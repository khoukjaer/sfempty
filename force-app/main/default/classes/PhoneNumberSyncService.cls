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

    // Wrapper method for the static call to make it mockable in tests
    @TestVisible // Or protected if tests are in the same namespace and can extend
    protected virtual NumberResDAO.NumberDetails callGetNumberDetails(NumberService.GetNumbersParameterbuilder params) {
        return NumberService.getNumberDetails(params);
    }

    public void synchronizeAssignments() {
        Map<String, Account_Phone_Number_Assignment__c> localAssignments = getLocalAssignments();
        Map<String, NumberResDAO.NumberData> remoteAssignments = getRemoteAssignments();
        compareAndPrepareDML(localAssignments, remoteAssignments);
    }

    private Map<String, Account_Phone_Number_Assignment__c> getLocalAssignments() {
        Map<String, Account_Phone_Number_Assignment__c> localAssignmentsMap = new Map<String, Account_Phone_Number_Assignment__c>();
        // TODO: Query all fields required for comparison and updates.
        // For now, using Name and a placeholder 'Status__c' and 'Series__c'.
        // Add other fields from Account_Phone_Number_Assignment__c as needed.
        for (Account_Phone_Number_Assignment__c assignment : [
            SELECT Id, Name, Status__c, Series__c
            FROM Account_Phone_Number_Assignment__c
        ]) {
            localAssignmentsMap.put(assignment.Name, assignment);
        }
        return localAssignmentsMap;
    }

    private Map<String, NumberResDAO.NumberData> getRemoteAssignments() {
        Map<String, NumberResDAO.NumberData> remoteAssignmentsMap = new Map<String, NumberResDAO.NumberData>();
        Set<String> openSeries = new Set<String>();
        for (OpenPhoneNumberSeries__mdt series : [SELECT MasterLabel, DeveloperName FROM OpenPhoneNumberSeries__mdt]) {
            // Assuming DeveloperName holds the series identifier that matches NumberService's numberGroup
            openSeries.add(series.DeveloperName);
        }

        // TODO: Replace this with actual logic to get all number series
        List<String> allSeries = new List<String>{'Series1', 'Series2', 'OpenSeries1'};

        List<String> defaultStatuses = new List<String>{'AA', 'AR', 'AI', 'AS'};
        List<String> openSeriesStatuses = new List<String>{'AR'};

        for (String currentSeries : allSeries) {
            List<String> statusesToQuery = openSeries.contains(currentSeries) ? openSeriesStatuses : defaultStatuses;
            for (String status : statusesToQuery) {
                NumberService.GetNumbersParameterbuilder params = new NumberService.GetNumbersParameterbuilder();
                params.withNumberGroup(currentSeries);
                params.withNumberStatus(status);

                // Use the wrapper method instead of direct static call
                NumberResDAO.NumberDetails details = callGetNumberDetails(params);

                if (details != null && details.data != null) {
                    for (NumberResDAO.NumberData numberData : details.data) {
                        if (String.isNotBlank(numberData.phoneNumber)) {
                            remoteAssignmentsMap.put(numberData.phoneNumber, numberData);
                        }
                    }
                } else if (details != null && details.error != null) {
                    System.debug('Error fetching remote numbers for series ' + currentSeries + ' with status ' + status + ': ' + details.error.message);
                }
            }
        }
        return remoteAssignmentsMap;
    }

    private void compareAndPrepareDML(
        Map<String, Account_Phone_Number_Assignment__c> localAssignments,
        Map<String, NumberResDAO.NumberData> remoteAssignments
    ) {
        List<Account_Phone_Number_Assignment__c> toCreate = new List<Account_Phone_Number_Assignment__c>();
        List<Account_Phone_Number_Assignment__c> toUpdate = new List<Account_Phone_Number_Assignment__c>();
        List<Account_Phone_Number_Assignment__c> toDelete = new List<Account_Phone_Number_Assignment__c>();

        // Iterate through remote assignments to find new or changed records
        for (String remoteKey : remoteAssignments.keySet()) {
            NumberResDAO.NumberData remoteData = remoteAssignments.get(remoteKey);
            Account_Phone_Number_Assignment__c localRecord = localAssignments.get(remoteKey);

            if (localRecord == null) {
                Account_Phone_Number_Assignment__c newAssignment = new Account_Phone_Number_Assignment__c();
                newAssignment.Name = remoteData.phoneNumber;
                newAssignment.Status__c = remoteData.numberStatus;
                newAssignment.Series__c = remoteData.numberGroup;
                toCreate.add(newAssignment);
            } else {
                boolean changed = false;
                if (localRecord.Status__c != remoteData.numberStatus) {
                    localRecord.Status__c = remoteData.numberStatus;
                    changed = true;
                }
                if (localRecord.Series__c != remoteData.numberGroup) {
                    localRecord.Series__c = remoteData.numberGroup;
                    changed = true;
                }
                if (changed) {
                    toUpdate.add(localRecord);
                }
            }
        }

        for (String localKey : localAssignments.keySet()) {
        for (String localKey : localAssignments.keySet()) {
            if (!remoteAssignments.containsKey(localKey)) {
                toDelete.add(localAssignments.get(localKey));
            }
        }

        executeDMLOperations(toCreate, toUpdate, toDelete);
    }

    private void executeDMLOperations(
        List<Account_Phone_Number_Assignment__c> toCreate,
        List<Account_Phone_Number_Assignment__c> toUpdate,
        List<Account_Phone_Number_Assignment__c> toDelete
    ) {
        // Placeholder for DML execution
        try {
            if (!toCreate.isEmpty()) {
                // TODO: Before insert, ensure required fields are populated or handle defaults
                insert toCreate;
                System.debug('Created ' + toCreate.size() + ' new assignments.');
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
                System.debug('Updated ' + toUpdate.size() + ' existing assignments.');
            }
            if (!toDelete.isEmpty()) {
                delete toDelete;
                System.debug('Deleted ' + toDelete.size() + ' assignments.');
            }
        } catch (DmlException e) {
            // TODO: Implement robust error handling for DML failures
            System.debug('DML Error: ' + e.getMessage());
            // Consider logging errors, sending notifications, or a retry mechanism for certain errors
        }
    }
}
