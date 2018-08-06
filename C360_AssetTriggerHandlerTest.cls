@isTest
public class C360_AssetTriggerHandlerTest{
    static testMethod void testAsset(){
        C360_AssetTriggerHandler handlerCls = new C360_AssetTriggerHandler();
        handlerCls.getTriggerID();
        Map<Id,Asset> newAssetMap = new Map<Id,Asset>();
        Map<Id,Asset> oldAssetMap = new Map<Id,Asset>();
        List<Account> newAccount = C360_UtilTest.createAccountData();
        List<Account> oldAccount = C360_UtilTest.createAccountData();
        List<Asset> oldAsset = C360_UtilTest.createAssetData(oldAccount[0].Id,oldAccount[0].Id);
        List<Asset> newAsset = C360_UtilTest.createAssetData(newAccount[0].Id,newAccount[0].Id);
        newAsset[0].Coverage_End_Date__c = system.today();
        newAsset[0].Sponsor__c = oldAccount[0].Id;
        update newAsset[0];
        
        oldAssetMap.put(oldAsset[0].Id,oldAsset[0]);
        newAssetMap.put(newAsset[0].Id,newAsset[0]);
        handlerCls.onAfterUpdate(newAsset,newAssetMap,oldAsset,oldAssetMap);
        Test.StartTest();
        //database.ExecuteBatch(new C360_handleAssetIndicators(newAccountMap),200);
        Test.StopTest();
    }
}