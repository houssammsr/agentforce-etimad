/** Bounded synthetic assessment workspace. No external uploads or automatic approvals. */
public with sharing class EtimadAssessmentService {
    public static Boolean serviceWrite { get; private set; }
    public class AssessmentException extends Exception {}
    public class Evidence {
        public String id;
        public String supplierId;
        public String concept;
        public Boolean verified;
        public Date validFrom;
        public Date validTo;
        public Boolean assertion;
    }
    public class Finding {
        @AuraEnabled public Id reviewId;
        @AuraEnabled public String concept;
        @AuraEnabled public String status;
        @AuraEnabled public String reason;
        @AuraEnabled public String evidenceIds;
        @AuraEnabled public String revision;
    }
    private static void permission(String name) {
        if (!FeatureManagement.checkPermission(name)) throw new AssessmentException('Etimad permission required.');
    }
    public static String fingerprint(Etimad_Assessment__c row) {
        List<Object> parts=new List<Object>{row.Supplier__c,row.As_Of__c,row.Evidence_JSON__c,row.Source_Id__c,row.Document_Version__c};
        if(row.Source_Model__c!=null) { parts.add(row.Source_Model__c); parts.add(row.Source_Key__c); }
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(JSON.serialize(parts))));
    }
    @AuraEnabled
    public static List<Etimad_Assessment__c> listWorkspaces() {
        permission('Etimad_Read');
        return [SELECT Id,Name,Supplier__c,As_Of__c,Source_Id__c,Document_Version__c,
            Evidence_JSON__c,Revision__c,Source_Model__c,Source_Key__c FROM Etimad_Assessment__c WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 10];
    }
    /** Evidence editing is not verification: edits always clear verification flags. */
    @AuraEnabled
    public static void saveEvidence(Id workspaceId,String expectedRevision,String payload) {
        permission('Etimad_Verify');
        Etimad_Assessment__c row=locked(workspaceId,expectedRevision);
        List<Evidence> evidence=parse(payload,row.Supplier__c);
        for(Evidence e:evidence) e.verified=false;
        write(new Etimad_Assessment__c(Id=row.Id,Evidence_JSON__c=JSON.serialize(evidence)));
    }
    /** Explicit human attestation of one synthetic fixture item. */
    @AuraEnabled
    public static void verifyEvidence(Id workspaceId,String expectedRevision,String evidenceId) {
        permission('Etimad_Verify');
        Etimad_Assessment__c row=locked(workspaceId,expectedRevision);
        List<Evidence> evidence=parse(row.Evidence_JSON__c,row.Supplier__c);
        Boolean found=false;
        for(Evidence e:evidence) if(e.id==evidenceId) { e.verified=true; found=true; }
        if(!found) throw new AssessmentException('Evidence unavailable.');
        write(new Etimad_Assessment__c(Id=row.Id,Evidence_JSON__c=JSON.serialize(evidence)));
    }
    private static Etimad_Assessment__c locked(Id id,String revision) {
        List<Etimad_Assessment__c> rows=[SELECT Id,Supplier__c,As_Of__c,Source_Id__c,
            Document_Version__c,Evidence_JSON__c,Revision__c,Source_Model__c,Source_Key__c FROM Etimad_Assessment__c
            WHERE Id=:id WITH USER_MODE LIMIT 1 FOR UPDATE];
        if(rows.isEmpty() || String.isBlank(revision) || rows[0].Revision__c!=revision)
            throw new AssessmentException('Workspace changed or unavailable. Refresh.');
        return rows[0];
    }
    public static List<Evidence> parse(String payload,String supplier) {
        if(String.isBlank(payload) || payload.length()>16000) throw new AssessmentException('Invalid evidence payload.');
        List<Evidence> rows=(List<Evidence>)JSON.deserializeStrict(payload,List<Evidence>.class);
        if(rows==null || rows.size()>20) throw new AssessmentException('At most 20 evidence items.');
        Set<String> ids=new Set<String>();
        for(Evidence e:rows) {
            if(e==null || String.isBlank(e.id) || e.id.length()>100 || ids.contains(e.id) ||
                e.supplierId!=supplier || String.isBlank(e.concept) || e.concept.length()>100 ||
                e.verified==null || e.assertion==null || e.validFrom==null || e.validTo==null || e.validFrom>e.validTo)
                throw new AssessmentException('Invalid evidence identity, scope or dates.');
            ids.add(e.id);
        }
        return rows;
    }
    private static void write(Etimad_Assessment__c row) {
        serviceWrite=true;
        try { Database.update(row,AccessLevel.USER_MODE); } finally { serviceWrite=false; }
    }
    /** Always recompute; no stale persisted result can be mistaken for a current finding. */
    @AuraEnabled
    public static List<Finding> assess(Id workspaceId,String expectedRevision) {
        permission('Etimad_Read');
        Etimad_Assessment__c workspace=locked(workspaceId,expectedRevision);
        List<Evidence> all=parse(workspace.Evidence_JSON__c,workspace.Supplier__c);
        if(workspace.Source_Model__c!=null) return assessSource(workspace,all);
        List<Finding> results=new List<Finding>();
        for(Etimad_Review__c row:[SELECT Id,Concept__c,Revision__c,Verified_Revision__c,
            Exception_Concept__c,Document_Version__c FROM Etimad_Review__c
            WHERE Assessment__c=:workspaceId WITH USER_MODE ORDER BY Name LIMIT 11]) {
            if(results.size()==10) throw new AssessmentException('Workspace exceeds ten requirements.');
            Finding f=new Finding(); f.reviewId=row.Id; f.concept=row.Concept__c;
            f.revision=workspace.Revision__c+':'+row.Revision__c; f.evidenceIds='';
            f.status='unknown'; f.reason='NO_CURRENT_VERIFIED_EVIDENCE';
            if(row.Document_Version__c!=workspace.Document_Version__c) f.reason='STALE_SOURCE_VERSION';
            else if(row.Verified_Revision__c!=row.Revision__c) f.reason='REQUIREMENT_NOT_REVIEWED';
            else {
                List<Evidence> direct=new List<Evidence>(); List<Evidence> exceptions=new List<Evidence>();
                for(Evidence e:all) if(e.verified && e.validFrom<=workspace.As_Of__c && e.validTo>=workspace.As_Of__c) {
                    if(e.concept==row.Concept__c) direct.add(e);
                    if(e.concept==row.Exception_Concept__c) exceptions.add(e);
                }
                if(conflict(exceptions)) setFinding(f,'conflicting','EXCEPTION_EVIDENCE_CONFLICT',exceptions);
                else if(positive(exceptions)) setFinding(f,'not_applicable','REVIEWED_EXCEPTION_SUPPORTED',exceptions);
                else if(conflict(direct)) setFinding(f,'conflicting','DIRECT_EVIDENCE_CONFLICT',direct);
                else if(!direct.isEmpty() && !direct[0].assertion && String.isNotBlank(row.Exception_Concept__c) && exceptions.isEmpty())
                    setFinding(f,'unknown','EXCEPTION_APPLICABILITY_UNRESOLVED',direct);
                else if(!direct.isEmpty()) setFinding(f,direct[0].assertion?'supported':'gap','VERIFIED_DIRECT_EVIDENCE',direct);
            }
            results.add(f);
        }
        return results;
    }
    /** Three cited clauses must each be human-reviewed before compound assessment. */
    private static List<Finding> assessSource(Etimad_Assessment__c w,List<Evidence> evidence) {
        if(w.Source_Model__c!='SOFTWARE_SECURITY_V1') throw new AssessmentException('Unknown source model.');
        List<Etimad_Review__c> clauses=[SELECT Id,Concept__c,Revision__c,Verified_Revision__c,Source_Id__c,
            Source_Hash__c,Document_Version__c FROM Etimad_Review__c WHERE Assessment__c=:w.Id WITH USER_MODE LIMIT 4];
        Set<String> concepts=new Set<String>(); Boolean reviewed=true; List<String> revisions=new List<String>();
        for(Etimad_Review__c c:clauses) {
            concepts.add(c.Concept__c); revisions.add(c.Revision__c+':'+String.valueOf(c.Verified_Revision__c));
            if(c.Verified_Revision__c!=c.Revision__c || c.Source_Id__c!=w.Source_Id__c ||
                c.Source_Hash__c!=w.Document_Version__c || c.Document_Version__c!=w.Document_Version__c) reviewed=false;
        }
        Boolean complete=clauses.size()==3 && concepts==new Set<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'};
        revisions.sort(); String context=EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(w.Revision__c+String.join(revisions,':'))));
        List<Finding> findings=new List<Finding>();
        for(Etimad_Review__c c:clauses) if(c.Concept__c!='SME_EXCEPTION') {
            Finding f=new Finding(); f.reviewId=c.Id; f.concept=c.Concept__c; f.revision=context; f.evidenceIds=''; f.status='unknown';
            f.reason=!complete ? 'SOURCE_CLAUSES_INCOMPLETE' : 'SOURCE_RELATIONSHIPS_NOT_REVIEWED';
            if(complete && reviewed) {
                EtimadCompoundRules.Result r=EtimadCompoundRules.evaluate(c.Concept__c,evidence,w.As_Of__c,w.Supplier__c);
                f.status=r.status; f.reason=r.reason; f.evidenceIds=String.join(r.evidenceIds,', ');
            }
            findings.add(f);
        }
        return findings;
    }
    public class SourceInput {
        public String supplier;
        public Date asOf;
        public List<EtimadCandidateContract.Candidate> candidates;
    }
    /** Provisional source clauses plus synthetic supplier; no source attestation. */
    @AuraEnabled
    public static Id importSoftwareWorkspace(String payload) {
        permission('Etimad_Import');
        if(String.isBlank(payload) || payload.length()>32000) throw new AssessmentException('Invalid workspace payload.');
        SourceInput input=(SourceInput)JSON.deserializeStrict(payload,SourceInput.class);
        if(input==null || input.supplier!='SYNTHETIC-SOFTWARE-SUPPLIER' || input.asOf==null || input.candidates==null || input.candidates.size()!=3)
            throw new AssessmentException('Explicit synthetic supplier, date and three clauses required.');
        Map<String,Etimad_Review__c> rows=EtimadCandidateContract.prepare(JSON.serialize(input.candidates));
        Set<String> concepts=new Set<String>(); Set<String> hashes=new Set<String>(); List<String> revisions=new List<String>();
        for(Etimad_Review__c row:rows.values()) {
            if(row.Source_Id__c!='TAQEEM-SOFTWARE-2026' || row.Synthetic__c || row.Document_Version__c!=row.Source_Hash__c)
                throw new AssessmentException('Software source identity/version required.');
            concepts.add(row.Concept__c); hashes.add(row.Source_Hash__c); revisions.add(row.Revision__c);
        }
        if(rows.size()!=3 || hashes.size()!=1 || concepts!=new Set<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'})
            throw new AssessmentException('Complete distinct source clauses required.');
        revisions.sort(); String hash; for(String value:hashes) hash=value;
        String key=EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(input.supplier+String.valueOf(input.asOf)+String.join(revisions,':'))));
        List<Etimad_Assessment__c> existing=[SELECT Id FROM Etimad_Assessment__c WHERE Source_Key__c=:key WITH USER_MODE LIMIT 1];
        if(!existing.isEmpty()) return existing[0].Id;
        Savepoint checkpoint=Database.setSavepoint();
        try {
            Etimad_Assessment__c w=new Etimad_Assessment__c(Supplier__c=input.supplier,As_Of__c=input.asOf,
                Source_Id__c='TAQEEM-SOFTWARE-2026',Document_Version__c=hash,Evidence_JSON__c='[]',
                Source_Model__c='SOFTWARE_SECURITY_V1',Source_Key__c=key);
            serviceWrite=true;
            try { Database.insert(w,AccessLevel.USER_MODE); } finally { serviceWrite=false; }
            for(EtimadCandidateContract.Candidate c:input.candidates)
                c.importKey=EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(w.Id+':'+c.concept)));
            List<Id> ids=EtimadReviewController.importCandidates(JSON.serialize(input.candidates));
            EtimadReviewController.linkSource(w.Id,ids);
            return w.Id;
        } catch(Exception e) {
            Database.rollback(checkpoint); throw new AssessmentException('Source workspace import failed; no partial changes committed.');
        }
    }
    private static Boolean positive(List<Evidence> rows) { for(Evidence e:rows) if(e.assertion) return true; return false; }
    private static Boolean conflict(List<Evidence> rows) {
        Set<Boolean> values=new Set<Boolean>(); for(Evidence e:rows) values.add(e.assertion); return values.size()>1;
    }
    private static void setFinding(Finding f,String status,String reason,List<Evidence> rows) {
        f.status=status; f.reason=reason; List<String> ids=new List<String>();
        for(Evidence e:rows) ids.add(e.id); ids.sort(); f.evidenceIds=String.join(ids,', ');
    }
    /** A bounded synthetic scenario only; never imports or attests to real source content. */
    @AuraEnabled
    public static Id createDemo() {
        permission('Etimad_Import'); permission('Etimad_Verify');
        Etimad_Assessment__c workspace=new Etimad_Assessment__c(Supplier__c='SYNTHETIC-SUPPLIER',
            As_Of__c=Date.newInstance(2026,6,1),Source_Id__c='SYN-PHASE3',Document_Version__c='synthetic-v1',
            Evidence_JSON__c='[{"id":"SYN-SME","supplierId":"SYNTHETIC-SUPPLIER","concept":"LOCAL_SME_CERT","verified":false,"validFrom":"2026-01-01","validTo":"2026-12-31","assertion":true}]');
        serviceWrite=true;
        try { Database.insert(workspace,AccessLevel.USER_MODE); } finally { serviceWrite=false; }
        List<Object> candidates=new List<Object>();
        for(String concept:new List<String>{'BID_SECURITY','LOCAL_SME_CERT','FINAL_SECURITY'}) candidates.add(new Map<String,Object>{
            'importKey'=>workspace.Id+'-'+concept,'sourceId'=>'SYN-PHASE3','sourceHash'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'documentVersion'=>'synthetic-v1','sourceUrl'=>'https://example.invalid/synthetic','pageCount'=>3,'pdfPage'=>1,
            'concept'=>concept,'fact'=>'SYNTHETIC demonstration: '+concept,'quote'=>'Synthetic source fixture; not an actual tender.',
            'synthetic'=>true});
        List<Id> ids=EtimadReviewController.importCandidates(JSON.serialize(candidates));
        // linkSynthetic reads this nullable field for every row, including non-exempt requirements.
        List<Etimad_Review__c> reviews=[SELECT Id,Concept__c,Exception_Concept__c FROM Etimad_Review__c WHERE Id IN :ids WITH USER_MODE];
        for(Etimad_Review__c r:reviews) { r.Assessment__c=workspace.Id; if(r.Concept__c=='BID_SECURITY') r.Exception_Concept__c='LOCAL_SME_CERT'; }
        EtimadReviewController.linkSynthetic(reviews);
        return workspace.Id;
    }
}
