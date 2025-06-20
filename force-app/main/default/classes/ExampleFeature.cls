public with sharing class ExampleFeature {

    // The constant NEW_FEATURE_TOGGLE_NAME is no longer needed here,
    // as the toggle name is encapsulated within FeatureToggles class.

    public String getFeatureBehavior() {
        if (FeatureToggles.NewExampleFeature) { // Changed to use FeatureToggles
            return 'New Behavior Enabled';
        } else {
            return 'Old Behavior';
        }
    }

    public Integer performComplexCalculation(Integer input) {
        if (FeatureToggles.ComplexMathV2Enabled) { // Changed to use FeatureToggles
            // Imagine a new, complex calculation
            return input * input * 2; // New version
        } else {
            // Old, simpler calculation
            return input * input; // Old version
        }
    }
}
