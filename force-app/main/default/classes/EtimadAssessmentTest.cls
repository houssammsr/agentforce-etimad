@IsTest
private class EtimadAssessmentTest {
    /** Diagnose grants in the actual runAs context before business operations. */
    private static void assertEffectiveAccess() {
        List<String> missing=new List<String>();
        Set<String> assigned=new Set<String>();
        Id currentUser=UserInfo.getUserId();
        // Inspect test setup records explicitly; application access remains user-mode.
        for(PermissionSetAssignment grant:[SELECT PermissionSet.Name FROM PermissionSetAssignment
            WHERE AssigneeId=:currentUser WITH SYSTEM_MODE]) assigned.add(grant.PermissionSet.Name);
        for(String name:new List<String>{'Etimad_Importer','Etimad_Reviewer','Etimad_Phase3_Data'})
            if(!assigned.contains(name)) missing.add('ASSIGNMENT:'+name);
        for(String permission:new List<String>{'Etimad_Read','Etimad_Import','Etimad_Verify','Etimad_Approve'})
            if(!FeatureManagement.checkPermission(permission)) missing.add('CUSTOM_PERMISSION:'+permission);
        Map<String,Schema.SObjectType> objects=Schema.getGlobalDescribe();
        for(String name:new List<String>{'Etimad_Assessment__c','Etimad_Review__c'}) {
            if(!objects.containsKey(name)) { missing.add('SCHEMA_OBJECT:'+name); continue; }
            Schema.DescribeSObjectResult d=objects.get(name).getDescribe();
            if(!d.isAccessible()) missing.add('OBJECT_READ:'+name);
            if(!d.isCreateable()) missing.add('OBJECT_CREATE:'+name);
            if(!d.isUpdateable()) missing.add('OBJECT_UPDATE:'+name);
            Map<String,Schema.SObjectField> fields=d.fields.getMap();
            List<String> required=name=='Etimad_Assessment__c'
                ? new List<String>{'Supplier__c','As_Of__c','Source_Id__c','Document_Version__c','Evidence_JSON__c','Revision__c'}
                : new List<String>{'Assessment__c','Exception_Concept__c'};
            for(String field:required) {
                String qualified=name+'.'+field;
                if(!fields.containsKey(field)) { missing.add('SCHEMA_FIELD:'+qualified); continue; }
                Schema.DescribeFieldResult f=fields.get(field).getDescribe();
                if(!f.isAccessible()) missing.add('FIELD_READ:'+qualified);
                if(!f.isCreateable()) missing.add('FIELD_CREATE:'+qualified);
                if(!f.isUpdateable()) missing.add('FIELD_UPDATE:'+qualified);
            }
        }
        Assert.areEqual(0,missing.size(),'ETIMAD_PERMISSION_DIAGNOSTIC: '+String.join(missing,'; '));
    }

    @TestSetup static void users() {
        Id profile=[SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id;
        User u=new User(Alias='eapfull',LastName='Synthetic reviewer',Email='synthetic@example.invalid',
            Username='eap'+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
            TimeZoneSidKey='Asia/Riyadh',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',ProfileId=profile);
        insert u;
        List<PermissionSetAssignment> grants=new List<PermissionSetAssignment>();
        Set<String> found=new Set<String>();
        for(PermissionSet p:[SELECT Id,Name FROM PermissionSet WHERE Name IN ('Etimad_Importer','Etimad_Reviewer','Etimad_Phase3_Data')])
        {
            found.add(p.Name);
            grants.add(new PermissionSetAssignment(AssigneeId=u.Id,PermissionSetId=p.Id));
        }
        Assert.areEqual(3,found.size(),'ETIMAD_SETUP_DIAGNOSTIC: expected Importer, Reviewer and Phase3_Data permission sets; found '+String.join(new List<String>(found),', '));
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
            assertEffectiveAccess();
            EtimadAssessmentService.createDemo(); Etimad_Assessment__c w=workspace();
            List<Etimad_Review__c> linked=[SELECT Concept__c,Exception_Concept__c
                FROM Etimad_Review__c WHERE Assessment__c=:w.Id WITH USER_MODE];
            Assert.areEqual(3,linked.size(),'All synthetic requirements must be linked.');
            for(Etimad_Review__c requirement:linked) {
                Assert.areEqual(requirement.Concept__c=='BID_SECURITY' ? 'LOCAL_SME_CERT' : null,
                    requirement.Exception_Concept__c,'Only bid security has the SME exception.');
            }
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
            assertEffectiveAccess();
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
            assertEffectiveAccess();
            EtimadAssessmentService.createDemo(); Etimad_Assessment__c w=workspace();
            Assert.isFalse(Database.update(new Etimad_Assessment__c(Id=w.Id,Supplier__c='OTHER'),false).isSuccess());
            try { EtimadAssessmentService.saveEvidence(w.Id,w.Revision__c,w.Evidence_JSON__c.replace('SYNTHETIC-SUPPLIER','OTHER')); Assert.fail('Scope mismatch'); }
            catch(EtimadAssessmentService.AssessmentException e) { Assert.isTrue(e.getMessage().contains('scope')); }
            Assert.areEqual(w.Revision__c,workspace().Revision__c);
        }
    }

    @IsTest static void unresolvedExceptionCannotBecomeGap() {
        System.runAs(reviewer()) {
            assertEffectiveAccess();
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
