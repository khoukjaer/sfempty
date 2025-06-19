@isTest
private class FeatureToggleServiceTests {

    // Helper method to create a Feature_Toggle__mdt record for testing
    private static void createFeatureToggle(String developerName, Boolean isEnabled) {
        // In test context, we can create Custom Metadata Type records.
        // This requires the CMDT to be deployed or available in the org.
        // For unit tests, this approach is valid.
        // Note: This is a simplified way. For more complex scenarios or
        // if direct CMDT creation in tests is problematic (e.g. due to packaging),
        // consider using a mock provider with Test.createStub or HttpCalloutMock.
        // However, for CMDT, direct creation is generally the simplest and recommended way.

        Feature_Toggle__mdt toggle = new Feature_Toggle__mdt();
        toggle.DeveloperName = developerName;
        toggle.MasterLabel = developerName; // MasterLabel is required
        toggle.IsEnabled__c = isEnabled;

        // The following line would typically be used to insert, but for CMDTs in tests,
        // they are available for query once instantiated and populated if your code queries them.
        // However, to ensure they are queryable as if they were actual metadata records,
        // we need to insert them. This is a change in behavior in recent API versions.
        // If this fails, it means the "Enable Apex Test Access to Custom Metadata Types"
        // critical update might not be active, or there's a specific org configuration.
        // For robust testing, this insert is now necessary.
        List<Feature_Toggle__mdt> togglesToInsert = new List<Feature_Toggle__mdt>{toggle};
        List<Database.SaveResult> results = Database.insertImmediate(togglesToInsert);

        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                // Handle error - though in test context, it might just fail the test
                System.debug('Error inserting test CMDT: ' + sr.getErrors()[0].getMessage());
            }
        }
    }

    @TestSetup
    static void makeData(){
        // Create some sample toggles for the tests
        createFeatureToggle('TestFeatureEnabled', true);
        createFeatureToggle('TestFeatureDisabled', false);
        // 'TestFeatureNotFound' is intentionally not created
    }

    @isTest
    static void testFeatureEnabled() {
        Test.startTest();
        Boolean isEnabled = FeatureToggleService.isFeatureEnabled('TestFeatureEnabled');
        Test.stopTest();
        System.assertEquals(true, isEnabled, 'TestFeatureEnabled should be true');
    }

    @isTest
    static void testFeatureDisabled() {
        Test.startTest();
        Boolean isEnabled = FeatureToggleService.isFeatureEnabled('TestFeatureDisabled');
        Test.stopTest();
        System.assertEquals(false, isEnabled, 'TestFeatureDisabled should be false');
    }

    @isTest
    static void testFeatureNotFound() {
        Test.startTest();
        Boolean isEnabled = FeatureToggleService.isFeatureEnabled('TestFeatureNotFound');
        Test.stopTest();
        System.assertEquals(false, isEnabled, 'TestFeatureNotFound should be false as it does not exist');
    }

    @isTest
    static void testBlankFeatureName() {
        Test.startTest();
        Boolean isEnabled = FeatureToggleService.isFeatureEnabled('');
        Boolean isEnabledNull = FeatureToggleService.isFeatureEnabled(null);
        Test.stopTest();
        System.assertEquals(false, isEnabled, 'Blank feature name should return false');
        System.assertEquals(false, isEnabledNull, 'Null feature name should return false');
    }

    @isTest
    static void testCachingBehavior() {
        // Prime the cache for 'TestFeatureEnabled'
        createFeatureToggle('CacheTestFeature', true);

        Test.startTest();
        // First call - should query and cache
        Boolean firstCall = FeatureToggleService.isFeatureEnabled('CacheTestFeature');
        System.assertEquals(true, firstCall, 'First call for CacheTestFeature should be true');

        // To verify caching, we ideally need to check SOQL query counts.
        // We can simulate this by trying to change the underlying data (not possible for CMDTs directly mid-transaction)
        // or by asserting the SOQL count if Test.getQueries() was more granular for CMDTs.
        // For this test, we'll rely on the logic that if it works, the cache must be effective.
        // A more advanced test could involve deleting the CMDT record (if possible in test)
        // and seeing if the cached value persists. However, CMDT records are part of metadata.

        // Second call - should use cache
        // To ensure this, we clear the SOQL limit and then make the call.
        // If it makes another query when it shouldn't, it might hit limits in more complex scenarios.
        Integer soqlQueriesBeforeSecondCall = Limits.getQueries();
        Boolean secondCall = FeatureToggleService.isFeatureEnabled('CacheTestFeature');
        Integer soqlQueriesAfterSecondCall = Limits.getQueries();

        Test.stopTest();

        System.assertEquals(true, secondCall, 'Second call for CacheTestFeature should also be true (from cache)');
        System.assertEquals(soqlQueriesBeforeSecondCall, soqlQueriesAfterSecondCall, 'SOQL queries should not increase on the second call for the same feature toggle due to caching.');

        // Test cache clear
        FeatureToggleService.clearCache(); // Clear the cache
        // Re-create the toggle as clearCache doesn't affect @TestSetup data for this test's purpose
        // but we want to ensure the next call re-queries if the cache was indeed cleared.
        // Note: TestSetup data is available across test methods, but static cache is per transaction.
        // clearCache clears the static variable. The CMDT record still exists from TestSetup.

        soqlQueriesBeforeSecondCall = Limits.getQueries(); // Reset counter before the call
        Boolean thirdCallAfterClear = FeatureToggleService.isFeatureEnabled('CacheTestFeature');
        soqlQueriesAfterSecondCall = Limits.getQueries();

        System.assertEquals(true, thirdCallAfterClear, 'Third call for CacheTestFeature after cache clear should be true (re-queried)');
        System.assert(soqlQueriesAfterSecondCall > soqlQueriesBeforeSecondCall, 'SOQL queries should increase after cache clear, indicating a fresh query.');
    }

    @isTest
    static void testFeatureNameCaseSensitivity() {
        // TestSetup creates 'TestFeatureEnabled'
        Test.startTest();
        Boolean isEnabledUpper = FeatureToggleService.isFeatureEnabled('TESTFEATUREENABLED');
        Boolean isEnabledLower = FeatureToggleService.isFeatureEnabled('testfeatureenabled');
        Boolean isEnabledMixed = FeatureToggleService.isFeatureEnabled('TestFeatureEnabled');
        Test.stopTest();

        System.assertEquals(true, isEnabledUpper, 'Uppercase feature name should be found (cache key is lowercased)');
        System.assertEquals(true, isEnabledLower, 'Lowercase feature name should be found');
        System.assertEquals(true, isEnabledMixed, 'Mixed case feature name should be found');

        // Verify caching behavior for different cases of the same name
        Integer queriesBefore = Limits.getQueries();
        FeatureToggleService.isFeatureEnabled('testfeatureenabled_case'); // First call with this variant
        FeatureToggleService.isFeatureEnabled('TestFeatureEnabled_Case'); // Second call, different case
        FeatureToggleService.isFeatureEnabled('TESTFEATUREENABLED_CASE'); // Third call, another case
        Integer queriesAfter = Limits.getQueries();
        // Expecting only 1 query for 'testfeatureenabled_case' due to cache normalization.
        // This requires 'testfeatureenabled_case' to be created first.
        createFeatureToggle('testfeatureenabled_case', true);
        FeatureToggleService.clearCache(); // Clear cache before this specific test part

        queriesBefore = Limits.getQueries();
        FeatureToggleService.isFeatureEnabled('testfeatureenabled_case');
        Integer queriesAfterFirst = Limits.getQueries();
        FeatureToggleService.isFeatureEnabled('TestFeatureEnabled_Case');
        FeatureToggleService.isFeatureEnabled('TESTFEATUREENABLED_CASE');
        Integer queriesAfterThird = Limits.getQueries();

        System.assertEquals(1, queriesAfterFirst - queriesBefore, 'Only one query should be made for the first variant.');
        System.assertEquals(queriesAfterFirst, queriesAfterThird, 'Subsequent calls with different casing for the same DeveloperName should hit the cache.');
    }
}
