import { LightningElement } from 'lwc';
import listWorkspaces from '@salesforce/apex/EtimadAssessmentService.listWorkspaces';
import createDemo from '@salesforce/apex/EtimadAssessmentService.createDemo';
import assess from '@salesforce/apex/EtimadAssessmentService.assess';
import saveEvidence from '@salesforce/apex/EtimadAssessmentService.saveEvidence';
import verifyEvidence from '@salesforce/apex/EtimadAssessmentService.verifyEvidence';
import canVerify from '@salesforce/customPermission/Etimad_Verify';
import canImport from '@salesforce/customPermission/Etimad_Import';

export default class EtimadAssessment extends LightningElement {
    workspaces = [];
    findings = [];
    selected;
    draft = '';
    evidenceId = '';
    busy = false;
    error;
    uncertain = false;
    get options() { return this.workspaces.map(w => ({label: `${w.Name} · ${w.Supplier__c}`, value:w.Id})); }
    get disabled() { return this.busy || this.uncertain || !this.selected; }
    get editDisabled() { return this.disabled || !canVerify; }
    get createDisabled() { return this.busy || this.uncertain || !canVerify || !canImport; }
    get context() { const w=this.workspaces.find(x=>x.Id===this.selected); return w ? `${w.Source_Id__c} · ${w.Document_Version__c} · ${w.As_Of__c}` : ''; }
    async refresh() {
        if(this.busy) return;
        this.busy=true; this.findings=[];
        try { await this.load(); this.uncertain=false; this.error=undefined; }
        catch(e) { this.error=e?.body?.message || e.message; }
        finally { this.busy=false; }
    }
    async load() {
        this.workspaces=await this.bounded(listWorkspaces());
        const w=this.workspaces.find(x=>x.Id===this.selected);
        if(w) this.draft=w.Evidence_JSON__c;
    }
    choose(e) { this.selected=e.detail.value; this.findings=[]; this.draft=this.workspaces.find(w=>w.Id===this.selected)?.Evidence_JSON__c || ''; }
    edit(e) { this.draft=e.target.value; this.findings=[]; }
    evidence(e) { this.evidenceId=e.target.value; }
    async bounded(promise) {
        let timer;
        try { return await Promise.race([promise,new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Timeout: refresh before continuing / حدّث قبل المتابعة')),20000);})]); }
        finally { clearTimeout(timer); }
    }
    async act(e) {
        if(this.busy || this.uncertain) return;
        const action=e.target.dataset.action;
        const w=this.workspaces.find(x=>x.Id===this.selected);
        if(action!=='create' && !w) return;
        this.busy=true; this.error=undefined; this.findings=[];
        try {
            const args={workspaceId:w?.Id,expectedRevision:w?.Revision__c};
            if(action==='create') this.selected=await this.bounded(createDemo());
            else if(action==='save') await this.bounded(saveEvidence({...args,payload:this.draft}));
            else if(action==='verify') await this.bounded(verifyEvidence({...args,evidenceId:this.evidenceId}));
            else if(action==='assess') this.findings=await this.bounded(assess(args));
            await this.load();
        } catch(error) {
            this.uncertain=true; this.error=error?.body?.message || error.message;
        } finally { this.busy=false; }
    }
}
