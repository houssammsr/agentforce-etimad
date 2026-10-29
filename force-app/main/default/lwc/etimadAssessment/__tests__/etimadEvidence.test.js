import { createElement } from 'lwc';
import Component from 'c/etimadAssessment';
import listWorkspaces from '@salesforce/apex/EtimadAssessmentService.listWorkspaces';
import saveEvidence from '@salesforce/apex/EtimadAssessmentService.saveEvidence';
import capture from '@salesforce/apex/EtimadDecisionService.capture';
import listSnapshots from '@salesforce/apex/EtimadDecisionService.listSnapshots';
import approve from '@salesforce/apex/EtimadDecisionService.approve';
jest.mock('@salesforce/apex/EtimadAssessmentService.listWorkspaces',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.saveEvidence',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadDecisionService.capture',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadDecisionService.listSnapshots',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadDecisionService.approve',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/customPermission/Etimad_Verify',()=>({default:true}),{virtual:true});
jest.mock('@salesforce/customPermission/Etimad_Approve',()=>({default:true}),{virtual:true});
const flush=()=>new Promise(resolve=>setTimeout(resolve,0));
const row={id:'SYN-E',concept:'BID_SECURITY',supplierId:'SYN-S',validFrom:'2026-01-01',validTo:'2026-12-31',assertion:true,verified:false};
const workspace={Id:'SYN-W',Name:'SYN',Supplier__c:'SYN-S',Evidence_JSON__c:'[]',Revision__c:'v1'};
const snapshot={Id:'SYN-SNAPSHOT',Name:'SYN-ES',Context_Hash__c:'HASH',Rule_Version__c:'TEST',
    Payload__c:JSON.stringify(['snapshot-v1','TEST','SYN-W','SYN-S','2026-06-01','SYN','v1',null,null,'revision',JSON.stringify([row]),[],[['SYN-R','BID_SECURITY','supported','VERIFIED','SYN-E','revision']]])};
async function setup(rows=[]) {
    listWorkspaces.mockResolvedValue([{...workspace,Evidence_JSON__c:JSON.stringify(rows)}]);listSnapshots.mockResolvedValue([snapshot]);
    const el=createElement('c-etimad-assessment',{is:Component});document.body.appendChild(el);
    el.shadowRoot.querySelector('lightning-button').click();await flush();
    el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change',{detail:{value:'SYN-W'}}));await flush();return el;
}
const action=(el,name)=>el.shadowRoot.querySelector(`[data-action="${name}"]`).click();
async function add(el,values=row) {
    for(const key of ['id','concept','validFrom','validTo']) {
        const input=el.shadowRoot.querySelector(`[data-field="${key}"]`);input.value=values[key];
        input.dispatchEvent(new CustomEvent('change',{detail:{value:values[key]}}));await flush();
    }
    action(el,'add');await flush();
}
async function confirm(el) {
    const input=el.shadowRoot.querySelector('[data-role="confirmation"]');input.checked=true;input.dispatchEvent(new CustomEvent('change'));await flush();
}
afterEach(()=>{document.body.innerHTML='';jest.resetAllMocks();});
it('adds evidence without exposing JSON or accepting a supplier override',async()=>{
    const el=await setup();await add(el);
    expect(el.shadowRoot.querySelector('lightning-textarea')).toBeNull();
    expect(el.shadowRoot.querySelector('lightning-datatable').data).toEqual([row]);
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(true);
    expect(el.shadowRoot.querySelector('[data-action="capture"]').disabled).toBe(true);
});
it('rejects impossible dates and duplicate evidence IDs before saving',async()=>{
    const el=await setup();await add(el,{...row,validFrom:'2026-02-30'});
    expect(el.shadowRoot.querySelector('[data-validation]')).not.toBeNull();action(el,'save');await flush();expect(saveEvidence).not.toHaveBeenCalled();
    action(el,'discard');await flush();await add(el);await add(el);
    expect(el.shadowRoot.querySelector('lightning-datatable').data).toHaveLength(1);
    expect(el.shadowRoot.querySelector('[data-validation]')).not.toBeNull();
});
it('blocks invalid cell edits until discarded',async()=>{
    const el=await setup([row]);
    el.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('cellchange',{detail:{draftValues:[{id:row.id,validTo:'2025-01-01'}]}}));await flush();
    expect(el.shadowRoot.querySelector('[data-action="save"]').disabled).toBe(true);
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(true);
    action(el,'discard');await flush();expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(false);
});
it('stages removal and never sends an automatic mutation',async()=>{
    const el=await setup([row]);
    el.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction',{detail:{action:{name:'remove'},row}}));await flush();
    expect(el.shadowRoot.querySelector('lightning-datatable').data).toEqual([]);expect(saveEvidence).not.toHaveBeenCalled();
});
it('renders captured outcomes and requires explicit version-bound acceptance',async()=>{
    const el=await setup();capture.mockResolvedValue(snapshot.Id);action(el,'capture');await flush();
    expect(el.shadowRoot.textContent).toContain('supported');
    action(el,'approve');await flush();expect(approve).not.toHaveBeenCalled();
    await confirm(el);approve.mockResolvedValue('SYN-ACCEPTED');action(el,'approve');await flush();
    expect(approve).toHaveBeenCalledWith({snapshotId:snapshot.Id,expectedContext:'HASH'});
    expect(el.shadowRoot.querySelector('[role="status"]').textContent).toContain('no Task');
});
it('invalidates snapshot selection when evidence is edited',async()=>{
    const el=await setup();capture.mockResolvedValue(snapshot.Id);action(el,'capture');await flush();await confirm(el);await add(el);
    expect(el.shadowRoot.querySelector('[data-action="approve"]').disabled).toBe(true);
    expect(el.shadowRoot.querySelector('[data-role="snapshot"]').options).toEqual([]);
});
it('fails closed on stale server rejection and does not retry approval',async()=>{
    const el=await setup();capture.mockResolvedValue(snapshot.Id);action(el,'capture');await flush();await confirm(el);
    approve.mockRejectedValue(new Error('Stale snapshot'));action(el,'approve');await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Stale');
    expect(approve).toHaveBeenCalledTimes(1);expect(el.shadowRoot.querySelector('[data-action="approve"]').disabled).toBe(true);
});
it('does not approve an unreadable snapshot payload',async()=>{
    const el=await setup();capture.mockResolvedValue(snapshot.Id);listSnapshots.mockResolvedValue([{...snapshot,Payload__c:'invalid'}]);
    action(el,'capture');await flush();await confirm(el);action(el,'approve');await flush();expect(approve).not.toHaveBeenCalled();
});
