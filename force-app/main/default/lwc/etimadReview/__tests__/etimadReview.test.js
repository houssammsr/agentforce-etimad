import { createElement } from '@lwc/engine-dom';
import EtimadReview from 'c/etimadReview';
import listReviews from '@salesforce/apex/EtimadReviewController.listReviews';
import approveTask from '@salesforce/apex/EtimadReviewController.approveTask';
import verifyEvidence from '@salesforce/apex/EtimadReviewController.verifyEvidence';
import correctFact from '@salesforce/apex/EtimadReviewController.correctFact';

jest.mock('@salesforce/apex/EtimadReviewController.listReviews', () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return { default: createApexTestWireAdapter(jest.fn()) };
}, { virtual: true });
jest.mock('@salesforce/apex/EtimadReviewController.approveTask', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EtimadReviewController.verifyEvidence', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/EtimadReviewController.correctFact', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn().mockResolvedValue() }), { virtual: true });
jest.mock('@salesforce/customPermission/Etimad_Verify', () => ({ default: true }), { virtual: true });
jest.mock('@salesforce/customPermission/Etimad_Approve', () => ({ default: true }), { virtual: true });

const row = { Id: 'a00000000000001AAA', Source_Id__c: 'SYNTHETIC', Concept__c: 'SECURITY',
    Fact__c: 'Synthetic fact', Quote__c: 'دليل اصطناعي', Source_URL__c: 'https://example.invalid',
    Revision__c: 'revision-1', Verified_Revision__c: null, PDF_Page__c: 2, Page_Count__c: 3,
    Document_Version__c: 'v1', Synthetic__c: true };
const flush = async () => { await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); };
function mount(data = [row]) {
    const el = createElement('c-etimad-review', { is: EtimadReview });
    document.body.appendChild(el); listReviews.emit(data); return el;
}
function button(el, action) { return el.shadowRoot.querySelector(`[data-action="${action}"]`); }
function edit(el, field, value) {
    const input = el.shadowRoot.querySelector(`[data-field="${field}"]`);
    if (field === 'confirmed') input.checked = value; else input.value = value;
    input.dispatchEvent(new CustomEvent('change'));
}
afterEach(() => { document.body.replaceChildren(); jest.clearAllMocks(); });

test('unverified records cannot approve; Arabic RTL and source evidence are visible', async () => {
    const el = mount(); await flush();
    expect(button(el,'approve').disabled).toBe(true);
    expect(el.shadowRoot.querySelector('section').getAttribute('dir')).toBe('rtl');
    expect(el.shadowRoot.querySelector('blockquote').textContent).toContain('دليل اصطناعي');
    el.shadowRoot.querySelector('lightning-button').click(); await flush();
    expect(el.shadowRoot.querySelector('section').getAttribute('dir')).toBe('ltr');
});

test('explicit confirmation and verified revision are both required', async () => {
    const el = mount([{ ...row, Verified_Revision__c: row.Revision__c }]); await flush();
    expect(button(el,'approve').disabled).toBe(true);
    edit(el,'confirmed',true); await flush();
    expect(button(el,'approve').disabled).toBe(false);
    button(el,'approve').click(); await flush();
    expect(approveTask).toHaveBeenCalledWith({ reviewId: row.Id, expectedRevision: row.Revision__c });
});

test('verification requires rationale and cannot ignore an unsaved correction', async () => {
    const el = mount(); await flush();
    expect(button(el,'verify').disabled).toBe(true);
    edit(el,'note','Checked original page'); await flush();
    expect(button(el,'verify').disabled).toBe(false);
    edit(el,'fact','Corrected'); await flush();
    expect(button(el,'verify').disabled).toBe(true);
    button(el,'save').click(); await flush();
    expect(correctFact).toHaveBeenCalledWith({ reviewId: row.Id, expectedRevision: row.Revision__c, fact: 'Corrected' });
    expect(verifyEvidence).not.toHaveBeenCalled();
});

test('existing task stays disabled and stale-write failure is shown', async () => {
    const el=mount([{ ...row, Task_Id__c:'00T000000000001AAA' }]); await flush();
    expect(button(el,'approve').disabled).toBe(true);
    verifyEvidence.mockRejectedValueOnce({ body: { message:'Review changed. Refresh.' } });
    edit(el,'note','Checked source'); await flush();
    button(el,'verify').click(); await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Review changed');
});

test('empty and denied-access states expose no source record', async () => {
    const el=mount([]); await flush();
    expect(el.shadowRoot.querySelectorAll('article')).toHaveLength(0);
    listReviews.error({ message:'Access denied' }); await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]')).not.toBeNull();
    expect(el.shadowRoot.querySelectorAll('article')).toHaveLength(0);
});
