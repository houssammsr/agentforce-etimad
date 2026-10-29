@IsTest
private class EtimadReviewControllerTest {
    @TestSetup
    static void setupUsers() {
        Id profileId = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id;
        List<User> people = new List<User>();
        for (String alias : new List<String>{'etrfull','etrread','etrnone'}) {
            people.add(new User(Alias=alias, LastName=alias, Email=alias+'@example.invalid',
                Username=alias+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
                TimeZoneSidKey='Asia/Riyadh', LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US', ProfileId=profileId));
        }
        insert people;
        Map<String, Id> permissionIds = new Map<String, Id>();
        for (PermissionSet p : [SELECT Id, Name FROM PermissionSet WHERE Name IN
            ('Etimad_Importer','Etimad_Reviewer','Etimad_Reader')]) { permissionIds.put(p.Name,p.Id); }
        insert new List<PermissionSetAssignment>{
            new PermissionSetAssignment(AssigneeId=people[0].Id,PermissionSetId=permissionIds.get('Etimad_Importer')),
            new PermissionSetAssignment(AssigneeId=people[0].Id,PermissionSetId=permissionIds.get('Etimad_Reviewer')),
            new PermissionSetAssignment(AssigneeId=people[1].Id,PermissionSetId=permissionIds.get('Etimad_Reader'))};
    }
    private static User person(String alias) { return [SELECT Id FROM User WHERE Alias=:alias LIMIT 1]; }
    private static String payload(String key) {
        return JSON.serialize(new List<Object>{new Map<String,Object>{'importKey'=>key,
            'sourceId'=>'SYN-PHASE2','sourceHash'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'documentVersion'=>'v1','sourceUrl'=>'https://example.invalid/synthetic',
            'pageCount'=>2,'pdfPage'=>2,'concept'=>'BID_SECURITY','fact'=>'Synthetic requirement',
            'quote'=>'Synthetic original evidence','synthetic'=>true}});
    }
    private static Etimad_Review__c candidate() {
        EtimadReviewController.importCandidates(payload('synthetic-key'));
        return EtimadReviewController.listReviews()[0];
    }
    @IsTest static void importAndApprovalAreIdempotent() {
        System.runAs(person('etrfull')) {
            Etimad_Review__c row=candidate();
            Assert.areEqual(row.Id,EtimadReviewController.importCandidates(payload('synthetic-key'))[0]);
            EtimadReviewController.verifyEvidence(row.Id,row.Revision__c,'Checked synthetic page 2.');
            Id taskId=EtimadReviewController.approveTask(row.Id,row.Revision__c);
            Assert.areEqual(taskId,EtimadReviewController.approveTask(row.Id,row.Revision__c));
            Assert.areEqual(1,[SELECT count() FROM Task WHERE WhatId=:row.Id]);
        }
    }
    @IsTest static void unverifiedAndStaleAreRejected() {
        System.runAs(person('etrfull')) {
            Etimad_Review__c row=candidate();
            try { EtimadReviewController.approveTask(row.Id,row.Revision__c); Assert.fail('Must reject'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('Verify')); }
            EtimadReviewController.verifyEvidence(row.Id,row.Revision__c,'Source checked.');
            EtimadReviewController.correctFact(row.Id,row.Revision__c,'Corrected requirement');
            try { EtimadReviewController.approveTask(row.Id,row.Revision__c); Assert.fail('Must reject stale'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('changed')); }
            Etimad_Review__c changed=EtimadReviewController.listReviews()[0];
            Assert.isNull(changed.Verified_Revision__c);
            Assert.areEqual(0,[SELECT count() FROM Task WHERE WhatId=:row.Id]);
        }
    }
    @IsTest static void correctedApprovedRecordCannotDuplicateTask() {
        System.runAs(person('etrfull')) {
            Etimad_Review__c row=candidate();
            EtimadReviewController.verifyEvidence(row.Id,row.Revision__c,'Source checked.');
            EtimadReviewController.approveTask(row.Id,row.Revision__c);
            EtimadReviewController.correctFact(row.Id,row.Revision__c,'New corrected fact');
            row=EtimadReviewController.listReviews()[0];
            EtimadReviewController.verifyEvidence(row.Id,row.Revision__c,'Corrected source checked.');
            try { EtimadReviewController.approveTask(row.Id,row.Revision__c); Assert.fail('No duplicate'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('earlier')); }
            Assert.areEqual(1,[SELECT count() FROM Task WHERE WhatId=:row.Id]);
        }
    }
    @IsTest static void directWorkflowWritesAreRejected() {
        System.runAs(person('etrfull')) {
            Etimad_Review__c row=candidate();
            Database.SaveResult result=Database.update(new Etimad_Review__c(Id=row.Id,
                Verified_Revision__c=row.Revision__c),false);
            Assert.isFalse(result.isSuccess());
        }
    }
    @IsTest static void accessAndCustomPermissionBoundaries() {
        Id reviewId;
        System.runAs(person('etrfull')) { reviewId=candidate().Id; }
        System.runAs(person('etrread')) {
            Assert.areEqual(0,EtimadReviewController.listReviews().size(),'Private records stay private');
            try { EtimadReviewController.approveTask(reviewId,'fake'); Assert.fail('No approval permission'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('permission')); }
        }
        System.runAs(person('etrnone')) {
            try { EtimadReviewController.listReviews(); Assert.fail('No read permission'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('permission')); }
        }
    }
    @IsTest static void sourceAndPayloadValidation() {
        System.runAs(person('etrfull')) {
            String bad=payload('bad').replace('"pdfPage":2','"pdfPage":3');
            try { EtimadReviewController.importCandidates(bad); Assert.fail('Invalid page'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('Invalid')); }
            Etimad_Review__c row=candidate();
            try { EtimadReviewController.importCandidates(payload('synthetic-key').replace('Synthetic requirement','Different'));
                Assert.fail('Conflicting retry'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('different')); }
            try { EtimadReviewController.verifyEvidence(row.Id,row.Revision__c,''); Assert.fail('Need note'); }
            catch(EtimadReviewController.ReviewException e) { Assert.isTrue(e.getMessage().contains('Record')); }
        }
    }
}
