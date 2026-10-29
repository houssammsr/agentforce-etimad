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
        synthetic: 'SYNTHETIC', real: 'SOURCE-DERIVED · provisional' },
    ar: { title: 'اعتماد · مراجعة الأدلة', refresh: 'تحديث', source: 'فتح المصدر الأصلي',
        note: 'وضّح كيف تدعم الصفحة الأصلية هذا المتطلب', fact: 'متطلب مستخرج مبدئي',
        quote: 'اقتباس مبدئي — قارنه بالأصل', save: 'حفظ التصحيح وإلغاء التحقق السابق',
        verify: 'راجعت الصفحة الأصلية', approve: 'اعتماد إنشاء مهمة متابعة داخلية واحدة',
        pending: 'غير متحقق', verified: 'تمت مراجعة الدليل', approved: 'أُنشئت المهمة',
        stale: 'توجد مهمة سابقة — يلزم التحقق اليدوي', empty: 'لا توجد مراجعات متاحة.',
        warning: 'هذه مراجعة دليل لمتطلب واحد وليست اعتماد عرض أو شهادة امتثال.',
        confirm: 'أوافق على إنشاء مهمة متابعة داخلية واحدة لهذه النسخة.',
        synthetic: 'بيانات اصطناعية', real: 'مستخرج من المصدر · مبدئي' }
};

export default class EtimadReview extends LightningElement {
    locale = 'ar';
    records = [];
    busy = false;
    error;
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
            return { ...r, factDraft: draft.fact ?? r.Fact__c, noteDraft: draft.note ?? '',
                provenance: r.Synthetic__c ? this.labels.synthetic : this.labels.real,
                status: approved ? this.labels.approved : r.Task_Id__c ? this.labels.stale :
                    verified ? this.labels.verified : this.labels.pending,
                disableVerify: this.busy || !canVerify || !(draft.note || '').trim() ||
                    (draft.fact !== undefined && draft.fact !== r.Fact__c),
                disableSave: this.busy || !canVerify || !draft.fact?.trim() || draft.fact === r.Fact__c,
                disableApprove: this.busy || !canApprove || !verified || !!r.Task_Id__c || !draft.confirmed ||
                    (draft.fact !== undefined && draft.fact !== r.Fact__c),
                confirmed: !!draft.confirmed, readOnly: !canVerify || this.busy,
                page: `${r.PDF_Page__c} / ${r.Page_Count__c}` };
        });
    }
    @wire(listReviews)
    wiredReviews(result) {
        this.wiredResult = result;
        if (result.data) { this.records = result.data; this.error = undefined; }
        if (result.error) { this.records = []; this.error = this.message(result.error); }
    }
    message(error) { return error?.body?.message || error?.message || 'Request failed.'; }
    toggleLanguage() { this.locale = this.locale === 'ar' ? 'en' : 'ar'; }
    edit(event) {
        const { id, field } = event.target.dataset;
        this.drafts = { ...this.drafts, [id]: { ...this.drafts[id],
            [field]: field === 'confirmed' ? event.target.checked : event.target.value,
            ...(field === 'fact' ? { confirmed: false } : {}) } };
    }
    async refresh() {
        this.drafts = {};
        await refreshApex(this.wiredResult);
    }
    async act(event) {
        const { id, action } = event.target.dataset;
        const row = this.records.find((r) => r.Id === id);
        if (!row || this.busy) return;
        this.busy = true;
        this.error = undefined;
        try {
            const args = { reviewId: id, expectedRevision: row.Revision__c };
            if (action === 'verify') await verifyEvidence({ ...args, note: this.drafts[id]?.note });
            else if (action === 'save') await correctFact({ ...args, fact: this.drafts[id]?.fact });
            else if (action === 'approve' && this.drafts[id]?.confirmed) await approveTask(args);
            await this.refresh();
        } catch (error) { this.error = this.message(error); }
        finally { this.busy = false; }
    }
}
