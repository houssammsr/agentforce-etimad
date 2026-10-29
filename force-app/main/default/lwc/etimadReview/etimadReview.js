import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import listReviews from '@salesforce/apex/EtimadReviewController.listReviews';
import verifyEvidence from '@salesforce/apex/EtimadReviewController.verifyEvidence';
import correctFact from '@salesforce/apex/EtimadReviewController.correctFact';
import approveTask from '@salesforce/apex/EtimadReviewController.approveTask';
import canVerify from '@salesforce/customPermission/Etimad_Verify';
import canApprove from '@salesforce/customPermission/Etimad_Approve';

const COPY = {
    en: { title: 'Etimad · Evidence review', refresh: 'Refresh', source: 'Open original source',
        note: 'Explain how the original page supports this requirement', fact: 'Candidate requirement',
        quote: 'Candidate quotation — verify against the original', save: 'Save correction (invalidates verification)',
        verify: 'I checked the original page', approve: 'Approve one internal follow-up Task',
        pending: 'Unverified', verified: 'Evidence reviewed', approved: 'Task created',
        stale: 'Earlier Task exists — manual reconciliation required', empty: 'No accessible reviews.',
        warning: 'This is requirement-level evidence review, not a bid approval or compliance certification.',
        confirm: 'I authorize creation of one internal follow-up Task for this revision.',
        synthetic: 'SYNTHETIC', real: 'SOURCE-DERIVED · provisional',
        saved: 'Saved successfully.',
        timeout: 'The request timed out. Its server outcome may be unknown. Click Refresh to check before retrying.',
        refreshFailed: 'Could not refresh the review. Click Refresh before taking another action.',
        reconciled: 'Review refreshed from Salesforce.' },
    ar: { title: 'اعتماد · مراجعة الأدلة', refresh: 'تحديث', source: 'فتح المصدر الأصلي',
        note: 'وضّح كيف تدعم الصفحة الأصلية هذا المتطلب', fact: 'متطلب مستخرج مبدئي',
        quote: 'اقتباس مبدئي — قارنه بالأصل', save: 'حفظ التصحيح وإلغاء التحقق السابق',
        verify: 'راجعت الصفحة الأصلية', approve: 'اعتماد إنشاء مهمة متابعة داخلية واحدة',
        pending: 'غير متحقق', verified: 'تمت مراجعة الدليل', approved: 'أُنشئت المهمة',
        stale: 'توجد مهمة سابقة — يلزم التحقق اليدوي', empty: 'لا توجد مراجعات متاحة.',
        warning: 'هذه مراجعة دليل لمتطلب واحد وليست اعتماد عرض أو شهادة امتثال.',
        confirm: 'أوافق على إنشاء مهمة متابعة داخلية واحدة لهذه النسخة.',
        synthetic: 'بيانات اصطناعية', real: 'مستخرج من المصدر · مبدئي',
        saved: 'تم الحفظ بنجاح.',
        timeout: 'انتهت مهلة الطلب وقد تكون نتيجته على الخادم غير معروفة. اضغط تحديث للتحقق قبل إعادة المحاولة.',
        refreshFailed: 'تعذر تحديث المراجعة. اضغط تحديث قبل اتخاذ إجراء آخر.',
        reconciled: 'تم تحديث المراجعة من Salesforce.' }
};

export default class EtimadReview extends LightningElement {
    locale = 'ar';
    records = [];
    busy = false;
    error;
    notice;
    needsRefresh = false;
    wiredResult;
    drafts = {};
    get labels() { return COPY[this.locale]; }
    get direction() { return this.locale === 'ar' ? 'rtl' : 'ltr'; }
    get isArabic() { return this.locale === 'ar'; }
    get empty() { return !this.records.length; }
    get rows() {
        return this.records.map((r) => {
            const verified = r.Verified_Revision__c === r.Revision__c;
            const approved = r.Approved_Revision__c === r.Revision__c && r.Task_Id__c;
            const draft = this.drafts[r.Id] || {};
            return { ...r, factDraft: draft.fact ?? r.Fact__c, noteDraft: draft.note ?? r.Review_Note__c ?? '',
                provenance: r.Synthetic__c ? this.labels.synthetic : this.labels.real,
                status: approved ? this.labels.approved : r.Task_Id__c ? this.labels.stale :
                    verified ? this.labels.verified : this.labels.pending,
                disableVerify: this.busy || this.needsRefresh || !canVerify || !(draft.note ?? r.Review_Note__c ?? '').trim() ||
                    (draft.fact !== undefined && draft.fact !== r.Fact__c),
                disableSave: this.busy || this.needsRefresh || !canVerify || !draft.fact?.trim() || draft.fact === r.Fact__c,
                disableApprove: this.busy || this.needsRefresh || !canApprove || !verified || !!r.Task_Id__c || !draft.confirmed ||
                    (draft.fact !== undefined && draft.fact !== r.Fact__c),
                confirmed: !!draft.confirmed, readOnly: !canVerify || this.busy || this.needsRefresh,
                page: `${r.PDF_Page__c} / ${r.Page_Count__c}` };
        });
    }
    @wire(listReviews)
    wiredReviews(result) {
        this.wiredResult = result;
        if (result.data) {
            this.records = result.data;
            if (!this.needsRefresh) this.error = undefined;
        }
        if (result.error) { this.records = []; this.needsRefresh = true; this.error = this.message(result.error); }
    }
    message(error) { return error?.body?.message || error?.message || 'Request failed.'; }
    toggleLanguage() { this.locale = this.locale === 'ar' ? 'en' : 'ar'; }
    edit(event) {
        const { id, field } = event.target.dataset;
        this.drafts = { ...this.drafts, [id]: { ...this.drafts[id],
            [field]: field === 'confirmed' ? event.target.checked : event.target.value,
            ...(field === 'fact' ? { confirmed: false } : {}) } };
    }
    async bounded(request) {
        let timer;
        try {
            return await Promise.race([request, new Promise((resolve, reject) => {
                timer = setTimeout(() => reject(new Error(this.labels.timeout)), 20000);
            })]);
        } finally { clearTimeout(timer); }
    }
    async refreshData() {
        this.needsRefresh = true;
        await this.bounded(refreshApex(this.wiredResult));
        if (this.wiredResult?.error) throw new Error(this.labels.refreshFailed);
        this.drafts = {};
        this.needsRefresh = false;
        this.error = undefined;
        this.notice = this.labels.reconciled;
    }
    async refresh() {
        if (this.busy) return;
        this.busy = true;
        this.error = undefined;
        try { await this.refreshData(); }
        catch (error) { this.error = this.message(error); }
        finally { this.busy = false; }
    }
    async act(event) {
        const { id, action } = event.target.dataset;
        const row = this.records.find((r) => r.Id === id);
        if (!row || this.busy || this.needsRefresh) return;
        this.busy = true;
        this.error = undefined;
        this.notice = undefined;
        this.needsRefresh = true;
        try {
            const args = { reviewId: id, expectedRevision: row.Revision__c };
            let request;
            if (action === 'verify') request = verifyEvidence({ ...args, note: this.drafts[id]?.note ?? row.Review_Note__c });
            else if (action === 'save') request = correctFact({ ...args, fact: this.drafts[id]?.fact });
            else if (action === 'approve' && this.drafts[id]?.confirmed) request = approveTask(args);
            else throw new Error(this.labels.refreshFailed);
            // A client timeout does not cancel Apex. Never retry a mutation automatically.
            await this.bounded(request);
            this.notice = this.labels.saved;
            await this.refreshData();
        } catch (error) { this.error = this.message(error); }
        finally { this.busy = false; }
    }
}
