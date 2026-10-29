/** Source-scoped condition model; never authorizes a mutation. */
public with sharing class EtimadCompoundRules {
    public class Result {
        public String status='unknown';
        public String reason='NO_CURRENT_VERIFIED_EVIDENCE';
        public List<String> evidenceIds=new List<String>();
    }
    private static String state(String concept,List<EtimadAssessmentService.Evidence> evidence,Set<String> used) {
        Set<Boolean> values=new Set<Boolean>();
        for(EtimadAssessmentService.Evidence e:evidence) if(e.concept==concept) { values.add(e.assertion); used.add(e.id); }
        return values.size()>1 ? 'conflicting' : values.isEmpty() ? 'unknown' : values.contains(true) ? 'true' : 'false';
    }
    private static String allOf(List<String> concepts,List<EtimadAssessmentService.Evidence> evidence,Set<String> used) {
        Set<String> values=new Set<String>();
        for(String c:concepts) values.add(state(c,evidence,used));
        if(values.contains('conflicting')) return 'conflicting';
        if(values.contains('false')) return 'false';
        return values.contains('unknown') ? 'unknown' : 'true';
    }
    public static Result evaluate(String concept,List<EtimadAssessmentService.Evidence> evidence,Date asOf,String supplier) {
        Result r=new Result(); Set<String> used=new Set<String>();
        List<EtimadAssessmentService.Evidence> current=new List<EtimadAssessmentService.Evidence>();
        for(EtimadAssessmentService.Evidence e:evidence)
            if(e.verified && e.supplierId==supplier && e.validFrom<=asOf && e.validTo>=asOf) current.add(e);
        String applies=concept=='SME_CERTIFICATE' ? state('OMITS_INITIAL_SECURITY',current,used) : 'true';
        String exemption='false';
        if(applies=='conflicting') { r.status='conflicting'; r.reason='APPLICABILITY_EVIDENCE_CONFLICT'; }
        else if(applies=='false') { r.status='not_applicable'; r.reason='APPLICABILITY_DISPROVED'; }
        else if(applies=='unknown') r.reason='APPLICABILITY_UNRESOLVED';
        else {
            if(concept=='BID_SECURITY') exemption=allOf(new List<String>{'LOCAL_ESTABLISHMENT','SME_CLASSIFICATION','SME_CERTIFICATE'},current,used);
            if(exemption=='conflicting') { r.status='conflicting'; r.reason='EXCEPTION_EVIDENCE_CONFLICT'; }
            else if(exemption=='true') { r.status='not_applicable'; r.reason='REVIEWED_COMPOUND_EXCEPTION_SUPPORTED'; }
            else {
                String direct=state(concept,current,used);
                if(direct=='conflicting') { r.status='conflicting'; r.reason='DIRECT_EVIDENCE_CONFLICT'; }
                else if(direct=='true') { r.status='supported'; r.reason='VERIFIED_DIRECT_EVIDENCE'; }
                else if(direct=='false' && exemption=='unknown') r.reason='EXCEPTION_APPLICABILITY_UNRESOLVED';
                else if(direct=='false') { r.status='gap'; r.reason='VERIFIED_DIRECT_EVIDENCE'; }
            }
        }
        r.evidenceIds.addAll(used); r.evidenceIds.sort(); return r;
    }
}
