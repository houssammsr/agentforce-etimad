trigger EtimadReviewTrigger on Etimad_Review__c (before insert, before update) {
    EtimadReviewGuard.enforce(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
}
