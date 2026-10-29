import { createElement } from 'lwc';
import Component from 'c/etimadAssessment';
import listWorkspaces from '@salesforce/apex/EtimadAssessmentService.listWorkspaces';
import assess from '@salesforce/apex/EtimadAssessmentService.assess';
import saveEvidence from '@salesforce/apex/EtimadAssessmentService.saveEvidence';
import verifyEvidence from '@salesforce/apex/EtimadAssessmentService.verifyEvidence';
jest.mock('@salesforce/apex/EtimadAssessmentService.listWorkspaces',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.assess',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.saveEvidence',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.verifyEvidence',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/customPermission/Etimad_Verify',()=>({default:true}),{virtual:true});
const flush=()=>new Promise(resolve=>setTimeout(resolve,0));
const workspace={Id:'SYN-W',Name:'SYN',Supplier__c:'SYN-S',Evidence_JSON__c:'[]',Revision__c:'v1'};
async function setup() {
    listWorkspaces.mockResolvedValue([workspace]);
    const el=createElement('c-etimad-assessment',{is:Component});document.body.appendChild(el);
    el.shadowRoot.querySelector('lightning-button').click();await flush();
    el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change',{detail:{value:'SYN-W'}}));await flush();
    return el;
}
afterEach(()=>{document.body.innerHTML='';jest.clearAllMocks();});
it('renders findings bound to the selected server revision',async()=>{
    const el=await setup();assess.mockResolvedValue([{reviewId:'SYN-R',concept:'BID_SECURITY',status:'unknown',reason:'NO_CURRENT_VERIFIED_EVIDENCE'}]);
    el.shadowRoot.querySelector('[data-action="assess"]').click();await flush();
    expect(assess).toHaveBeenCalledWith({workspaceId:'SYN-W',expectedRevision:'v1'});
    expect(el.shadowRoot.querySelector('article').textContent).toContain('unknown');
});
it('locks further operations after uncertain save until explicit refresh',async()=>{
    const el=await setup();saveEvidence.mockRejectedValue(new Error('Network interrupted'));
    el.shadowRoot.querySelector('[data-action="save"]').click();await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Network interrupted');
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(true);
    expect(saveEvidence).toHaveBeenCalledTimes(1);
    el.shadowRoot.querySelector('lightning-button').click();await flush();
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(false);
});

it('blocks assessment and attestation of unsaved drafts until explicit discard',async()=>{
    const el=await setup();
    const editor=el.shadowRoot.querySelector('lightning-textarea');
    editor.value='[{"id":"unsaved"}]';editor.dispatchEvent(new CustomEvent('change'));await flush();
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(true);
    expect(el.shadowRoot.querySelector('[data-action="verify"]').disabled).toBe(true);
    el.shadowRoot.querySelector('[data-action="assess"]').dispatchEvent(new CustomEvent('click'));
    el.shadowRoot.querySelector('[data-action="verify"]').dispatchEvent(new CustomEvent('click'));await flush();
    expect(assess).not.toHaveBeenCalled();expect(verifyEvidence).not.toHaveBeenCalled();
    el.shadowRoot.querySelector('[data-action="discard"]').click();await flush();
    expect(editor.value).toBe('[]');
    expect(el.shadowRoot.querySelector('[data-action="assess"]').disabled).toBe(false);
});

it('reloads changed server revision after saving and uses it for assessment',async()=>{
    const el=await setup();
    const editor=el.shadowRoot.querySelector('lightning-textarea');
    editor.value='[{"id":"draft"}]';editor.dispatchEvent(new CustomEvent('change'));await flush();
    saveEvidence.mockResolvedValueOnce();
    listWorkspaces.mockResolvedValue([{...workspace,Revision__c:'v2',Evidence_JSON__c:'[{"id":"saved","verified":false}]'}]);
    el.shadowRoot.querySelector('[data-action="save"]').click();await flush();
    expect(editor.value).toContain('saved');
    assess.mockResolvedValueOnce([]);
    el.shadowRoot.querySelector('[data-action="assess"]').click();await flush();
    expect(assess).toHaveBeenCalledWith({workspaceId:'SYN-W',expectedRevision:'v2'});
});

it('discards findings if workspace changed during assessment',async()=>{
    const el=await setup();
    assess.mockResolvedValueOnce([{reviewId:'SYN-R',status:'supported'}]);
    listWorkspaces.mockResolvedValue([{...workspace,Revision__c:'newer'}]);
    el.shadowRoot.querySelector('[data-action="assess"]').click();await flush();
    expect(el.shadowRoot.querySelector('article')).toBeNull();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('changed');
});
