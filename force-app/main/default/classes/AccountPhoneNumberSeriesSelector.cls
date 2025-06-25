/**
 * The AccountPhoneNumberSeriesSelector class is responsible for selects related to Account Phone Number Series
 *  -----------------------------------------------------------------------------
 *  Developer            Date            Description
 *  -----------------------------------------------------------------------------
 *  Kenneth Houkjær         22/06/2025      Initial version 
 * 
 * @author Kenneth Houkjær
 * @date 22/06/2025
 */
public with sharing class AccountPhoneNumberSeriesSelector{

    /**
     * 
     * @param acc An Account owning the phone number series, if null all phone number series for all 
     *            Accounts are returned.
     * @return List<Account_Phone_Number_Assignment__c> 
     */
     public static List<Account_Phone_Number_Series__c> getAllAccountPhoneNumberSeries(Account acc){

        List<Account_Phone_Number_Series__c> series;
        List<String> fieldsToQuery = new List<String>{
            'Id', 'Name', 'Number_Group__c', 'Number_Location__c', 'CVR__c', 'Number_Pattern__c', 'Product_type__c'
        };
        
        if(acc != null){
            series = new Query('Account_Phone_Number_Series__c').
            selectFields(fieldsToQuery).
            addConditionEq('Account__c', acc.Id).
            run();
        }
        else{
            series = new Query('Account_Phone_Number_Series__c').
            selectFields(fieldsToQuery).
            run();
        }

        return series;
     }
}
