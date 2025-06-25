/**
 * The PhoneNumberSyncService is responsible for synchronizing Fokus phone numbers with Salesforce
 *  -----------------------------------------------------------------------------
 *  Developer            Date            Description
 *  -----------------------------------------------------------------------------
 *  Kenneth Houkjær         22/06/2025      Initial version 
 * 
 * @author Kenneth Houkjær
 * @date 22/06/2025
 */
public virtual class PhoneNumberSyncService { // Made class virtual for extensibility in tests

    private NumberService numberServiceInstance;

    public PhoneNumberSyncService() {
        // Allowing NumberService to be null if only static methods are used via wrappers
        // Or initialize if non-static methods of NumberService are also used elsewhere.
        // For now, NumberService.getNumberDetails is static, so instance isn't strictly for that.
    }

    // Constructor for testing to allow mocking of potential non-static NumberService methods (if any)
    @TestVisible
    private PhoneNumberSyncService(NumberService mockNumberService) {
        this.numberServiceInstance = mockNumberService;
    }

    // Inner class to hold remote assignment data along with its parent Series Id
    public class RemoteAssignmentWrapper {
        @TestVisible public NumberResDAO.NumberData numberData;
        @TestVisible public Id parentSeriesId;

        public RemoteAssignmentWrapper(NumberResDAO.NumberData data, Id seriesId) {
            this.numberData = data;
            this.parentSeriesId = seriesId;
        }
    }

    /**
     * Wrapper method for the static call to make it mockable in tests
     */
    @TestVisible // Or protected if tests are in the same namespace and can extend
    protected virtual NumberResDAO.NumberDetails callGetNumberDetails(NumberService.GetNumbersParameterbuilder params) {
        return NumberService.getNumberDetails(params);
    }

    /**
     * Method to get Account Phone Number Series records. Made virtual for potential test mocking.
     */
    @TestVisible
    protected virtual List<Account_Phone_Number_Series__c> getAllAccountPhoneNumberSeries(Account acc) {
       return AccountPhoneNumberSeriesSelector.getAllAccountPhoneNumberSeries(acc);
    }

    /**
     * Method to get OpenPhoneNumberSeries metadata. Made virtual for potential test mocking.
     */
    @TestVisible
    protected virtual List<OpenPhoneNumberSeries__mdt> getOpenPhoneNumberSeriesMetadata() {
        // Assuming API names NumberGroup__c and NumberLocation__c based on typical naming.
        // User feedback: "OpenPhoneNumberSeries containing NumberGroup, NumberLocation"
        // Adjust if API names are different (e.g., MasterLabel or DeveloperName if those store the group/location)
        return MetadataSelector.getOpenPhoneNumberSeries();
    }

    /**
     * Synchronizes assignments for a given account
     */
    public void synchronizeAssignmentsForAccount(Account acc) {
        Map<String, Account_Phone_Number_Assignment__c> localAssignments = getLocalAssignments(acc);
        Map<String, RemoteAssignmentWrapper> remoteAssignments = getRemoteAssignments(acc); // Changed return type
        compareAndPrepareDML(localAssignments, remoteAssignments); // Argument type changed
        
        Logger.emit();
    }
    
     /**
      * Synchronizes assignments for all accounts
      */
    public void synchronizeAllAssignments() {
        Map<String, Account_Phone_Number_Assignment__c> localAssignments = getLocalAssignments(null);
        Map<String, RemoteAssignmentWrapper> remoteAssignments = getRemoteAssignments(null); // Changed return type
        compareAndPrepareDML(localAssignments, remoteAssignments); // Argument type changed
        
        Logger.emit();
    }

    /**
     * getLocalAssignments
     */
    private Map<String, Account_Phone_Number_Assignment__c> getLocalAssignments(Account acc) {
        List<Account_Phone_Number_Assignment__c> listOfAccountPhoneNumberAssignments = AccountPhoneNumberAssignmentSelector.getAssignments(acc);
        
        Map<String, Account_Phone_Number_Assignment__c> localAssignmentsMap = new Map<String, Account_Phone_Number_Assignment__c>();

        for (Account_Phone_Number_Assignment__c assignment : listOfAccountPhoneNumberAssignments) {
            if (String.isNotBlank(assignment.Phone_Number__c)) {
                localAssignmentsMap.put(assignment.Phone_Number__c.toLowerCase(), assignment); // Key by lowercase phone number for case-insensitivity
            }
        }
        return localAssignmentsMap;
    }

    /**
     * getRemoteAssignments
     */
    private Map<String, RemoteAssignmentWrapper> getRemoteAssignments(Account acc) {
        Map<String, RemoteAssignmentWrapper> remoteAssignmentsMap = new Map<String, RemoteAssignmentWrapper>();

        // 1. Get all Account Phone Number Series
        List<Account_Phone_Number_Series__c> allSeriesRecords = getAllAccountPhoneNumberSeries(acc);
        if (allSeriesRecords.isEmpty()) {
            Logger.logInfo('No Account_Phone_Number_Series__c records found. No remote assignments to fetch.');
            return remoteAssignmentsMap;
        }

        // 2. Get OpenPhoneNumberSeries metadata
        Set<String> openSeriesKeys = new Set<String>();
        for (OpenPhoneNumberSeries__mdt opsMeta : getOpenPhoneNumberSeriesMetadata()) {
            // Create a unique key for comparison, e.g., "P_EKC"
             if (String.isNotBlank(opsMeta.number_group__c) && String.isNotBlank(opsMeta.number_location__c)) {
                openSeriesKeys.add(opsMeta.number_group__c.toUpperCase() + '_' + opsMeta.number_location__c.toUpperCase());
            }
        }
        Logger.logInfo('Open Series Keys from CMD: ' + openSeriesKeys);

        List<String> defaultStatuses = new List<String>{'AA', 'AR', 'AI', 'AS'};
        List<String> openSeriesStatuses = new List<String>{'AR'};

        // 3. Iterate through each Account_Phone_Number_Series__c record
        for (Account_Phone_Number_Series__c seriesRecord : allSeriesRecords) {
            String currentSeriesKey = '';
            if (String.isNotBlank(seriesRecord.Number_Group__c) && String.isNotBlank(seriesRecord.Number_Location__c)) {
                currentSeriesKey = seriesRecord.Number_Group__c.toUpperCase() + '_' + seriesRecord.Number_Location__c.toUpperCase();
            }

            boolean isSeriesOpen = openSeriesKeys.contains(currentSeriesKey);
            List<String> statusesToQuery = isSeriesOpen ? openSeriesStatuses : defaultStatuses;

            Logger.logInfo('Processing Series: ' + seriesRecord.Name +
                         ', Group: ' + seriesRecord.Number_Group__c +
                         ', Location: ' + seriesRecord.Number_Location__c +
                         ', IsOpen: ' + isSeriesOpen +
                         ', Statuses: ' + statusesToQuery);

            for (String status : statusesToQuery) {
                NumberService.GetNumbersParameterbuilder params = new NumberService.GetNumbersParameterbuilder();
                params.withNumberGroup(seriesRecord.Number_Group__c);
                params.withNumberLocation(seriesRecord.Number_Location__c);
                params.withCvr(seriesRecord.CVR__c);
                params.withNumberPattern(seriesRecord.Number_Pattern__c);
                // Note: Product_type__c from seriesRecord.Product_type__c is not directly used by
                // the current NumberService.GetNumbersParameterbuilder().build() which hardcodes GSM.
                // This might be an area for future enhancement if the builder needs to be more dynamic.
                params.withNumberStatus(status);
                // params.withAmountOfNumbers(X); // Consider pagination
                
                Logger.logInfo('Calling getNumberDetails with ' +  params);
                NumberResDAO.NumberDetails details = callGetNumberDetails(params);
                Logger.logInfo('getNumberDetails returned ' + details);

                if (details != null && details.data != null) {
                    for (NumberResDAO.NumberData numberData : details.data) {
                        if (String.isNotBlank(numberData.phoneNumber)) {
                            // Key by lowercase phone number for case-insensitivity
                            remoteAssignmentsMap.put(
                                numberData.phoneNumber.toLowerCase(),
                                new RemoteAssignmentWrapper(numberData, seriesRecord.Id)
                            );
                        }
                    }
                } else if (details != null && details.error != null) {
                    Logger.logInfo('Error fetching remote numbers for Series Name ' + seriesRecord.Name +
                                 ' (Group: ' + seriesRecord.Number_Group__c +
                                 ', Location: ' + seriesRecord.Number_Location__c +
                                 ') with status ' + status + ': ' + details.error.message);
                }
            }
        }
        return remoteAssignmentsMap;
    }

    /**
     * compareAndPrepareDML
     */
    private void compareAndPrepareDML(
        Map<String, Account_Phone_Number_Assignment__c> localAssignments,
        Map<String, RemoteAssignmentWrapper> remoteAssignments
    ) {
        List<Account_Phone_Number_Assignment__c> toCreate = new List<Account_Phone_Number_Assignment__c>();
        List<Account_Phone_Number_Assignment__c> toUpdate = new List<Account_Phone_Number_Assignment__c>();
        List<Account_Phone_Number_Assignment__c> toDelete = new List<Account_Phone_Number_Assignment__c>();

        // Iterate through remote assignments to find new or changed records
        for (String remoteKey : remoteAssignments.keySet()) { // remoteKey is already lowercased
            RemoteAssignmentWrapper wrapper = remoteAssignments.get(remoteKey);
            NumberResDAO.NumberData remoteData = wrapper.numberData;
            Id parentSeriesIdForRemote = wrapper.parentSeriesId;

            Account_Phone_Number_Assignment__c localRecord = localAssignments.get(remoteKey);

            if (localRecord == null) {
                // New record: create it
                Account_Phone_Number_Assignment__c newAssignment = new Account_Phone_Number_Assignment__c();

                newAssignment.Phone_Number__c = remoteData.phoneNumber; // Store with original casing
                newAssignment.CTN_Number_Status__c = remoteData.numberStatus;
                newAssignment.Account_Phone_Number_Series__c = parentSeriesIdForRemote; // Set Master-Detail relationship

                // TODO: Map other fields from remoteData to newAssignment if necessary
                // e.g., newAssignment.Phone_Number_user__c = remoteData.someUserField;
                // e.g., newAssignment.Account__c = determineAccountIdLogic();
                // For now, only core fields are mapped.

                toCreate.add(newAssignment);
                Logger.logInfo('To Create: Phone=' + remoteData.phoneNumber + ', Status=' + remoteData.numberStatus + ', SeriesId=' + parentSeriesIdForRemote);

            } else {
                // Existing record: check for changes
                boolean changed = false;

                // Compare CTN_Number_Status__c
                if (localRecord.CTN_Number_Status__c != remoteData.numberStatus) {
                    localRecord.CTN_Number_Status__c = remoteData.numberStatus;
                    changed = true;
                }

                // TODO: Compare other relevant fields from remoteData and update localRecord if changed.
                // Example:
                // if (localRecord.Phone_Number_user__c != remoteData.someUserField) {
                //    localRecord.Phone_Number_user__c = remoteData.someUserField;
                //    changed = true;
                // }

                // Note: The parentSeriesId (Account_Phone_Number_Series__c) for an existing localRecord
                // is generally not expected to change based on remote data for the *same phone number*.
                // If a phone number were to move series, it might appear as a delete from old series
                // and an add to new series, depending on how NumberService reports it.
                // We are not updating localRecord.Account_Phone_Number_Series__c here.

                if (changed) {
                    toUpdate.add(localRecord);
                    Logger.logInfo('To Update: Phone=' + localRecord.Phone_Number__c + ', NewStatus=' + localRecord.CTN_Number_Status__c);
                }
            }
        }

        // Iterate through local assignments to find records for deletion
        for (String localKey : localAssignments.keySet()) { // localKey is lowercased Phone_Number__c
            if (!remoteAssignments.containsKey(localKey)) {
                Account_Phone_Number_Assignment__c assignmentToDelete = localAssignments.get(localKey);
                toDelete.add(assignmentToDelete);
                Logger.logInfo('To Delete: Phone=' + assignmentToDelete.Phone_Number__c + ', Id=' + assignmentToDelete.Id);
            }
        }

        executeDMLOperations(toCreate, toUpdate, toDelete);
    }

    /**
     * executeDMLOperations
     */
    private void executeDMLOperations(
        List<Account_Phone_Number_Assignment__c> toCreate,
        List<Account_Phone_Number_Assignment__c> toUpdate,
        List<Account_Phone_Number_Assignment__c> toDelete
    ) {
        // Placeholder for DML execution
        try {
            if (!toCreate.isEmpty()) {
                // TODO: Before insert, ensure required fields are populated or handle defaults
                DatabaseService dbs = new DatabaseService();
                dbs.insertRecords(toCreate);
                Logger.logInfo('Created ' + toCreate.size() + ' new assignments.');
            }
            if (!toUpdate.isEmpty()) {
                DatabaseService dbs = new DatabaseService();
                dbs.updateRecords(toUpdate);
                Logger.logInfo('Updated ' + toUpdate.size() + ' existing assignments.');
            }
            if (!toDelete.isEmpty()) {
                DatabaseService dbs = new DatabaseService();
                dbs.deleteRecords(toDelete);

                Logger.logInfo('Deleted ' + toDelete.size() + ' assignments.');
            }
        } catch (DmlException e) {
            // TODO: Implement robust error handling for DML failures
            system.debug('kk ' +  'DML Error: ' + e.getMessage());
            Logger.logError('PhoneNumberSyncService', 'DML Error: ' + e.getMessage());
        }
    }
}






