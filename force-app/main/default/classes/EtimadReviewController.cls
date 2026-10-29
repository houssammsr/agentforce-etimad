/** One-requirement walking skeleton. No external submission or autonomous approval. */
public with sharing class EtimadReviewController {
    /** @description Transaction-scoped guard, writable only by this service. */
    public static Boolean serviceWrite { get; private set; }
    /** @description Explicit authorization, stale-state and validation failure. */
    public class ReviewException extends Exception {}

    private static void requirePermission(String permission) {
        if (!FeatureManagement.checkPermission(permission)) {
            throw new ReviewException('Etimad permission required.');
        }
    }

    /**
     * @description Read current user's records without a system-mode fallback.
     * @return At most 25 accessible reviews.
     */
    @AuraEnabled(cacheable=true)
    public static List<Etimad_Review__c> listReviews() {
        requirePermission('Etimad_Read');
        return [SELECT Id, Name, Source_Id__c, Source_Hash__c, Document_Version__c,
            Source_URL__c, PDF_Page__c, Page_Count__c, Concept__c, Fact__c, Quote__c,
            Revision__c, Verified_Revision__c, Approved_Revision__c, Task_Id__c,
            Review_Note__c, Synthetic__c, Assessment__c, Exception_Concept__c, Submission_Deadline_Hijri__c,
            Submission_Deadline_Gregorian__c
            FROM Etimad_Review__c WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 25];
    }

    /**
     * @description Import bounded candidates; never initially verified.
     * @param payload Schema-bound JSON candidates.
     * @return IDs of newly inserted or unchanged existing candidates.
     */
    @AuraEnabled
    public static List<Id> importCandidates(String payload) {
        requirePermission('Etimad_Import');
        Map<String, Etimad_Review__c> prepared = EtimadCandidateContract.prepare(payload);
        Set<String> keys = prepared.keySet();
        Map<String, Etimad_Review__c> existing = new Map<String, Etimad_Review__c>();
        for (Etimad_Review__c row : [SELECT Id, Import_Key__c, Revision__c FROM Etimad_Review__c
            WHERE Import_Key__c IN :keys WITH USER_MODE]) {
            existing.put(row.Import_Key__c, row);
        }
        List<Etimad_Review__c> inserts = EtimadCandidateContract.filterInserts(prepared, existing);
        serviceWrite = true;
        try {
            Database.insert(inserts, AccessLevel.USER_MODE);
        } finally {
            serviceWrite = false;
        }
        List<Id> ids = new List<Id>();
        for (Etimad_Review__c row : inserts) { ids.add(row.Id); }
        for (Etimad_Review__c row : existing.values()) { ids.add(row.Id); }
        return ids;
    }

    /**
     * @description Fingerprint every source/content field relevant to evidence review.
     * @param row Current source-bound requirement.
     * @return SHA-256 revision fingerprint.
     */
    public static String revision(Etimad_Review__c row) {
        List<Object> parts=new List<Object>{row.Source_Id__c, row.Source_Hash__c, row.Document_Version__c,
            row.Source_URL__c, row.PDF_Page__c == null ? null : row.PDF_Page__c.intValue(),
            row.Page_Count__c == null ? null : row.Page_Count__c.intValue(), row.Concept__c,
            row.Fact__c, row.Quote__c, row.Submission_Deadline_Hijri__c,
            row.Submission_Deadline_Gregorian__c, row.Synthetic__c};
        // Preserve Phase 2 fingerprints for unlinked records, including existing approvals.
        if(row.Assessment__c!=null || row.Exception_Concept__c!=null) {
            parts.add(row.Assessment__c); parts.add(row.Exception_Concept__c);
        }
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(JSON.serialize(parts))));
    }

    private static Etimad_Review__c locked(Id reviewId, String expectedRevision) {
        List<Etimad_Review__c> rows = [SELECT Id, Assessment__c, Exception_Concept__c, Source_Id__c, Source_Hash__c, Document_Version__c,
            Source_URL__c, PDF_Page__c, Page_Count__c, Concept__c, Fact__c, Quote__c, Synthetic__c,
            Submission_Deadline_Hijri__c, Submission_Deadline_Gregorian__c, Revision__c,
            Verified_Revision__c, Approved_Revision__c, Task_Id__c
            FROM Etimad_Review__c WHERE Id = :reviewId WITH USER_MODE LIMIT 1 FOR UPDATE];
        if (rows.isEmpty() || String.isBlank(expectedRevision) || rows[0].Revision__c != expectedRevision) {
            throw new ReviewException('Review unavailable or changed. Refresh before continuing.');
        }
        return rows[0];
    }

    /**
     * @description Record human page attestation, not automated citation verification.
     * @param reviewId Accessible requirement ID.
     * @param expectedRevision Revision displayed to reviewer.
     * @param note Explanation of original-page support.
     */
    @AuraEnabled
    public static void verifyEvidence(Id reviewId, String expectedRevision, String note) {
        requirePermission('Etimad_Verify');
        Etimad_Review__c row = locked(reviewId, expectedRevision);
        if (String.isBlank(note) || note.length() > 2000) {
            throw new ReviewException('Record how the original page supports this requirement.');
        }
        writeReview(new Etimad_Review__c(Id=row.Id, Verified_Revision__c=row.Revision__c,
            Verified_By__c=UserInfo.getUserId(), Verified_At__c=System.now(), Review_Note__c=note));
    }

    /**
     * @description Correct a fact and invalidate prior verification through the guard.
     * @param reviewId Accessible requirement ID.
     * @param expectedRevision Revision displayed to reviewer.
     * @param fact Corrected requirement text.
     */
    @AuraEnabled
    public static void correctFact(Id reviewId, String expectedRevision, String fact) {
        requirePermission('Etimad_Verify');
        Etimad_Review__c row = locked(reviewId, expectedRevision);
        if (String.isBlank(fact) || fact.length() > 8000) { throw new ReviewException('Fact is required.'); }
        writeReview(new Etimad_Review__c(Id=row.Id, Fact__c=fact));
    }

    /**
     * @description Lock review and atomically create at most one approved follow-up Task.
     * @param reviewId Accessible requirement ID.
     * @param expectedRevision Source revision explicitly selected for approval.
     * @return Existing or newly created Task ID.
     */
    @AuraEnabled
    public static Id approveTask(Id reviewId, String expectedRevision) {
        requirePermission('Etimad_Approve');
        Etimad_Review__c row = locked(reviewId, expectedRevision);
        if (row.Verified_Revision__c != row.Revision__c) {
            throw new ReviewException('Verify the original source evidence before approval.');
        }
        if (row.Task_Id__c != null) {
            if (row.Approved_Revision__c == row.Revision__c) { return (Id) row.Task_Id__c; }
            throw new ReviewException('An earlier version already created a task. Review it manually; no duplicate created.');
        }
        Savepoint checkpoint = Database.setSavepoint();
        try {
            Task work = new Task(Subject=('Etimad evidence: ' + row.Concept__c).left(255),
                WhatId=row.Id, OwnerId=UserInfo.getUserId(), Status='Not Started', Priority='Normal',
                Description='Internal evidence follow-up only. Source: ' + row.Source_Id__c +
                    '; PDF page ' + row.PDF_Page__c + '; revision ' + row.Revision__c +
                    '. This task is not a bid approval or compliance certification.');
            Database.insert(work, AccessLevel.USER_MODE);
            writeReview(new Etimad_Review__c(Id=row.Id, Task_Id__c=work.Id,
                Approved_Revision__c=row.Revision__c, Approved_By__c=UserInfo.getUserId(), Approved_At__c=System.now()));
            return work.Id;
        } catch (Exception e) {
            Database.rollback(checkpoint);
            throw new ReviewException('Approval failed; no task was committed. Check access and refresh.');
        }
    }

    /** Link only newly created synthetic fixtures; never attest to source evidence. */
    public static void linkSynthetic(List<Etimad_Review__c> changes) {
        requirePermission('Etimad_Import'); requirePermission('Etimad_Verify');
        Set<Id> ids=new Set<Id>(); for(Etimad_Review__c c:changes) ids.add(c.Id);
        Map<Id,Etimad_Review__c> current=new Map<Id,Etimad_Review__c>([SELECT Id,Synthetic__c,Assessment__c FROM Etimad_Review__c WHERE Id IN :ids WITH USER_MODE]);
        Set<Id> workspaceIds=new Set<Id>(); for(Etimad_Review__c c:changes) workspaceIds.add(c.Assessment__c);
        Set<Id> validWorkspaceIds=new Map<Id,Etimad_Assessment__c>([SELECT Id FROM Etimad_Assessment__c WHERE Id IN :workspaceIds AND Source_Id__c='SYN-PHASE3' WITH USER_MODE]).keySet();
        List<Etimad_Review__c> updates=new List<Etimad_Review__c>();
        for(Etimad_Review__c c:changes) {
            if(!current.containsKey(c.Id) || !current.get(c.Id).Synthetic__c || current.get(c.Id).Assessment__c!=null)
                throw new ReviewException('Only unlinked synthetic fixtures can be linked.');
            if(!validWorkspaceIds.contains(c.Assessment__c)) throw new ReviewException('Synthetic workspace required.');
            updates.add(new Etimad_Review__c(Id=c.Id,Assessment__c=c.Assessment__c,Exception_Concept__c=c.Exception_Concept__c));
        }
        serviceWrite=true;
        try { Database.update(updates,AccessLevel.USER_MODE); } finally { serviceWrite=false; }
    }

    private static void writeReview(Etimad_Review__c change) {
        serviceWrite = true;
        try {
            Database.update(change, AccessLevel.USER_MODE);
        } finally {
            serviceWrite = false;
        }
    }
}
