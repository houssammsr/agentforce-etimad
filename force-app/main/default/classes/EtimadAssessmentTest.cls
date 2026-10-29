@IsTest
private class EtimadAssessmentTest {
    @TestSetup static void users() {
        Id profile=[SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id;
        User u=new User(Alias='eapfull',LastName='Synthetic reviewer',Email='synthetic@example.invalid',
            Username='eap'+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
            TimeZoneSidKey='Asia/Riyadh',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',ProfileId=profile);
        insert u;
        List<PermissionSetAssignment> grants=new List<PermissionSetAssignment>();
        for(PermissionSet p:[SELECT Id FROM PermissionSet WHERE Name IN ('Etimad_Importer','Etimad_Reviewer')])
            grants.add(new PermissionSetAssignment(AssigneeId=u.Id,PermissionSetId=p.Id));
        insert grants;
    }
    private static User reviewer() { return [SELECT Id FROM User WHERE Alias='eapfull' LIMIT 1]; }
    private static Etimad_Assessment__c workspace() { return EtimadAssessmentService.listWorkspaces()[0]; }
    private static void verifyRequirements() {
        for(Etimad_Review__c r:EtimadReviewController.listReviews())
            EtimadReviewController.verifyEvidence(r.Id,r.Revision__c,'Synthetic source manually reviewed for test.');
    }
    @IsTest static void scopedExceptionAndInvalidation() {
        System.runAs(reviewer()) {
            EtimadAssessmentService.createDemo(); Etimad_Assessment__c w=workspace();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c))
                Assert.areEqual('unknown',f.status);
            verifyRequirements();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'SYN-SME'); w=workspace();
            Map<String,String> results=new Map<String,String>();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c)) results.put(f.concept,f.status);
            Assert.areEqual('not_applicable',results.get('BID_SECURITY'));
            Assert.areEqual('supported',results.get('LOCAL_SME_CERT'));
            Assert.areEqual('unknown',results.get('FINAL_SECURITY'));
            Assert.areEqual(0,[SELECT count() FROM Task]);
            String old=w.Revision__c;
            EtimadAssessmentService.saveEvidence(w.Id,old,w.Evidence_JSON__c); w=workspace();
            Assert.areNotEqual(old,w.Revision__c);
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c)) Assert.areEqual('unknown',f.status);
            try { EtimadAssessmentService.verifyEvidence(w.Id,old,'SYN-SME'); Assert.fail('Stale write'); }
            catch(EtimadAssessmentService.AssessmentException e) { Assert.isTrue(e.getMessage().contains('changed')); }
        }
    }
    @IsTest static void conflictsAndExpiredEvidence() {
        System.runAs(reviewer()) {
            EtimadAssessmentService.createDemo(); verifyRequirements(); Etimad_Assessment__c w=workspace();
            List<EtimadAssessmentService.Evidence> rows=EtimadAssessmentService.parse(w.Evidence_JSON__c,w.Supplier__c);
            EtimadAssessmentService.Evidence second=(EtimadAssessmentService.Evidence)JSON.deserialize(JSON.serialize(rows[0]),EtimadAssessmentService.Evidence.class);
            second.id='SYN-NO'; second.assertion=false; rows.add(second);
            EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,JSON.serialize(rows)); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'SYN-SME'); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'SYN-NO'); w=workspace();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c))
                if(f.concept=='BID_SECURITY') Assert.areEqual('conflicting',f.status);
            rows=EtimadAssessmentService.parse(w.Evidence_JSON__c,w.Supplier__c);
            rows.remove(1); rows[0].validTo=Date.newInstance(2026,5,31);
            EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,JSON.serialize(rows)); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'SYN-SME'); w=workspace();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c)) Assert.areEqual('unknown',f.status);
        }
    }
    @IsTest static void directWritesAndInvalidScopeRejected() {
        System.runAs(reviewer()) {
            EtimadAssessmentService.createDemo(); Etimad_Assessment__c w=workspace();
            Assert.isFalse(Database.update(new Etimad_Assessment__c(Id=w.Id,Supplier__c='OTHER'),false).isSuccess());
            try { EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,w.Evidence_JSON__c.replace('SYNTHETIC-SUPPLIER','OTHER')); Assert.fail('Scope mismatch'); }
            catch(EtimadAssessmentService.AssessmentException e) { Assert.isTrue(e.getMessage().contains('scope')); }
            Assert.areEqual(w.Revision__c,workspace().Revision__c);
        }
    }

    @IsTest static void unresolvedExceptionCannotBecomeGap() {
        System.runAs(reviewer()) {
            EtimadAssessmentService.createDemo(); verifyRequirements(); Etimad_Assessment__c w=workspace();
            List<EtimadAssessmentService.Evidence> rows=EtimadAssessmentService.parse(w.Evidence_JSON__c,w.Supplier__c);
            rows[0].concept='BID_SECURITY'; rows[0].assertion=false; rows[0].id='DIRECT-NO';
            EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,JSON.serialize(rows)); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'DIRECT-NO'); w=workspace();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c)) {
                if(f.concept=='BID_SECURITY') {
                    Assert.areEqual('unknown',f.status);
                    Assert.areEqual('EXCEPTION_APPLICABILITY_UNRESOLVED',f.reason);
                }
            }
            EtimadAssessmentService.Evidence excluded=(EtimadAssessmentService.Evidence)JSON.deserialize(JSON.serialize(rows[0]),EtimadAssessmentService.Evidence.class);
            excluded.id='EXCLUDED'; excluded.concept='LOCAL_SME_CERT'; rows.add(excluded);
            EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,JSON.serialize(rows)); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'DIRECT-NO'); w=workspace();
            EtimadAssessmentService.verifyEvidence(w.Id,w.Revision__c,'EXCLUDED'); w=workspace();
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(w.Id,w.Revision__c)) {
                if(f.concept=='BID_SECURITY') Assert.areEqual('gap',f.status);
            }
        }
    }
}
