import { LightningElement } from 'lwc';
import listWorkspaces from '@salesforce/apex/EtimadAssessmentService.listWorkspaces';
import createDemo from '@salesforce/apex/EtimadAssessmentService.createDemo';
import assess from '@salesforce/apex/EtimadAssessmentService.assess';
import saveEvidence from '@salesforce/apex/EtimadAssessmentService.saveEvidence';
import verifyEvidence from '@salesforce/apex/EtimadAssessmentService.verifyEvidence';
import capture from '@salesforce/apex/EtimadDecisionService.capture';
import listSnapshots from '@salesforce/apex/EtimadDecisionService.listSnapshots';
import approve from '@salesforce/apex/EtimadDecisionService.approve';
import canVerify from '@salesforce/customPermission/Etimad_Verify';
import canImport from '@salesforce/customPermission/Etimad_Import';
import canApprove from '@salesforce/customPermission/Etimad_Approve';

const emptyRow = () => ({id:'', concept:'', validFrom:'', validTo:'', assertion:true});
export default class EtimadAssessment extends LightningElement {
    workspaces=[]; findings=[]; snapshots=[]; selected; draft=''; evidenceId='';
    busy=false; uncertain=false; error; notice; pendingEdits=[]; validationError;
    newRow=emptyRow(); snapshotId; confirmed=false;
    columns=[
        {label:'Evidence ID / معرّف الدليل',fieldName:'id',type:'text'},
        {label:'Concept / المفهوم',fieldName:'concept',type:'text',editable:true},
        {label:'Valid from / ساري من',fieldName:'validFrom',type:'text',editable:true},
        {label:'Valid to / ساري إلى',fieldName:'validTo',type:'text',editable:true},
        {label:'Supports (false = contradicts) / يؤيد',fieldName:'assertion',type:'boolean',editable:true},
        {label:'Reviewed / تمت المراجعة',fieldName:'verified',type:'boolean'},
        {type:'button',typeAttributes:{label:'Remove / حذف',name:'remove'}}
    ];
    assertionOptions=[{label:'Supports / يؤيد',value:'true'},{label:'Contradicts / يناقض',value:'false'}];
    get assertionValue() { return String(this.newRow.assertion); }
    get workspace() { return this.workspaces.find(w=>w.Id===this.selected); }
    get options() { return this.workspaces.map(w=>({label:`${w.Name} · ${w.Supplier__c}`,value:w.Id})); }
    get sourceMode() { return this.workspace?.Source_Model__c==='SOFTWARE_SECURITY_V1'; }
    get evidenceRows() { return this.draft ? JSON.parse(this.draft) : []; }
    get evidenceOptions() { return this.evidenceRows.map(e=>({label:`${e.id} · ${e.concept}`,value:e.id})); }
    get hasNewDraft() { return ['id','concept','validFrom','validTo'].some(k=>this.newRow[k]); }
    get dirty() { return !!this.workspace && (this.draft!==this.workspace.Evidence_JSON__c || this.pendingEdits.length>0 || this.hasNewDraft); }
    get disabled() { return this.busy || this.uncertain || !this.selected; }
    get actionDisabled() { return this.disabled || this.dirty; }
    get editDisabled() { return this.disabled || !canVerify; }
    get saveDisabled() { return this.editDisabled || !!this.validationError || this.hasNewDraft; }
    get verifyDisabled() { return this.actionDisabled || !canVerify || !this.evidenceId; }
    get discardDisabled() { return this.busy || !this.dirty; }
    get selectionDisabled() { return this.busy || this.dirty; }
    get refreshDisabled() { return this.busy || this.dirty; }
    get createDisabled() { return this.busy || this.uncertain || this.dirty || !canVerify || !canImport; }
    get captureDisabled() { return this.actionDisabled || !canVerify; }
    get snapshotOptions() { return this.snapshots.map(s=>({label:`${s.Name} · ${s.Rule_Version__c}`,value:s.Id})); }
    get selectedSnapshot() { return this.snapshots.find(s=>s.Id===this.snapshotId); }
    get snapshotDetails() {
        try {
            const p=JSON.parse(this.selectedSnapshot?.Payload__c || 'null');
            if(!Array.isArray(p) || p[0]!=='snapshot-v1' || p.length!==13)return null;
            return {evidence:JSON.parse(p[10]),sources:p[11].map(c=>({id:c[0],source:c[1],version:c[3],page:c[5],concept:c[7],quote:c[9]})),
                outcomes:p[12].map(f=>({id:f[0],concept:f[1],status:f[2],reason:f[3]}))};
        } catch(e) { return null; }
    }
    get approvalDisabled() { return this.actionDisabled || !canApprove || !this.snapshotDetails || !this.confirmed; }
    get context() { const w=this.workspace;return w?`${w.Source_Id__c} · ${w.Document_Version__c} · ${w.As_Of__c} · ${w.Supplier__c}`:''; }
    resetResults() { this.findings=[];this.snapshots=[];this.snapshotId=undefined;this.confirmed=false;this.notice=undefined; }
    discard() {
        if(this.busy)return;
        this.draft=this.workspace?.Evidence_JSON__c || '';this.pendingEdits=[];this.validationError=undefined;
        this.newRow=emptyRow();this.error=undefined;this.resetResults();
    }
    async bounded(promise) {
        let timer;
        try { return await Promise.race([promise,new Promise((resolve,reject)=>{
            timer=setTimeout(()=>reject(new Error('Timeout: refresh before continuing / حدّث قبل المتابعة')),20000);
        })]); } finally { clearTimeout(timer); }
    }
    async load() {
        this.workspaces=await this.bounded(listWorkspaces());
        this.draft=this.workspace?.Evidence_JSON__c || '';if(!this.workspace)this.selected=undefined;
        this.pendingEdits=[];this.validationError=undefined;this.newRow=emptyRow();
    }
    async refresh() {
        if(this.busy || this.dirty)return;
        this.busy=true;this.resetResults();
        try { await this.load();this.uncertain=false;this.error=undefined; }
        catch(e) { this.error=e?.body?.message || e.message; }
        finally { this.busy=false; }
    }
    choose(e) {
        if(this.busy || this.dirty)return;
        this.selected=e.detail.value;this.evidenceId='';this.draft=this.workspace?.Evidence_JSON__c || '';
        this.newRow=emptyRow();this.resetResults();
    }
    evidence(e) { this.evidenceId=e.detail.value; }
    newField(e) {
        const key=e.target.dataset.field;const value=e.detail?.value ?? e.target.value;
        this.newRow={...this.newRow,[key]:key==='assertion'?value==='true':value};this.resetResults();
    }
    validate(rows) {
        if(rows.length>20)throw new Error('Maximum 20 evidence rows / الحد الأقصى 20');
        const ids=new Set();
        for(const e of rows) {
            const validDate=s=>typeof s==='string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s)) && new Date(s).toISOString().slice(0,10)===s;
            if(!e.id?.trim() || e.id.length>100 || ids.has(e.id) || !e.concept?.trim() || e.concept.length>100 ||
               !validDate(e.validFrom) || !validDate(e.validTo) || e.validFrom>e.validTo || typeof e.assertion!=='boolean' ||
               e.supplierId!==this.workspace.Supplier__c)throw new Error('Check unique ID, concept and ISO dates / تحقق من المعرّف والمفهوم والتواريخ');
            ids.add(e.id);
        }
    }
    addRow() {
        if(this.editDisabled)return;
        try {
            const rows=[...this.evidenceRows,{...this.newRow,supplierId:this.workspace.Supplier__c,verified:false}];
            this.validate(rows);this.draft=JSON.stringify(rows);this.newRow=emptyRow();this.validationError=undefined;this.resetResults();
        } catch(e) { this.validationError=e.message; }
    }
    editRows(e) {
        if(this.editDisabled)return;
        this.pendingEdits=e.detail.draftValues;this.resetResults();
        try {
            const rows=this.evidenceRows.map(row=>({...row,...this.pendingEdits.find(d=>d.id===row.id)}));
            this.validate(rows);this.draft=JSON.stringify(rows);this.pendingEdits=[];this.validationError=undefined;
        } catch(error) { this.validationError=error.message; }
    }
    rowAction(e) {
        if(this.editDisabled || e.detail.action.name!=='remove')return;
        this.draft=JSON.stringify(this.evidenceRows.filter(row=>row.id!==e.detail.row.id));
        this.pendingEdits=[];this.validationError=undefined;this.resetResults();
    }
    chooseSnapshot(e) { this.snapshotId=e.detail.value;this.confirmed=false; }
    confirm(e) { this.confirmed=e.target.checked; }
    async act(e) {
        if(this.busy || this.uncertain)return;
        const action=e.target.dataset.action;
        if(this.dirty && action!=='save')return;
        if(action==='save') {
            if(this.hasNewDraft || this.validationError)return;
            try { this.validate(this.evidenceRows); } catch(error) { this.validationError=error.message;return; }
        }
        if(action==='verify' && !this.evidenceId)return;
        if(action==='approve' && this.approvalDisabled)return;
        const w=this.workspace;if(action!=='create' && !w)return;
        this.busy=true;this.error=undefined;this.notice=undefined;this.findings=[];
        try {
            const args={workspaceId:w?.Id,expectedRevision:w?.Revision__c};
            if(action==='create') this.selected=await this.bounded(createDemo());
            else if(action==='save') await this.bounded(saveEvidence({...args,payload:this.draft}));
            else if(action==='verify') await this.bounded(verifyEvidence({...args,evidenceId:this.evidenceId}));
            else if(action==='assess') this.findings=await this.bounded(assess(args));
            else if(action==='capture') this.snapshotId=await this.bounded(capture(args));
            else if(action==='approve') {
                await this.bounded(approve({snapshotId:this.snapshotId,expectedContext:this.selectedSnapshot.Context_Hash__c}));
                this.notice='Assessment accepted for this exact version only; no Task or bid submitted / تم قبول نسخة التقييم فقط';
            }
            await this.load();
            if(action==='assess' && this.workspace?.Revision__c!==args.expectedRevision)throw new Error('Evidence changed; recompute / تغيرت الأدلة؛ أعد التقييم');
            if(['capture','history','approve'].includes(action))this.snapshots=await this.bounded(listSnapshots({workspaceId:this.selected}));
            else { this.snapshots=[];this.snapshotId=undefined; }
            this.confirmed=false;
        } catch(error) {
            this.resetResults();this.uncertain=true;this.error=error?.body?.message || error.message;
        } finally { this.busy=false; }
    }
}
