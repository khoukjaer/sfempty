public with sharing class FeatureToggleService {

    // Platform Cache Configuration
    // IMPORTANT: This partition name ('FeatureToggleCache') must be set up in Salesforce's
    // Platform Cache configuration (Setup > Platform Cache). If this partition does not exist,
    // is not active, or the running user/context lacks permission, the service will attempt
    // to use the default Platform Cache session and org partitions.
    private static final String CACHE_PARTITION_NAME = 'FeatureToggleCache';

    // Default Time-To-Live for items stored in Platform Cache, in seconds.
    // (e.g., 600 seconds = 10 minutes). When a feature toggle's status is read from
    // Custom Metadata and stored in Platform Cache, it will remain there for this duration.
    // Changes to toggle values in Custom Metadata Types might take up to this TTL to be
    // reflected if the value is being served from an existing Platform Cache entry.
    // This value can be modified here to adjust the cache expiry policy.
    public static final Integer DEFAULT_CACHE_TTL_SECONDS = 600;

    // Prefix for all keys stored in Platform Cache by this service.
    // This helps ensure that keys are unique and avoid potential collisions if other
    // applications or services use the same cache partition with generic key names.
    private static final String CACHE_KEY_PREFIX = 'FeatureToggleService.';

    private static Map<String, Boolean> toggleCache; // Existing static cache

    // Static initializer to ensure cache is new for each transaction
    static {
        toggleCache = new Map<String, Boolean>();
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isFeatureEnabled(String featureName) {
        if (String.isBlank(featureName)) {
            return false;
        }

        String normalizedFeatureName = featureName.toLowerCase(); // Normalize for consistent cache keys

        // 1. Check static transaction cache
        if (toggleCache.containsKey(normalizedFeatureName)) {
            return toggleCache.get(normalizedFeatureName);
        }

        // 2. Check Platform Cache
        String platformCacheKey = CACHE_KEY_PREFIX + normalizedFeatureName;
        Boolean isEnabled = null; // Initialize isEnabled to null

        if (!Test.isRunningTest()) {
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION_NAME);
                if (partition != null) {
                    Object cachedValue = partition.get(platformCacheKey);
                    if (cachedValue != null) {
                        isEnabled = (Boolean)cachedValue;
                    }
                } else {
                    System.debug(LoggingLevel.WARN, 'FeatureToggleService: Platform Cache partition "' + CACHE_PARTITION_NAME + '" not found. Checking default partition.');
                    // Try default partition if named one is not found
                    Object cachedValueFromDefault = Cache.Org.get(platformCacheKey);
                    if (cachedValueFromDefault != null) {
                        isEnabled = (Boolean)cachedValueFromDefault;
                    }
                }

                if (isEnabled != null) {
                    toggleCache.put(normalizedFeatureName, isEnabled); // Populate static cache
                    return isEnabled;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'FeatureToggleService: Error accessing Platform Cache for GET. Feature: ' + featureName + '. Error: ' + e.getMessage());
                // Fall through to query CMDT, isEnabled remains null
            }
        }

        // 3. If not in any cache, query Feature_Toggle__mdt
        System.debug(LoggingLevel.INFO, 'FeatureToggleService: Querying CMDT for toggle: ' + featureName);
        Boolean queriedIsEnabledValue = false; // Default to false before query
        try {
            Feature_Toggle__mdt toggle = [
                SELECT IsEnabled__c
                FROM Feature_Toggle__mdt
                WHERE DeveloperName = :featureName
                LIMIT 1
            ];
            if (toggle != null) {
                queriedIsEnabledValue = toggle.IsEnabled__c;
            }
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN, 'FeatureToggleService: QueryException for ' + featureName + '. Defaulting to false. Error: ' + e.getMessage());
            // queriedIsEnabledValue remains false
        }

        isEnabled = queriedIsEnabledValue; // Assign the queried value (or its default of false)

        // Store in Platform Cache (if not running a test) and static cache
        if (!Test.isRunningTest()) {
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION_NAME);
                if (partition != null) {
                    partition.put(platformCacheKey, isEnabled, DEFAULT_CACHE_TTL_SECONDS);
                } else {
                    // Fallback to default partition for putting if named one was not found
                    Cache.Org.put(platformCacheKey, isEnabled, DEFAULT_CACHE_TTL_SECONDS);
                    System.debug(LoggingLevel.WARN, 'FeatureToggleService: Platform Cache partition "' + CACHE_PARTITION_NAME + '" not found. Used default partition for PUT.');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'FeatureToggleService: Error writing to Platform Cache for PUT. Feature: ' + featureName + '. Error: ' + e.getMessage());
            }
        }
        toggleCache.put(normalizedFeatureName, isEnabled); // Store in static cache regardless

        return isEnabled;
    }

    /**
     * Clears the static transaction-level cache.
     * This method is primarily used for testing purposes to ensure that subsequent
     * calls to `isFeatureEnabled` within the same test transaction re-evaluate
     * toggles from their source (CMDT or simulated Platform Cache behavior in tests)
     * rather than using values cached earlier in the transaction.
     *
     * Note: This method does NOT clear items from the Platform Cache. Platform Cache
     * items expire based on their TTL or can be managed via Salesforce administrative tools.
     */
    @TestVisible
    private static void clearCache() {
        if (toggleCache != null) { // Add null check for robustness
            toggleCache.clear();
            System.debug(LoggingLevel.INFO, 'FeatureToggleService: Static transaction cache cleared.');
        }
    }
}
