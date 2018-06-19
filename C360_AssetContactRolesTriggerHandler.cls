public class C360_AssetContactRolesTriggerHandler  extends C360_BaseTriggerHandler {

    public override String getTriggerID() {
        return 'AssetContactRoles__c';
    }
    
    public override void onAfterInsert(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
        getContactIds(newSObjectList);
    }

    public override void onAfterUpdate(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
    }

    public override void onAfterDelete(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
    }

    public override void onAfterUndelete(){
        //TODO
    }
    
    public static void getContactIds(List<SObject> newSObjectList){
        Set<Id> contactIdSet = new Set<Id>();
        Set<Id> assetIdSet = new Set<Id>();
        for(AssetContactRoles__c acr : (List<AssetContactRoles__c>)newSObjectList){
            contactIdSet.add(acr.Contact__c);
            assetIdSet.add(acr.Asset__c);
        }
        if(!System.isbatch()){
            Database.executeBatch(new C360_handleAssetContactIndicators(assetIdSet,null),200);
        }
    }

}