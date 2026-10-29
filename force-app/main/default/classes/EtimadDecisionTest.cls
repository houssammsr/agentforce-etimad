@IsTest
private class EtimadDecisionTest {
    @TestSetup static void setupUsers() {
        Id profile=[SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id;
        List<User> people=new List<User>();
        for(String alias:new List<String>{'edsfull','edsread'}) people.add(new User(Alias=alias,LastName=alias,
            Email=alias+'@example.invalid',Username=alias+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
            TimeZoneSidKey='Asia/Riyadh',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',ProfileId=profile));
        insert people;List<PermissionSetAssignment> grants=new List<PermissionSetAssignment>();
        for(PermissionSet p:[SELECT Id,Name FROM PermissionSet WHERE Name IN
            ('Etimad_Importer','Etimad_Reviewer','Etimad_Phase3_Data','Etimad_Reader','Etimad_Phase3_Read','Etimad_Decision_Data','Etimad_Decision_Read')]) {
            Boolean read=p.Name=='Etimad_Reader' || p.Name=='Etimad_Phase3_Read' || p.Name=='Etimad_Decision_Read';
            grants.add(new PermissionSetAssignment(AssigneeId=read?people[1].Id:people[0].Id,PermissionSetId=p.Id));
        }
        insert grants;
    }
    private static User actor(String alias) { return [SELECT Id FROM User WHERE Alias=:alias LIMIT 1]; }
    private static Etimad_Assessment__c workspace() { return EtimadAssessmentService.listWorkspaces()[0]; }
    private static Etimad_Assessment__c ready() {
        EtimadAssessmentService.createDemo();Etimad_Assessment__c w=workspace();
        for(Etimad_Review__c r:EtimadReviewController.listReviews())
            EtimadReviewController.verifyEvidence(r.Id,r.Revision__c,'Synthetic isolated test only.');
        List<EtimadAssessmentService.Evidence> evidence=new List<EtimadAssessmentService.Evidence>();
        for(String concept:new List<String>{'BID_SECURITY','LOCAL_SME_CERT','FINAL_SECURITY'}) {
            EtimadAssessmentService.Evidence e=new EtimadAssessmentService.Evidence();
            e.id=concept;e.supplierId=w.Supplier__c;e.concept=concept;e.verified=false;e.assertion=true;
            e.validFrom=w.As_Of__c.addDays(-1);e.validTo=w.As_Of__c.addDays(1);evidence.add(e);
        }
        EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,JSON.serialize(evidence));
        for(EtimadAssessmentService.Evidence e:evidence) {
            w=workspace();EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,e.id);
        }
        return workspace();
    }
    private static void reject(Id snapshotId,String hash,String message) {
        try { EtimadDecisionService.approve(snapshotId,hash);Assert.fail('Must reject '+message); }
        catch(EtimadDecisionService.DecisionException e) { Assert.isTrue(e.getMessage().contains(message),e.getMessage()); }
    }
    @IsTest static void immutableCaptureAndIdempotentApproval() {
        System.runAs(actor('edsfull')) {
            Etimad_Assessment__c w=ready();Id id=EtimadDecisionService.capture(w.Id,w.Revision__c);
            Etimad_Snapshot__c s=EtimadDecisionService.listSnapshots(w.Id)[0];Assert.areEqual(id,s.Id);
            Id accepted=EtimadDecisionService.approve(id,s.Context_Hash__c);
            Assert.areEqual(accepted,EtimadDecisionService.approve(id,s.Context_Hash__c));
            Assert.areEqual(1,[SELECT count() FROM Etimad_Approval__c]);
            Assert.areEqual(0,[SELECT count() FROM Task]);
            Assert.isFalse(Database.update(new Etimad_Snapshot__c(Id=id,Payload__c='changed'),false,AccessLevel.SYSTEM_MODE).isSuccess());
            Assert.isFalse(Database.delete(new Etimad_Snapshot__c(Id=id),false,AccessLevel.SYSTEM_MODE).isSuccess());
            Assert.isFalse(Database.update(new Etimad_Approval__c(Id=accepted,Context_Hash__c='changed'),false,AccessLevel.SYSTEM_MODE).isSuccess());
            Assert.isFalse(Database.delete(new Etimad_Approval__c(Id=accepted),false,AccessLevel.SYSTEM_MODE).isSuccess());
            Assert.isFalse(Database.insert(new Etimad_Snapshot__c(Workspace__c=w.Id),false,AccessLevel.SYSTEM_MODE).isSuccess());
            Assert.isFalse(Database.insert(new Etimad_Approval__c(Snapshot__c=id),false,AccessLevel.SYSTEM_MODE).isSuccess());
        }
    }
    @IsTest static void evidenceChangesInvalidateSnapshot() {
        System.runAs(actor('edsfull')) {
            Etimad_Assessment__c w=ready();Id id=EtimadDecisionService.capture(w.Id,w.Revision__c);
            Etimad_Snapshot__c s=EtimadDecisionService.listSnapshots(w.Id)[0];
            String payload=[SELECT Payload__c FROM Etimad_Snapshot__c WHERE Id=:id].Payload__c;
            EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,'[]');reject(id,s.Context_Hash__c,'Stale');
            Assert.areEqual(payload,[SELECT Payload__c FROM Etimad_Snapshot__c WHERE Id=:id].Payload__c);
            Assert.areEqual(0,[SELECT count() FROM Etimad_Approval__c]);
        }
    }
    @IsTest static void sourceAndRuleChangesInvalidateSnapshot() {
        System.runAs(actor('edsfull')) {
            Etimad_Assessment__c w=ready();Id id=EtimadDecisionService.capture(w.Id,w.Revision__c);
            Etimad_Snapshot__c s=EtimadDecisionService.listSnapshots(w.Id)[0];
            String version=EtimadDecisionService.activeRuleVersion;
            EtimadDecisionService.activeRuleVersion='simulated-rule-upgrade';
            reject(id,s.Context_Hash__c,'Stale');EtimadDecisionService.activeRuleVersion=version;
            Etimad_Review__c r=EtimadReviewController.listReviews()[0];
            EtimadReviewController.correctFact(r.Id,r.Revision__c,'Changed synthetic source interpretation');
            reject(id,s.Context_Hash__c,'Stale');
            Assert.areEqual(0,[SELECT count() FROM Etimad_Approval__c]);
        }
    }
    @IsTest static void unresolvedAndStaleCaptureRejected() {
        System.runAs(actor('edsfull')) {
            EtimadAssessmentService.createDemo();Etimad_Assessment__c w=workspace();
            Id id=EtimadDecisionService.capture(w.Id,w.Revision__c);
            Etimad_Snapshot__c s=EtimadDecisionService.listSnapshots(w.Id)[0];reject(id,s.Context_Hash__c,'Unresolved');
            reject(id,'wrong','Stale');
            try { EtimadDecisionService.capture(w.Id,'old');Assert.fail('Stale capture'); }
            catch(EtimadDecisionService.DecisionException e) { Assert.isTrue(e.getMessage().contains('changed')); }
        }
    }
    @IsTest static void readerCannotCaptureOrApprovePrivateSnapshot() {
        Id workspaceId;Id snapshotId;
        System.runAs(actor('edsfull')) {
            Etimad_Assessment__c w=ready();workspaceId=w.Id;snapshotId=EtimadDecisionService.capture(w.Id,w.Revision__c);
        }
        System.runAs(actor('edsread')) {
            reject(snapshotId,'fake','permission');
            try { EtimadDecisionService.capture(workspaceId,'fake');Assert.fail('No verification grant'); }
            catch(EtimadDecisionService.DecisionException e) { Assert.isTrue(e.getMessage().contains('permission')); }
            try { EtimadDecisionService.listSnapshots(workspaceId);Assert.fail('Private workspace'); }
            catch(EtimadDecisionService.DecisionException e) { Assert.isTrue(e.getMessage().contains('unavailable')); }
        }
    }
}
