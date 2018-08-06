@isTest
public class C360_AccountTriggerHandlerTest{
    static testMethod void testSponsorAccount(){
        C360_AccountTriggerHandler handlerCls = new C360_AccountTriggerHandler();
        handlerCls.getTriggerID();
        Map<Id,Account> newAccountMap = new Map<Id,Account>();
        Map<Id,Account> oldAccountMap = new Map<Id,Account>();
        List<Account> newAccount = C360_UtilTest.createAccountData();
        newAccountMap.put(newAccount[0].Id,newAccount[0]);
        newAccount[0].Canada_Only__c = false;
        newAccount[0].Special_Handling__c = false;
        newAccount[0].GB_OTIP_Indicator__c = false;
        newAccount[0].GB_OTIP_Staff_Indicator__c = true;
        newAccount[0].Staff_Plan__c = true;
        update newAccount[0];
        List<Account> oldAccount = C360_UtilTest.createAccountData();
        oldAccountMap.put(oldAccount[0].Id,oldAccount[0]);
        handlerCls.onAfterUpdate(newAccount,newAccountMap,oldAccount,oldAccountMap);
        List<Asset> assetList = C360_UtilTest.createAssetData(newAccount[0].Id,oldAccount[0].Id);
        Test.StartTest();
        database.ExecuteBatch(new C360_handleAssetIndicators(newAccountMap),200);
        Test.StopTest();
    }
}