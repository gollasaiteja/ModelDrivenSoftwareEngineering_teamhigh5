public with sharing class CCT_AlertTriggerHandler
{
    public static void onBeforeInsert(List<Alert__c> newAlertList)
    {
        if(CCT_Setting__c.getValues('Trigger Updates Alert GB Flags').Boolean_Value__c) // On/Off this functionality using the flag in custom setting
        {
            CCT_AlertTriggerHandlerWithoutSharing.updateCanadaOnlySpecialHandlingStaffPlan(newAlertList);
        }
    }
}