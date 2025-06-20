/**
 * Provides a convenient way to access feature toggles using static properties.
 * IMPORTANT: This class must be manually updated when new Feature_Toggle__mdt records
 * are added or their DeveloperNames are changed if you want to access them via
 * static properties like `FeatureToggles.YourFeatureName`.
 * Each static property getter calls FeatureToggleService.isFeatureEnabled('YourFeatureName').
 */
public with sharing class FeatureToggles {

    /**
     * Checks the 'NewExampleFeature' toggle.
     * Corresponds to the Feature_Toggle__mdt record with DeveloperName 'NewExampleFeature'.
     */
    public static Boolean NewExampleFeature {
        get {
            return FeatureToggleService.isFeatureEnabled('NewExampleFeature');
        }
    }

    /**
     * Checks the 'ComplexMathV2Enabled' toggle.
     * Corresponds to the Feature_Toggle__mdt record with DeveloperName 'ComplexMathV2Enabled'.
     */
    public static Boolean ComplexMathV2Enabled {
        get {
            return FeatureToggleService.isFeatureEnabled('ComplexMathV2Enabled');
        }
    }

    // Add other feature toggle getters here as needed:
    // public static Boolean AnotherFeature {
    //     get {
    //         return FeatureToggleService.isFeatureEnabled('AnotherFeature');
    //     }
    // }
}
