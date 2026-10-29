trigger EtimadSnapshotTrigger on Etimad_Snapshot__c (before insert, before update, before delete, after undelete) {
    List<Etimad_Snapshot__c> rows=Trigger.isDelete ? Trigger.old : Trigger.new;
    for(Etimad_Snapshot__c row:rows)
        if(!Trigger.isInsert || EtimadDecisionService.snapshotInsert!=true)
            row.addError('Assessment snapshots are append-only; use capture.');
}
