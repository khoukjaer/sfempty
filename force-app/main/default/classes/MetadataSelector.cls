/**
 * The MetadataSelector class is responsible for selects related to custom metadata types
 *  -----------------------------------------------------------------------------
 *  Developer            Date            Description
 *  -----------------------------------------------------------------------------
 *  Kenneth Houkjær         22/06/2025      Added getOpenPhoneNumberSeries and added doc sections 
 * 
 * @author Kenneth Houkjær
 * @date 22/06/2025
 */
public with sharing class MetadataSelector {
	private static final String ERROR_ORIGIN = 'Apex';
	private static final String ERROR_ADDITIONAL_INFO = 'MetadataSelector';
	private static final String API_SETTINGS_TYPE = 'APISettings__mdt';
	private static final String ENVIRONMENT_CREDENTIAL_TYPE = 'Environment_Credential_Mapping__mdt';
	private static final String DOCUMENT_IDENTIFIER_TYPE = 'Document_Identifier__mdt';
	private static final String LOG_IGNORE_TYPE = 'Log_Ignore__mdt';
	private static final String LOGGER_SETTINGS_TYPE = 'Logger_Setting__mdt';
    private static final String FEATURETOGGLE_TYPE = 'FeatureToggle__mdt';
    private static final String OPEN_PHONE_NUMBER_SERIES_TYPE = 'OpenPhoneNumberSeries__mdt';

	private static ErrorLogging errorLogging = new ErrorLogging(ERROR_ORIGIN);

	public static APISettings__mdt getAPISettings(String developerName) {
		APISettings__mdt settings = (APISettings__mdt) Service.record(APISettings__mdt.getInstance(developerName));
		if(settings == null) {
			logError(Label.No_Metadata_Found + ' : ' + API_SETTINGS_TYPE + ' : ' + developerName);
		}

		return settings;
	}

	public static List<Environment_Credential_Mapping__mdt> getEnvironmentCredentialMappings() {
		List<Environment_Credential_Mapping__mdt> mappings = Service.records(Environment_Credential_Mapping__mdt.getAll().values());
		if(mappings.isEmpty()) {
			logError(Label.No_Metadata_Found + ' : ' + ENVIRONMENT_CREDENTIAL_TYPE);
		}
		return mappings;
	}

	public static List<Document_Identifier__mdt> getDocumentIdentifierMappings() {
		List<Document_Identifier__mdt> mappings = Service.records(Document_Identifier__mdt.getAll().values());
		if(mappings.isEmpty()) {
			logError(Label.No_Metadata_Found + ' : ' + DOCUMENT_IDENTIFIER_TYPE);
		}
		return mappings;
	}

	public static List<Log_Ignore__mdt> getLogIgnoreMappings() {
		List<Log_Ignore__mdt> logIgnoreMappings = Log_Ignore__mdt.getAll().values();
		return logIgnoreMappings;
	}

	public static Logger_Setting__mdt getLoggerSettings(String nameSettings) {
		List<Logger_Setting__mdt> metadataRecords = new List<Logger_Setting__mdt>();
		metadataRecords.add(Logger_Setting__mdt.getInstance(nameSettings));
		List<Logger_Setting__mdt> loggerSettings = Service.records(metadataRecords);
		if(loggerSettings.isEmpty()) {
			logError(Label.No_Metadata_Found + ' : ' + LOGGER_SETTINGS_TYPE);
		}
		return loggerSettings.get(0);
	}

	public static List<Logger_Setting__mdt> getLoggerSettings() {
			List<Logger_Setting__mdt> loggerSettings = Service.records(Logger_Setting__mdt.getAll().values());
			if(loggerSettings.isEmpty()) {
				logError(Label.No_Metadata_Found + ' : ' + LOGGER_SETTINGS_TYPE);
			}
			return loggerSettings;
	}
    
    /**
	 * getOpenPhoneNumberSeries
	 */
	public static List<OpenPhoneNumberSeries__mdt> getOpenPhoneNumberSeries() {
			List<OpenPhoneNumberSeries__mdt> openPhoneNumberSeries = Service.records(OpenPhoneNumberSeries__mdt.getAll().values());
			if(openPhoneNumberSeries.isEmpty()) {
				logError(Label.No_Metadata_Found + ' : ' + OPEN_PHONE_NUMBER_SERIES_TYPE);
			}
			return openPhoneNumberSeries;
	}

	static Log_Ignore__mdt createMockedLoggerIgnoreMapping(String label, String userName, Boolean active){
 
        Log_Ignore__mdt loggerMapping = new Log_Ignore__mdt();
        loggerMapping.Filter_String__c = label;
        loggerMapping.Filter_UserName__c = userName;
        loggerMapping.Active__c = active;
 
        return loggerMapping;
    }
 
    static Logger_Setting__mdt createMockedLoggerSetting(LoggingLevel logLevel){
 
        Logger_Setting__mdt loggerSetting = new Logger_Setting__mdt();
        loggerSetting.Log_Level__c = logLevel.toString();
 
        return loggerSetting;
    }

	public static List<VTPX_User_Datatable_Products__mdt> getVTPXUserDatatableProducts(){
            List<VTPX_User_Datatable_Products__mdt> vtpxUserDatatableProducts =  Service.records(VTPX_User_Datatable_Products__mdt.getAll().values());  
            return vtpxUserDatatableProducts;
    }
    
    public static FeatureToggle__mdt getFeatureToggle(String featureName) {
		List<FeatureToggle__mdt> metadataRecords = new List<FeatureToggle__mdt>();
		metadataRecords.add(FeatureToggle__mdt.getInstance(featureName));
		List<FeatureToggle__mdt> listOfFeatureToggles = Service.records(metadataRecords);
		if(listOfFeatureToggles.isEmpty()) {
			logError(Label.No_Metadata_Found + ' : ' + FEATURETOGGLE_TYPE);
		}
		return listOfFeatureToggles.get(0);
	}
    
    public static List<FeatureToggle__mdt> getFeatureToggles() {
			List<FeatureToggle__mdt> listOfFeatureToggles = Service.records(FeatureToggle__mdt.getAll().values());
			if(listOfFeatureToggles.isEmpty()) {
				logError(Label.No_Metadata_Found + ' : ' + FEATURETOGGLE_TYPE);
			}
			return listOfFeatureToggles;
	}

	// enables generically mocking Custom Metadata for testing purposes
	private static Service instance = new Service();

	public static List<SObject> records(List<SObject> records) {
		return instance.passThrough(records);
	}

	public static SObject record(SObject record) {
		return instance.passThrough(record);
	}

	@TestVisible 
	private static void setMock(Service mock) {
		instance = mock;
	}

	public virtual class Service {
		protected virtual List<SObject> passThrough(List<SObject> records) {
			return records;
		}

		protected virtual SObject passThrough(SObject record) {
			return record;
		}
	}

	private static void logError(String errorMessage) {
		errorLogging.addError(errorMessage, ERROR_ADDITIONAL_INFO);
		errorLogging.logErrors();
	}
}
