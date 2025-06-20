public with sharing class ExampleFeature {

    public static final String NEW_FEATURE_TOGGLE_NAME = 'NewExampleFeature';

    public String getFeatureBehavior() {
        if (FeatureToggleService.isFeatureEnabled(NEW_FEATURE_TOGGLE_NAME)) {
            return 'New Behavior Enabled';
        } else {
            return 'Old Behavior';
        }
    }

    public Integer performComplexCalculation(Integer input) {
        if (FeatureToggleService.isFeatureEnabled('ComplexMathV2Enabled')) {
            // Imagine a new, complex calculation
            return input * input * 2; // New version
        } else {
            // Old, simpler calculation
            return input * input; // Old version
        }
    }
}
