@isTest
private class PhoneNumberSyncServiceTests {

    // Helper to create Account_Phone_Number_Assignment__c records for testing
    private static Account_Phone_Number_Assignment__c createLocalAssignment(String phoneNumber, String status, String series) {
        Account_Phone_Number_Assignment__c assignment = new Account_Phone_Number_Assignment__c(
            Name = phoneNumber, // Assuming Name is the phone number
            Status__c = status, // Placeholder field
            Series__c = series   // Placeholder field
            // Add other necessary fields as per object definition
        );
        return assignment;
    }

    // Helper to create NumberResDAO.NumberData for mock remote responses
    private static NumberResDAO.NumberData createRemoteData(String phoneNumber, String status, String group) {
        NumberResDAO.NumberData data = new NumberResDAO.NumberData();
        data.phoneNumber = phoneNumber;
        data.numberStatus = status;
        data.numberGroup = group;
        // productType, countryCode, id etc. can be populated if needed for logic
        return data;
    }

    @TestVisible
    private class MockPhoneNumberSyncService extends PhoneNumberSyncService {
        private Map<String, List<NumberResDAO.NumberData>> mockRemoteDataBySeriesAndStatus;
        public List<String> calledParamsKeys = new List<String>(); // To track calls

        MockPhoneNumberSyncService(Map<String, List<NumberResDAO.NumberData>> mockData) {
            super();
            this.mockRemoteDataBySeriesAndStatus = mockData;
        }

        @Override
        protected NumberResDAO.NumberDetails callGetNumberDetails(NumberService.GetNumbersParameterbuilder params) {
            NumberResDAO.NumberDetails details = new NumberResDAO.NumberDetails();
            details.data = new List<NumberResDAO.NumberData>();

            String key = params.numberGroup + '_' + params.numberStatus;
            calledParamsKeys.add(key); // Record the call parameters key

            if (mockRemoteDataBySeriesAndStatus != null && mockRemoteDataBySeriesAndStatus.containsKey(key)) {
                 details.data.addAll(mockRemoteDataBySeriesAndStatus.get(key));
            }
            return details;
        }
    }

    // ... (testCreateNewAssignments, testUpdateExistingAssignments, testDeleteObsoleteAssignments remain the same) ...
    @isTest
    static void testCreateNewAssignments() {
        Map<String, List<NumberResDAO.NumberData>> mockRemotePayload =
            new Map<String, List<NumberResDAO.NumberData>>{
                'Series1_AA' => new List<NumberResDAO.NumberData>{
                    createRemoteData('1112223333', 'AA', 'Series1'),
                    createRemoteData('4445556666', 'AA', 'Series1')
                }
                // Add other series from `allSeries` to prevent unexpected deletions if they are queried
                // For 'Series2' and 'OpenSeries1' (if it's not the one being tested as open here)
                // Ensure they return empty lists if no data is expected for them in this specific test.
                ,'Series2_AA' => new List<NumberResDAO.NumberData>(), 'Series2_AR' => new List<NumberResDAO.NumberData>(),
                'Series2_AI' => new List<NumberResDAO.NumberData>(), 'Series2_AS' => new List<NumberResDAO.NumberData>(),
                'OpenSeries1_AR' => new List<NumberResDAO.NumberData>() // Assuming OpenSeries1 is handled elsewhere or empty
            };

        Test.startTest();
        // Note: The PhoneNumberSyncService uses a hardcoded `allSeries` list:
        // List<String> allSeries = new List<String>{'Series1', 'Series2', 'OpenSeries1'};
        // And queries OpenPhoneNumberSeries__mdt. If 'OpenSeries1' is not in CMD for this test, it's treated as regular.
        MockPhoneNumberSyncService service = new MockPhoneNumberSyncService(mockRemotePayload);
        service.synchronizeAssignments();
        Test.stopTest();

        List<Account_Phone_Number_Assignment__c> created = [
            SELECT Name, Status__c, Series__c FROM Account_Phone_Number_Assignment__c
        ];
        System.assertEquals(2, created.size(), 'Should create 2 new assignments from Series1_AA.');
        Set<String> createdNumbers = new Set<String>();
        for(Account_Phone_Number_Assignment__c asn : created) {
            createdNumbers.add(asn.Name);
            if(asn.Name == '1112223333' || asn.Name == '4445556666') {
                System.assertEquals('AA', asn.Status__c);
                System.assertEquals('Series1', asn.Series__c);
            }
        }
        System.assert(createdNumbers.contains('1112223333'));
        System.assert(createdNumbers.contains('4445556666'));
    }

    @isTest
    static void testUpdateExistingAssignments() {
        List<Account_Phone_Number_Assignment__c> localAssignments = new List<Account_Phone_Number_Assignment__c>{
            createLocalAssignment('1234567890', 'AA', 'Series1')
        };
        insert localAssignments;

        Map<String, List<NumberResDAO.NumberData>> mockRemotePayload =
            new Map<String, List<NumberResDAO.NumberData>>{
                'Series1_AA' => new List<NumberResDAO.NumberData>{
                    createRemoteData('1234567890', 'AR', 'Series1')
                },
                // Add other series from `allSeries` to prevent unexpected deletions
                'Series1_AR' => new List<NumberResDAO.NumberData>(),
                'Series1_AI' => new List<NumberResDAO.NumberData>(),
                'Series1_AS' => new List<NumberResDAO.NumberData>(),
                'Series2_AA' => new List<NumberResDAO.NumberData>(), 'Series2_AR' => new List<NumberResDAO.NumberData>(),
                'Series2_AI' => new List<NumberResDAO.NumberData>(), 'Series2_AS' => new List<NumberResDAO.NumberData>(),
                'OpenSeries1_AR' => new List<NumberResDAO.NumberData>()
            };

        Test.startTest();
        MockPhoneNumberSyncService service = new MockPhoneNumberSyncService(mockRemotePayload);
        service.synchronizeAssignments();
        Test.stopTest();

        List<Account_Phone_Number_Assignment__c> updated = [
            SELECT Name, Status__c, Series__c FROM Account_Phone_Number_Assignment__c WHERE Name = '1234567890'
        ];
        System.assertEquals(1, updated.size());
        System.assertEquals('AR', updated[0].Status__c);
        System.assertEquals('Series1', updated[0].Series__c);
    }

    @isTest
    static void testDeleteObsoleteAssignments() {
        List<Account_Phone_Number_Assignment__c> localAssignments = new List<Account_Phone_Number_Assignment__c>{
            createLocalAssignment('0987654321', 'AA', 'Series1'),
            createLocalAssignment('1111111111', 'AA', 'Series2') // Added one in Series2
        };
        insert localAssignments;

        // Remote data for Series1 is empty, implying 0987654321 is obsolete.
        // Remote data for Series2_AA has one record, so 1111111111 should NOT be deleted.
        Map<String, List<NumberResDAO.NumberData>> mockRemotePayload =
            new Map<String, List<NumberResDAO.NumberData>>{
                'Series1_AA' => new List<NumberResDAO.NumberData>(), 'Series1_AR' => new List<NumberResDAO.NumberData>(),
                'Series1_AI' => new List<NumberResDAO.NumberData>(), 'Series1_AS' => new List<NumberResDAO.NumberData>(),
                'Series2_AA' => new List<NumberResDAO.NumberData>{ createRemoteData('1111111111', 'AA', 'Series2') }, // Keep this one
                'Series2_AR' => new List<NumberResDAO.NumberData>(),
                'Series2_AI' => new List<NumberResDAO.NumberData>(), 'Series2_AS' => new List<NumberResDAO.NumberData>(),
                'OpenSeries1_AR' => new List<NumberResDAO.NumberData>()
            };

        Test.startTest();
        MockPhoneNumberSyncService service = new MockPhoneNumberSyncService(mockRemotePayload);
        service.synchronizeAssignments();
        Test.stopTest();

        List<Account_Phone_Number_Assignment__c> remaining = [
            SELECT Name FROM Account_Phone_Number_Assignment__c
        ];
        System.assertEquals(1, remaining.size(), 'Only one assignment should remain.');
        System.assertEquals('1111111111', remaining[0].Name, 'Assignment 1111111111 from Series2 should remain.');
    }

    @isTest
    static void testOpenPhoneNumberSeriesHandling() {
        // 1. Setup Custom Metadata for 'OpenSeries1'
        // Note: Custom metadata DML is not directly supported.
        // We rely on the metadata being deployed or use Test.loadData if it were a custom object.
        // For tests, we assume OpenPhoneNumberSeries__mdt with DeveloperName 'OpenSeries1' exists,
        // or we adjust PhoneNumberSyncService to query a mockable source for open series names in tests.
        // For this iteration, we assume the CMD query works IF the metadata for 'OpenSeries1' is present.
        // If not, this test might not correctly test the "open series" path.
        // Let's proceed assuming 'OpenSeries1' is correctly identified as open by the main code.

        // 2. Setup mock remote payload
        Map<String, List<NumberResDAO.NumberData>> mockRemotePayload =
            new Map<String, List<NumberResDAO.NumberData>>{
                // Data for a regular series (Series1) - expecting calls for AA, AR, AI, AS
                'Series1_AA' => new List<NumberResDAO.NumberData>{ createRemoteData('REG001', 'AA', 'Series1') },
                'Series1_AR' => new List<NumberResDAO.NumberData>(),
                'Series1_AI' => new List<NumberResDAO.NumberData>(),
                'Series1_AS' => new List<NumberResDAO.NumberData>(),
                // Data for an open series (OpenSeries1) - expecting call only for AR
                'OpenSeries1_AR' => new List<NumberResDAO.NumberData>{ createRemoteData('OPEN001', 'AR', 'OpenSeries1') },
                // Data for another regular series (Series2) - expecting calls for AA, AR, AI, AS
                'Series2_AA' => new List<NumberResDAO.NumberData>(), 'Series2_AR' => new List<NumberResDAO.NumberData>(),
                'Series2_AI' => new List<NumberResDAO.NumberData>(), 'Series2_AS' => new List<NumberResDAO.NumberData>()
            };

        // No local assignments for simplicity in this test, focusing on call behavior and creation.

        Test.startTest();
        MockPhoneNumberSyncService service = new MockPhoneNumberSyncService(mockRemotePayload);
        // To properly test OpenPhoneNumberSeries__mdt, we need to ensure it's populated for the test run.
        // If not deploying, this test relies on the hardcoded `allSeries` and the default behavior if CMD is empty.
        // Let's assume 'OpenSeries1' is one of the `allSeries` and is correctly identified as open.
        // The `PhoneNumberSyncService` has `List<String> allSeries = new List<String>{'Series1', 'Series2', 'OpenSeries1'};`
        // And `getRemoteAssignments` queries `OpenPhoneNumberSeries__mdt`. If 'OpenSeries1' is in this CMD, it's "open".

        // To ensure 'OpenSeries1' is treated as open, we would typically insert OpenPhoneNumberSeries__mdt.
        // However, direct DML on CMD is not allowed. Tests run with access to existing metadata.
        // So, this test assumes 'OpenSeries1' (DeveloperName) exists as an OpenPhoneNumberSeries__mdt record.
        // If it does not, 'OpenSeries1' will be treated as a *regular* series by the production code.

        service.synchronizeAssignments();
        Test.stopTest();

        // 3. Assert DML outcomes
        List<Account_Phone_Number_Assignment__c> created = [
            SELECT Name, Status__c, Series__c FROM Account_Phone_Number_Assignment__c
        ];
        System.assertEquals(2, created.size(), 'Should create one regular and one open series assignment.');

        Set<String> createdPhoneNumbers = new Set<String>();
        for(Account_Phone_Number_Assignment__c asn : created) {
            createdPhoneNumbers.add(asn.Name);
        }
        System.assert(createdPhoneNumbers.contains('REG001'), 'Regular assignment REG001 should be created.');
        System.assert(createdPhoneNumbers.contains('OPEN001'), 'Open series assignment OPEN001 should be created.');

        // 4. Assert that callGetNumberDetails was called with expected parameters
        Set<String> expectedCallKeys = new Set<String>{
            'Series1_AA', 'Series1_AR', 'Series1_AI', 'Series1_AS', // Regular series
            'OpenSeries1_AR',                                      // Open series (only AR)
            'Series2_AA', 'Series2_AR', 'Series2_AI', 'Series2_AS'  // Another regular series
        };

        System.assertEquals(expectedCallKeys.size(), service.calledParamsKeys.size(),
            'Mock service should be called for specific series/status combinations. Called: ' + service.calledParamsKeys);

        for(String key : expectedCallKeys) {
            System.assert(service.calledParamsKeys.contains(key),
                'Expected callGetNumberDetails with key: ' + key + '. Actual calls: ' + service.calledParamsKeys);
        }
        // Verify OpenSeries1 was NOT called with AA, AI, AS
        System.assert(!service.calledParamsKeys.contains('OpenSeries1_AA'), 'OpenSeries1 should not be called with AA.');
        System.assert(!service.calledParamsKeys.contains('OpenSeries1_AI'), 'OpenSeries1 should not be called with AI.');
        System.assert(!service.calledParamsKeys.contains('OpenSeries1_AS'), 'OpenSeries1 should not be called with AS.');
    }
}
