import { createElement } from 'lwc';
import Component from 'c/etimadAssessment';
import listWorkspaces from '@salesforce/apex/EtimadAssessmentService.listWorkspaces';
import assess from '@salesforce/apex/EtimadAssessmentService.assess';
import saveEvidence from '@salesforce/apex/EtimadAssessmentService.saveEvidence';
jest.mock('@salesforce/apex/EtimadAssessmentService.listWorkspaces',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.assess',()=>({default:jest.fn()}),{virtual:true});
jest.mock('@salesforce/apex/EtimadAssessmentService.saveEvidence',()=>({default:jest.fn()}),{virtual:true});
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
