/** Prevent direct DML from bypassing workflow and invalidate decisions after content changes. */
public with sharing class EtimadReviewGuard {
    /**
     * @description Reject bypass writes and invalidate decisions when content changes.
     * @param rows Current trigger records.
     * @param oldRows Prior records, or null for insert.
     */
    public static void enforce(List<Etimad_Review__c> rows, Map<Id, Etimad_Review__c> oldRows) {
        for (Etimad_Review__c row : rows) {
            if (EtimadReviewController.serviceWrite != true) {
                row.addError('Use the Etimad review actions. Direct workflow edits are prohibited.');
                continue;
            }
            String fingerprint = EtimadReviewController.revision(row);
            if (oldRows != null && fingerprint != oldRows.get(row.Id).Revision__c) {
                row.Verified_Revision__c = null;
                row.Verified_By__c = null;
                row.Verified_At__c = null;
                row.Review_Note__c = null;
                row.Approved_Revision__c = null;
                row.Approved_By__c = null;
                row.Approved_At__c = null;
            }
            row.Revision__c = fingerprint;
        }
    }
}
