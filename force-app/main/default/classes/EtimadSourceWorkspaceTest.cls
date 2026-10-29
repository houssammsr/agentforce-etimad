@IsTest
private class EtimadSourceWorkspaceTest {
    @TestSetup static void setupUsers() {
        User u=new User(Alias='etsrc',LastName='Source fixture',Email='source@example.invalid',
            Username='etsrc'+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
            TimeZoneSidKey='Asia/Riyadh',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',
            ProfileId=[SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id);
        insert u; List<PermissionSetAssignment> grants=new List<PermissionSetAssignment>();
        for(PermissionSet p:[SELECT Id FROM PermissionSet WHERE Name IN ('Etimad_Importer','Etimad_Reviewer','Etimad_Phase3_Data')])
            grants.add(new PermissionSetAssignment(AssigneeId=u.Id,PermissionSetId=p.Id));
        insert grants;
    }
    private static String payload() {
        List<Object> candidates=new List<Object>();
        for(String concept:new List<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'}) candidates.add(new Map<String,Object>{
            'importKey'=>concept,'sourceId'=>'TAQEEM-SOFTWARE-2026',
            'sourceHash'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'documentVersion'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'sourceUrl'=>'https://example.invalid/fixture','pageCount'=>3,'pdfPage'=>1,'concept'=>concept,
            'fact'=>'Synthetic test content, not actual procurement evidence','quote'=>'Synthetic quote','synthetic'=>false});
        return JSON.serialize(new Map<String,Object>{'supplier'=>'SYNTHETIC-SOFTWARE-SUPPLIER','asOf'=>'2026-06-01','candidates'=>candidates});
    }
    private static List<EtimadAssessmentService.Evidence> evidence() {
        List<EtimadAssessmentService.Evidence> rows=new List<EtimadAssessmentService.Evidence>();
        for(String concept:new List<String>{'LOCAL_ESTABLISHMENT','SME_CLASSIFICATION','SME_CERTIFICATE','OMITS_INITIAL_SECURITY'}) {
            EtimadAssessmentService.Evidence e=new EtimadAssessmentService.Evidence(); e.id=concept;
            e.supplierId='SYNTHETIC-SOFTWARE-SUPPLIER';e.concept=concept;e.assertion=true;e.verified=false;
            e.validFrom=Date.newInstance(2026,1,1);e.validTo=Date.newInstance(2026,12,31);rows.add(e);
        }
        return rows;
    }
    @IsTest static void sourceImportAndReviewedCompoundAssessment() {
        User actor=[SELECT Id FROM User WHERE Alias='etsrc' LIMIT 1];
        System.runAs(actor) {
            Id id=EtimadAssessmentService.importSoftwareWorkspace(payload());
            Assert.areEqual(id,EtimadAssessmentService.importSoftwareWorkspace(payload()),'Retry returns same workspace');
            Etimad_Assessment__c w=EtimadAssessmentService.listWorkspaces()[0];
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(id,w.Revision__c)) Assert.areEqual('unknown',f.status);
            for(Etimad_Review__c c:EtimadReviewController.listReviews())
                EtimadReviewController.verifyEvidence(c.Id,c.Revision__c,'Synthetic citation review in isolated test.');
            EtimadAssessmentService.saveEvidence(id,w.Revision__c,JSON.serialize(evidence()));
            for(EtimadAssessmentService.Evidence e:evidence()) {
                w=EtimadAssessmentService.listWorkspaces()[0]; EtimadAssessmentService.verifyEvidence(id,w.Revision__c,e.id);
            }
            w=EtimadAssessmentService.listWorkspaces()[0]; List<EtimadAssessmentService.Finding> findings=EtimadAssessmentService.assess(id,w.Revision__c);
            Assert.areEqual(2,findings.size());
            for(EtimadAssessmentService.Finding f:findings) Assert.areEqual(f.concept=='BID_SECURITY'?'not_applicable':'supported',f.status);
            Etimad_Review__c clause=EtimadReviewController.listReviews()[0];
            EtimadReviewController.correctFact(clause.Id,clause.Revision__c,'Changed synthetic interpretation');
            for(EtimadAssessmentService.Finding f:EtimadAssessmentService.assess(id,w.Revision__c)) Assert.areEqual('unknown',f.status);
            Assert.areEqual(0,[SELECT count() FROM Task]);
        }
    }
    @IsTest static void compoundUnknownConflictAndConditionalCertificate() {
        List<EtimadAssessmentService.Evidence> rows=evidence();
        for(EtimadAssessmentService.Evidence e:rows) e.verified=true;
        Date asOf=Date.newInstance(2026,6,1); String supplier='SYNTHETIC-SOFTWARE-SUPPLIER';
        Assert.areEqual('not_applicable',EtimadCompoundRules.evaluate('BID_SECURITY',rows,asOf,supplier).status);
        rows[2].validTo=Date.newInstance(2026,5,31);
        Assert.areEqual('unknown',EtimadCompoundRules.evaluate('BID_SECURITY',rows,asOf,supplier).status);
        rows[3].assertion=false;
        Assert.areEqual('not_applicable',EtimadCompoundRules.evaluate('SME_CERTIFICATE',rows,asOf,supplier).status);
        rows[2].validTo=Date.newInstance(2026,12,31);
        EtimadAssessmentService.Evidence negative=(EtimadAssessmentService.Evidence)JSON.deserialize(JSON.serialize(rows[0]),EtimadAssessmentService.Evidence.class);
        negative.id='CONFLICT'; negative.assertion=false; rows.add(negative);
        Assert.areEqual('conflicting',EtimadCompoundRules.evaluate('BID_SECURITY',rows,asOf,supplier).status);
        Assert.areEqual('unknown',EtimadCompoundRules.evaluate('BID_SECURITY',rows,asOf,'OTHER').status);
    }
    @IsTest static void rejectIncompleteAndForeignSource() {
        User actor=[SELECT Id FROM User WHERE Alias='etsrc' LIMIT 1];
        System.runAs(actor) {
            for(String invalid:new List<String>{payload().replace('TAQEEM-SOFTWARE-2026','OTHER'),payload().replace('SME_EXCEPTION','BID_SECURITY')}) {
                try { EtimadAssessmentService.importSoftwareWorkspace(invalid); Assert.fail('Must reject'); }
                catch(Exception e) { Assert.isFalse(e instanceof System.AssertException); }
            }
            Assert.areEqual(0,[SELECT count() FROM Etimad_Assessment__c]);
        }
    }
}
