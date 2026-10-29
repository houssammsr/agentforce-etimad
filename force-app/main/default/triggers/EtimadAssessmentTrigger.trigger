trigger EtimadAssessmentTrigger on Etimad_Assessment__c (before insert, before update) {
    for(Etimad_Assessment__c row:Trigger.new) {
        if(EtimadAssessmentService.serviceWrite!=true) { row.addError('Use Etimad assessment actions.'); continue; }
        row.Revision__c=EtimadAssessmentService.fingerprint(row);
    }
}
