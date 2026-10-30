@IsTest
private class EtimadComplianceActionTest {
    @TestSetup static void setup() {
        List<User> users = new List<User>();
        Id profile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id;
        for (String alias : new List<String>{'etagent','etdenied','etreader'}) { users.add(new User(Alias=alias,
            LastName=alias,Email=alias+'@example.invalid',
            Username=alias+UserInfo.getOrganizationId()+System.now().getTime()+'@example.invalid',
            TimeZoneSidKey='Asia/Riyadh',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',ProfileId=profile)); }
        insert users;
        List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
        for (PermissionSet p : [SELECT Id FROM PermissionSet WHERE Name IN
            ('Etimad_Importer','Etimad_Reviewer','Etimad_Phase3_Data','Etimad_Agent_Read')]) {
            grants.add(new PermissionSetAssignment(AssigneeId=users[0].Id,PermissionSetId=p.Id)); }
        for (PermissionSet p : [SELECT Id FROM PermissionSet WHERE Name IN
            ('Etimad_Reader','Etimad_Phase3_Read','Etimad_Agent_Read')]) {
            grants.add(new PermissionSetAssignment(AssigneeId=users[2].Id,PermissionSetId=p.Id)); }
        insert grants;
    }
    private static User actor(String alias) { return [SELECT Id FROM User WHERE Alias=:alias LIMIT 1]; }
    private static Id fixture() {
        List<Object> rows = new List<Object>();
        for (String concept : new List<String>{'BID_SECURITY','SME_EXCEPTION','SME_CERTIFICATE'}) {
            rows.add(new Map<String,Object>{'importKey'=>concept,'sourceId'=>'TAQEEM-SOFTWARE-2026',
                'sourceHash'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'documentVersion'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'sourceUrl'=>'https://example.invalid/fixture','pageCount'=>3,'pdfPage'=>1,
                'concept'=>concept,'fact'=>'Invented test requirement','quote'=>'Invented test quotation','synthetic'=>false}); }
        return EtimadAssessmentService.importSoftwareWorkspace(JSON.serialize(new Map<String,Object>{
            'supplier'=>'SYNTHETIC-SOFTWARE-SUPPLIER','asOf'=>'2026-06-01','candidates'=>rows}));
    }
    private static EtimadComplianceAction.Request request(String id) {
        EtimadComplianceAction.Request r = new EtimadComplianceAction.Request(); r.workspaceId=id; return r;
    }
    @IsTest static void bulkUnknownReadOnlyAndStale() {
        System.runAs(actor('etagent')) {
            Id id = fixture();
            List<EtimadComplianceAction.Request> inputs = new List<EtimadComplianceAction.Request>();
            for (Integer i=0;i<200;i++) { inputs.add(request(String.valueOf(id))); }
            Test.startTest();
            Integer beforeQueries=Limits.getQueries();
            Integer beforeDml=Limits.getDmlStatements();
            List<EtimadComplianceAction.Response> outputs=EtimadComplianceAction.summarize(inputs);
            Assert.areEqual(2,Limits.getQueries()-beforeQueries);
            Assert.areEqual(beforeDml,Limits.getDmlStatements());
            Assert.areEqual(200,outputs.size()); Assert.areEqual('OK',outputs[199].status);
            Map<String,Object> summary=(Map<String,Object>)JSON.deserializeUntyped(outputs[0].summaryJson);
            Assert.areEqual(false,summary.get('sourceReviewed'));
            Assert.areEqual(3,((List<Object>)summary.get('clauses')).size());
            Assert.areEqual('agent-summary-v2',summary.get('schema'));
            Assert.areEqual(false,summary.get('sourceTextIncluded'));
            for (Object item : (List<Object>)summary.get('clauses')) {
                Map<String,Object> citation=(Map<String,Object>)item;
                Assert.isFalse(citation.containsKey('fact'));
                Assert.isFalse(citation.containsKey('quote'));
                Assert.isNotNull(citation.get('pdfPage'));
            }
            Assert.isFalse(outputs[0].summaryJson.contains('Invented test quotation'));
            Assert.isFalse(outputs[0].summaryJson.contains('Invented test requirement'));
            for (Object f : (List<Object>)summary.get('findings')) { Assert.areEqual('unknown',((Map<String,Object>)f).get('status')); }
            inputs[0].expectedRevision='old';
            Assert.areEqual('STALE_CONTEXT',EtimadComplianceAction.summarize(new List<EtimadComplianceAction.Request>{inputs[0]})[0].status);
            Test.stopTest();
            Assert.areEqual(0,[SELECT count() FROM Task]);
        }
    }
    @IsTest static void reviewedSourceStillNeedsEvidence() {
        System.runAs(actor('etagent')) {
            Id id=fixture();
            for (Etimad_Review__c r:EtimadReviewController.listReviews()) {
                EtimadReviewController.verifyEvidence(r.Id,r.Revision__c,'Invented isolated fixture review.'); }
            String value=EtimadComplianceAction.summarize(new List<EtimadComplianceAction.Request>{request(String.valueOf(id))})[0].summaryJson;
            Map<String,Object> summary=(Map<String,Object>)JSON.deserializeUntyped(value);
            Assert.areEqual(true,summary.get('sourceReviewed'));
            for (Object f:(List<Object>)summary.get('findings')) { Assert.areEqual('unknown',((Map<String,Object>)f).get('status')); }
            Assert.isTrue(String.valueOf(summary.get('supplierEvidence')).contains('Synthetic'));
        }
    }
    @IsTest static void invalidAndUnsupported() {
        System.runAs(actor('etagent')) {
            Id demo=EtimadAssessmentService.createDemo();
            List<EtimadComplianceAction.Response> outputs=EtimadComplianceAction.summarize(
                new List<EtimadComplianceAction.Request>{null,request('bad'),request(String.valueOf(UserInfo.getUserId())),request(String.valueOf(demo))});
            Assert.areEqual('INVALID_REQUEST',outputs[0].status);
            Assert.areEqual('INVALID_REQUEST',outputs[1].status);
            Assert.areEqual('INVALID_REQUEST',outputs[2].status);
            Assert.areEqual('UNSUPPORTED_MODEL',outputs[3].status);
            Assert.isNull(outputs[3].summaryJson);
        }
    }
    @IsTest static void missingPermissionDenied() {
        System.runAs(actor('etdenied')) {
            try { EtimadComplianceAction.summarize(new List<EtimadComplianceAction.Request>{request('bad')}); Assert.fail('Permission required'); }
            catch (EtimadAssessmentService.AssessmentException e) { Assert.isTrue(e.getMessage().contains('permission')); }
        }
    }
    @IsTest static void privateWorkspaceNotDisclosed() {
        Id id;
        System.runAs(actor('etagent')) { id=fixture(); }
        System.runAs(actor('etreader')) {
            EtimadComplianceAction.Response output=EtimadComplianceAction.summarize(
                new List<EtimadComplianceAction.Request>{request(String.valueOf(id))})[0];
            Assert.areEqual('UNAVAILABLE',output.status);
            Assert.isNull(output.summaryJson);
        }
    }
}
