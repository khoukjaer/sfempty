public with sharing class FeatureToggleService {

    private static Map<String, Boolean> toggleCache;

    // Static initializer to ensure cache is new for each transaction
    static {
        toggleCache = new Map<String, Boolean>();
    }

    @AuraEnabled(cacheable=true) // Cacheable for Lightning Components if needed
    public static Boolean isFeatureEnabled(String featureName) {
        if (String.isBlank(featureName)) {
            return false;
        }

        // Normalize the feature name to be case-insensitive for the cache key
        String cacheKey = featureName.toLowerCase();

        if (toggleCache.containsKey(cacheKey)) {
            return toggleCache.get(cacheKey);
        }

        Boolean isEnabled = false;
        try {
            Feature_Toggle__mdt toggle = [
                SELECT IsEnabled__c
                FROM Feature_Toggle__mdt
                WHERE DeveloperName = :featureName
                LIMIT 1
            ];
            if (toggle != null) {
                isEnabled = toggle.IsEnabled__c;
            }
        } catch (QueryException e) {
            // Handle query exception, e.g., if the Custom Metadata Type is not accessible
            // Or if there's no matching record, which is not an exception but an empty list.
            // For simplicity, we assume false if not found or error.
            System.debug(Logginglevel.WARN, 'QueryException while checking feature toggle: ' + featureName + '. Error: ' + e.getMessage());
        }

        toggleCache.put(cacheKey, isEnabled);
        return isEnabled;
    }

    // Method to allow clearing the cache, primarily for testability
    @TestVisible
    private static void clearCache() {
        toggleCache.clear();
    }
}
