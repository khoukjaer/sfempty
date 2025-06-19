@isTest
private class ExampleFeatureTests {

    // Helper to create the CMDT record for tests
    private static void createTestToggle(String developerName, Boolean isEnabled) {
        Feature_Toggle__mdt toggle = new Feature_Toggle__mdt(
            DeveloperName = developerName,
            MasterLabel = developerName,
            IsEnabled__c = isEnabled
        );
        insert toggle;
    }

    @isTest
    static void testGetFeatureBehavior_WhenFeatureIsEnabled() {
        // Setup: Enable the feature toggle for this test
        createTestToggle(ExampleFeature.NEW_FEATURE_TOGGLE_NAME, true);
        FeatureToggleService.clearCache(); // Clear cache to ensure fresh read for this test method

        ExampleFeature example = new ExampleFeature();
        Test.startTest();
        String behavior = example.getFeatureBehavior();
        Test.stopTest();

        System.assertEquals('New Behavior Enabled', behavior, 'Behavior should be new when toggle is ON');
    }

    @isTest
    static void testGetFeatureBehavior_WhenFeatureIsDisabled() {
        // Setup: Disable the feature toggle for this test (or ensure it's not present/false)
        createTestToggle(ExampleFeature.NEW_FEATURE_TOGGLE_NAME, false);
        FeatureToggleService.clearCache(); // Clear cache

        ExampleFeature example = new ExampleFeature();
        Test.startTest();
        String behavior = example.getFeatureBehavior();
        Test.stopTest();

        System.assertEquals('Old Behavior', behavior, 'Behavior should be old when toggle is OFF');
    }

    @isTest
    static void testGetFeatureBehavior_WhenFeatureToggleDoesNotExist() {
        // Setup: Ensure the toggle does not exist or is not true.
        // No need to create a toggle, or ensure it's not the one we're looking for.
        // FeatureToggleService.isFeatureEnabled will return false.
        FeatureToggleService.clearCache(); // Clear cache

        ExampleFeature example = new ExampleFeature();
        Test.startTest();
        String behavior = example.getFeatureBehavior();
        Test.stopTest();

        System.assertEquals('Old Behavior', behavior, 'Behavior should be old when toggle does not exist');
    }

    @isTest
    static void testPerformComplexCalculation_V2Enabled() {
        createTestToggle('ComplexMathV2Enabled', true);
        FeatureToggleService.clearCache();

        ExampleFeature example = new ExampleFeature();
        Test.startTest();
        Integer result = example.performComplexCalculation(5);
        Test.stopTest();

        System.assertEquals(50, result, 'Should use V2 calculation: 5*5*2 = 50');
    }

    @isTest
    static void testPerformComplexCalculation_V2Disabled() {
        createTestToggle('ComplexMathV2Enabled', false);
        FeatureToggleService.clearCache();

        ExampleFeature example = new ExampleFeature();
        Test.startTest();
        Integer result = example.performComplexCalculation(5);
        Test.stopTest();

        System.assertEquals(25, result, 'Should use V1 calculation: 5*5 = 25');
    }
}
