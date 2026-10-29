/** Immutable assessment capture and explicit, version-bound internal acceptance.
 * Approval never submits a bid or creates a Task.
 */
public with sharing class EtimadDecisionService {
    public static Boolean snapshotInsert { get; private set; }
    public static Boolean approvalInsert { get; private set; }
    @TestVisible private static String activeRuleVersion='decision-1:synthetic-3.2:software-security-1';
    public class DecisionException extends Exception {}
    private class State {
        String payload;
        String hash;
        Boolean acceptable;
    }
    private static void permission(String name) {
        if(!FeatureManagement.checkPermission(name)) throw new DecisionException('Etimad permission required.');
    }
    private static String digest(String value) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(value)));
    }
    private static Etimad_Assessment__c workspace(Id id) {
        List<Etimad_Assessment__c> rows=[SELECT Id,Supplier__c,As_Of__c,Source_Id__c,Document_Version__c,
            Evidence_JSON__c,Revision__c,Source_Model__c,Source_Key__c FROM Etimad_Assessment__c
            WHERE Id=:id WITH USER_MODE LIMIT 1 FOR UPDATE];
        if(rows.isEmpty()) throw new DecisionException('Workspace unavailable.');
        return rows[0];
    }
    /** Lock every source dependency, preserve evidence, and recompute results. */
    private static State current(Etimad_Assessment__c w) {
        if(w.Revision__c!=EtimadAssessmentService.fingerprint(w)) throw new DecisionException('Workspace integrity failure.');
        List<Etimad_Review__c> clauses=[SELECT Id,Source_Id__c,Source_Hash__c,Document_Version__c,Source_URL__c,
            PDF_Page__c,Page_Count__c,Concept__c,Fact__c,Quote__c,Revision__c,Verified_Revision__c,
            Verified_By__c,Verified_At__c,Review_Note__c,Exception_Concept__c,Synthetic__c
            FROM Etimad_Review__c WHERE Assessment__c=:w.Id WITH USER_MODE LIMIT 11 FOR UPDATE];
        // Both supported workspace models own exactly three source dependencies.
        // Partial sharing must never turn a subset into a complete approval.
        Set<String> concepts=new Set<String>();for(Etimad_Review__c c:clauses) concepts.add(c.Concept__c);
        Set<String> required=w.Source_Model__c==null ? new Set<String>{'BID_SECURITY','LOCAL_SME_CERT','FINAL_SECURITY'} :
            new Set<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'};
        if(clauses.size()!=3 || concepts!=required) throw new DecisionException('All three source dependencies must be accessible.');
        Map<Id,Etimad_Review__c> byId=new Map<Id,Etimad_Review__c>(clauses);
        List<Id> ids=new List<Id>(byId.keySet()); ids.sort();
        List<Object> sources=new List<Object>(); Boolean verified=true;
        for(Id id:ids) {
            Etimad_Review__c c=byId.get(id);
            if(c.Verified_Revision__c!=c.Revision__c) verified=false;
            sources.add(new List<Object>{c.Id,c.Source_Id__c,c.Source_Hash__c,c.Document_Version__c,c.Source_URL__c,
                c.PDF_Page__c,c.Page_Count__c,c.Concept__c,c.Fact__c,c.Quote__c,c.Revision__c,c.Verified_Revision__c,
                c.Verified_By__c,c.Verified_At__c,c.Review_Note__c,c.Exception_Concept__c,c.Synthetic__c});
        }
        List<EtimadAssessmentService.Finding> findings=EtimadAssessmentService.assess(w.Id,w.Revision__c);
        Map<Id,EtimadAssessmentService.Finding> results=new Map<Id,EtimadAssessmentService.Finding>();
        for(EtimadAssessmentService.Finding f:findings) results.put(f.reviewId,f);
        List<Object> outcomes=new List<Object>(); Boolean acceptable=verified && !findings.isEmpty();
        for(Id id:ids) if(results.containsKey(id)) {
            EtimadAssessmentService.Finding f=results.get(id);
            outcomes.add(new List<Object>{id,f.concept,f.status,f.reason,f.evidenceIds,f.revision});
            if(f.status!='supported' && f.status!='not_applicable') acceptable=false;
        }
        // Positional schema explicitly versioned; raw JSON evidence is immutable source state.
        String payload=JSON.serialize(new List<Object>{'snapshot-v1',activeRuleVersion,w.Id,w.Supplier__c,w.As_Of__c,
            w.Source_Id__c,w.Document_Version__c,w.Source_Model__c,w.Source_Key__c,w.Revision__c,
            w.Evidence_JSON__c,sources,outcomes});
        if(payload.length()>64000) throw new DecisionException('Snapshot exceeds bounded storage; no truncation.');
        State state=new State();state.payload=payload;state.hash=digest(payload);state.acceptable=acceptable;return state;
    }
    @AuraEnabled
    public static Id capture(Id workspaceId,String expectedRevision) {
        permission('Etimad_Read');permission('Etimad_Verify');
        Etimad_Assessment__c w=workspace(workspaceId);
        if(String.isBlank(expectedRevision) || w.Revision__c!=expectedRevision) throw new DecisionException('Workspace changed. Refresh.');
        State state=current(w);
        Etimad_Snapshot__c record=new Etimad_Snapshot__c(Workspace__c=w.Id,Context_Hash__c=state.hash,
            Rule_Version__c=activeRuleVersion,Payload__c=state.payload);
        snapshotInsert=true;
        try { Database.insert(record,AccessLevel.USER_MODE); } finally { snapshotInsert=false; }
        return record.Id;
    }
    @AuraEnabled
    public static List<Etimad_Snapshot__c> listSnapshots(Id workspaceId) {
        permission('Etimad_Read');workspace(workspaceId);
        return [SELECT Id,Name,Context_Hash__c,Rule_Version__c,CreatedDate,Payload__c FROM Etimad_Snapshot__c
            WHERE Workspace__c=:workspaceId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 10];
    }
    /** Rechecks source, evidence, verification, rule version and all finding outcomes. */
    @AuraEnabled
    public static Id approve(Id snapshotId,String expectedContext) {
        permission('Etimad_Read');permission('Etimad_Approve');
        List<Etimad_Snapshot__c> rows=[SELECT Id,Workspace__c,Context_Hash__c,Rule_Version__c,Payload__c
            FROM Etimad_Snapshot__c WHERE Id=:snapshotId WITH USER_MODE LIMIT 1];
        if(rows.isEmpty()) throw new DecisionException('Snapshot unavailable.');
        Etimad_Snapshot__c snapshot=rows[0];
        Etimad_Assessment__c w=workspace(snapshot.Workspace__c);
        State state=current(w);
        if(String.isBlank(expectedContext) || expectedContext!=snapshot.Context_Hash__c ||
            snapshot.Rule_Version__c!=activeRuleVersion || digest(snapshot.Payload__c)!=snapshot.Context_Hash__c ||
            snapshot.Context_Hash__c!=state.hash) throw new DecisionException('Stale snapshot: capture and review a new assessment.');
        if(!state.acceptable) throw new DecisionException('Unresolved or unreviewed findings prevent acceptance.');
        String key=String.valueOf(snapshot.Id);
        List<Etimad_Approval__c> existing=[SELECT Id FROM Etimad_Approval__c WHERE Snapshot_Key__c=:key WITH USER_MODE LIMIT 1];
        if(!existing.isEmpty()) return existing[0].Id;
        Etimad_Approval__c acceptance=new Etimad_Approval__c(Snapshot__c=snapshot.Id,Snapshot_Key__c=key,
            Context_Hash__c=state.hash,Approved_By__c=UserInfo.getUserId(),Approved_At__c=System.now());
        approvalInsert=true;
        try { Database.insert(acceptance,AccessLevel.USER_MODE); } finally { approvalInsert=false; }
        return acceptance.Id;
    }
}
