/** @description Validates untrusted import data before any database operation. */
public with sharing class EtimadCandidateContract {
    /** @description Source-bound candidate DTO; deliberately contains no approval fields. */
    public class Candidate {
        public String importKey;
        public String sourceId;
        public String sourceHash;
        public String documentVersion;
        public String sourceUrl;
        public Integer pageCount;
        public Integer pdfPage;
        public String concept;
        public String fact;
        public String quote;
        public String hijri;
        public Date gregorian;
        public Boolean synthetic;
    }

    private static void check(Boolean condition, String message) {
        if (condition != true) { throw new EtimadReviewController.ReviewException(message); }
    }

    private static void text(String value, Integer maximum) {
        check(String.isNotBlank(value), 'Required source, fact or citation is missing.');
        check(value.length() <= maximum, 'Candidate field exceeds storage limit.');
    }

    /**
     * @description Validate and deduplicate a bounded request before database access.
     * @param payload JSON array containing only candidate fields.
     * @return Validated records keyed by immutable import identity.
     */
    public static Map<String, Etimad_Review__c> prepare(String payload) {
        check(String.isNotBlank(payload), 'Missing candidate payload.');
        check(payload.length() <= 150000, 'Oversized candidate payload.');
        List<Candidate> candidates = (List<Candidate>) JSON.deserializeStrict(payload, List<Candidate>.class);
        check(candidates != null, 'Candidate list is required.');
        check(!candidates.isEmpty() && candidates.size() <= 10, 'Import one through ten requirements.');
        Map<String, Etimad_Review__c> prepared = new Map<String, Etimad_Review__c>();
        for (Candidate c : candidates) {
            Etimad_Review__c row = toRecord(c);
            row.Revision__c = EtimadReviewController.revision(row);
            if (prepared.containsKey(c.importKey)) {
                check(prepared.get(c.importKey).Revision__c == row.Revision__c,
                    'Conflicting duplicate import key.');
            }
            prepared.put(c.importKey, row);
        }
        return prepared;
    }

    /**
     * @description Reject conflicting retries and return genuinely new candidates.
     * @param prepared Fully validated incoming records.
     * @param existing Records visible to the current user with matching keys.
     * @return Records that require insertion.
     */
    public static List<Etimad_Review__c> filterInserts(Map<String, Etimad_Review__c> prepared,
        Map<String, Etimad_Review__c> existing) {
        List<Etimad_Review__c> rows = new List<Etimad_Review__c>();
        for (String key : prepared.keySet()) {
            if (existing.containsKey(key)) {
                check(existing.get(key).Revision__c == prepared.get(key).Revision__c,
                    'Import key already identifies different content. Use a new version.');
            } else {
                rows.add(prepared.get(key));
            }
        }
        return rows;
    }

    /**
     * @description Rejects incomplete source contracts; evidence remains unverified.
     * @param c Candidate containing source identity and literal evidence.
     * @return An unsaved, provisional record.
     */
    public static Etimad_Review__c toRecord(Candidate c) {
        check(c != null, 'Candidate is required.');
        text(c.importKey, 100);
        text(c.sourceId, 100);
        text(c.sourceHash, 64);
        check(Pattern.matches('[a-f0-9]{64}', c.sourceHash), 'Invalid source hash.');
        text(c.documentVersion, 100);
        text(c.sourceUrl, 255);
        check(c.sourceUrl.startsWith('https://'), 'Source must use HTTPS.');
        text(c.concept, 100);
        text(c.fact, 8000);
        text(c.quote, 8000);
        check(c.pageCount != null && c.pdfPage != null, 'Missing page information.');
        check(c.pdfPage >= 1 && c.pdfPage <= c.pageCount && c.pageCount <= 10000,
            'Invalid citation page.');
        check(c.synthetic != null, 'Explicit source provenance required.');
        // Date conversion belongs to the deterministic parser, not arbitrary browser input.
        check(c.hijri == null && c.gregorian == null,
            'Deadline import needs its own cited calendar contract; not supported in this slice.');
        return new Etimad_Review__c(Import_Key__c=c.importKey,
            Source_Id__c=c.sourceId, Source_Hash__c=c.sourceHash, Source_URL__c=c.sourceUrl,
            Document_Version__c=c.documentVersion, PDF_Page__c=c.pdfPage, Page_Count__c=c.pageCount,
            Concept__c=c.concept, Fact__c=c.fact, Quote__c=c.quote, Synthetic__c=c.synthetic);
    }
}
