trigger EtimadApprovalTrigger on Etimad_Approval__c (before insert, before update, before delete, after undelete) {
    List<Etimad_Approval__c> rows=Trigger.isDelete ? Trigger.old : Trigger.new;
    for(Etimad_Approval__c row:rows)
        if(!Trigger.isInsert || EtimadDecisionService.approvalInsert!=true)
            row.addError('Assessment acceptance is append-only; use approve.');
}
