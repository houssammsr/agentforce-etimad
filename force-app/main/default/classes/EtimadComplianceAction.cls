/** Read-only, bulk-scoped source assessment for the conversational assistant.
 * Only SOFTWARE_SECURITY_V1 is supported; no whole-tender compliance claim.
 */
public with sharing class EtimadComplianceAction {
    /** Explicit selection and optional optimistic revision supplied to the read tool. */
    public class Request {
        @InvocableVariable(required=true description='Explicit selected Etimad assessment workspace record ID. Never infer a different workspace.')
        public String workspaceId;
        @InvocableVariable(description='Optional workspace revision from a prior result. A mismatch rejects stale context.')
        public String expectedRevision;
    }
    /** No source content is returned on failure. */
    public class Response {
        @InvocableVariable(description='OK, INVALID_REQUEST, UNAVAILABLE, STALE_CONTEXT or UNSUPPORTED_MODEL. Only OK contains source data.')
        public String status;
        @InvocableVariable(description='Metadata-only assessment JSON: scope, historical date, synthetic supplier warning, citation pages and deterministic findings. No source quotations or clause prose are returned.')
        public String summaryJson;
    }
    /**
     * @description Recompute bounded, authorized source findings without database writes.
     * @param requests Up to 200 selections, at most ten distinct workspaces.
     * @return One response for each input, preserving order including invalid inputs.
     */
    @InvocableMethod(label='Get Etimad scoped assessment' description='Read only. Recompute two Software security obligations using three reviewed source clauses and synthetic supplier assertions. Cannot verify, approve, create records or establish whole-tender eligibility.')
    public static List<Response> summarize(List<Request> requests) {
        if (!FeatureManagement.checkPermission('Etimad_Read')) {
            throw new EtimadAssessmentService.AssessmentException('Etimad permission required.');
        }
        if (requests == null || requests.size() > 200) {
            throw new EtimadAssessmentService.AssessmentException('At most 200 requests.');
        }
        Set<Id> ids = new Set<Id>();
        for (Request input : requests) {
            Id parsed = selectedId(input);
            if (parsed != null) { ids.add(parsed); }
        }
        if (ids.size() > 10) { throw new EtimadAssessmentService.AssessmentException('At most ten distinct workspaces.'); }
        Map<Id, Etimad_Assessment__c> workspaces = new Map<Id, Etimad_Assessment__c>();
        Map<Id, List<Etimad_Review__c>> clauses = new Map<Id, List<Etimad_Review__c>>();
        if (!ids.isEmpty()) {
            workspaces = new Map<Id, Etimad_Assessment__c>([
                SELECT Id, Supplier__c, As_Of__c, Source_Id__c, Document_Version__c,
                    Evidence_JSON__c, Revision__c, Source_Model__c, Source_Key__c
                FROM Etimad_Assessment__c WHERE Id IN :ids WITH USER_MODE
            ]);
            // Bounded prototype: excess dependencies cannot be presented as a complete source model.
            List<Etimad_Review__c> selectedClauses = [
                SELECT Id, Assessment__c, Concept__c, Source_Id__c, Source_Hash__c, Document_Version__c,
                    PDF_Page__c, Revision__c, Verified_Revision__c
                FROM Etimad_Review__c WHERE Assessment__c IN :workspaces.keySet()
                WITH USER_MODE ORDER BY Id LIMIT 31
            ];
            if (selectedClauses.size() == 31) {
                throw new EtimadAssessmentService.AssessmentException('Source dependency bound exceeded; no partial assessment.');
            }
            for (Etimad_Review__c row : selectedClauses) {
                addClause(clauses, row);
            }
        }
        return responsesFor(requests, workspaces, clauses);
    }
    private static void addClause(Map<Id, List<Etimad_Review__c>> clauses, Etimad_Review__c row) {
        if (!clauses.containsKey(row.Assessment__c)) { clauses.put(row.Assessment__c, new List<Etimad_Review__c>()); }
        clauses.get(row.Assessment__c).add(row);
    }
    private static List<Response> responsesFor(List<Request> requests,
        Map<Id, Etimad_Assessment__c> workspaces, Map<Id, List<Etimad_Review__c>> clauses) {
        List<Response> responses = new List<Response>();
        Map<Id, String> prepared = new Map<Id, String>();
        for (Integer i = 0; i < requests.size(); i++) {
            Response output = new Response();
            Id id = selectedId(requests[i]);
            Etimad_Assessment__c w = workspaces.get(id);
            output.status = responseStatus(id, w, requests[i]);
            if (output.status == 'OK') {
                if (!prepared.containsKey(id)) { prepared.put(id, build(w, clauses.get(id))); }
                output.summaryJson = prepared.get(id);
            }
            responses.add(output);
        }
        return responses;
    }
    private static Id selectedId(Request input) {
        if (input == null || String.isBlank(input.workspaceId)) { return null; }
        try {
            Id parsed = Id.valueOf(input.workspaceId);
            return parsed.getSObjectType() == Etimad_Assessment__c.SObjectType ? parsed : null;
        } catch (Exception e) { return null; }
    }
    private static String responseStatus(Id id, Etimad_Assessment__c w, Request input) {
        if (id == null) { return 'INVALID_REQUEST'; }
        if (w == null) { return 'UNAVAILABLE'; }
        if (input.expectedRevision != null && input.expectedRevision != w.Revision__c) { return 'STALE_CONTEXT'; }
        if (w.Source_Model__c != 'SOFTWARE_SECURITY_V1') { return 'UNSUPPORTED_MODEL'; }
        return 'OK';
    }
    private static String build(Etimad_Assessment__c w, List<Etimad_Review__c> rows) {
        if (w.Revision__c != EtimadAssessmentService.fingerprint(w)) {
            throw new EtimadAssessmentService.AssessmentException('Workspace integrity failure.');
        }
        if (rows == null) { rows = new List<Etimad_Review__c>(); }
        Set<String> concepts = new Set<String>();
        Boolean reviewed = true;
        List<Object> citations = new List<Object>();
        List<String> revisions = new List<String>{w.Revision__c};
        for (Etimad_Review__c row : rows) {
            concepts.add(row.Concept__c);
            Boolean current = row.Verified_Revision__c == row.Revision__c && row.Revision__c != null &&
                row.Source_Id__c == w.Source_Id__c && row.Source_Hash__c == w.Document_Version__c &&
                row.Document_Version__c == w.Document_Version__c;
            reviewed = reviewed && current;
            revisions.add(row.Revision__c + ':' + String.valueOf(row.Verified_Revision__c));
            citations.add(new Map<String,Object>{'reviewId'=>row.Id, 'concept'=>row.Concept__c,
                'pdfPage'=>row.PDF_Page__c,
                'sourceReviewed'=>current, 'revision'=>row.Revision__c});
        }
        Boolean complete = rows.size() == 3 && concepts == new Set<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'};
        List<EtimadAssessmentService.Evidence> evidence = EtimadAssessmentService.parse(w.Evidence_JSON__c, w.Supplier__c);
        List<Object> findings = new List<Object>();
        for (String concept : new List<String>{'BID_SECURITY','SME_CERTIFICATE'}) {
            EtimadCompoundRules.Result finding = new EtimadCompoundRules.Result();
            finding.reason = complete ? 'SOURCE_RELATIONSHIPS_NOT_REVIEWED' : 'SOURCE_CLAUSES_INCOMPLETE';
            if (complete && reviewed) { finding = EtimadCompoundRules.evaluate(concept, evidence, w.As_Of__c, w.Supplier__c); }
            findings.add(new Map<String,Object>{'concept'=>concept,'status'=>finding.status,
                'reason'=>finding.reason,'evidenceIds'=>finding.evidenceIds});
        }
        revisions.sort();
        String context = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256',Blob.valueOf(JSON.serialize(revisions))));
        return JSON.serialize(new Map<String,Object>{'schema'=>'agent-summary-v2','workspaceId'=>w.Id,
            'workspaceRevision'=>w.Revision__c,'contextRevision'=>context,'asOf'=>w.As_Of__c,
            'sourceId'=>w.Source_Id__c,'documentVersion'=>w.Document_Version__c,'model'=>w.Source_Model__c,
            'scope'=>'Initial financial bid-guarantee and conditional SME-certificate obligations only; not whole-tender eligibility or bid approval.',
            'sourceTextIncluded'=>false,
            'supplierEvidence'=>'Synthetic demonstration assertions, not real company documents.',
            'sourceComplete'=>complete,'sourceReviewed'=>complete && reviewed,'clauses'=>citations,'findings'=>findings});
    }
}