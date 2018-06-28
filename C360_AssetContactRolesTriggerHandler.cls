public class C360_AssetContactRolesTriggerHandler  extends C360_BaseTriggerHandler {

    public override String getTriggerID() {
        return 'AssetContactRoles_c';
    }
    
    public override void onAfterInsert(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
        system.debug('Invoked======');
        getContactIds(newSObjectList,oldSObjectList);
    }

    public override void onAfterUpdate(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
        getContactIds(newSObjectList,oldSObjectList);
    }

    public override void onAfterDelete(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
    }
    public override void onBeforeDelete(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
        getContactIds(newSObjectList,oldSObjectList);
    }

    public override void onAfterUndelete(){
        //TODO
    }
    
    public static void getContactIds(List<SObject> newSObjectList,/*Boolean tobeDeleted,*/ List<SObject> oldSObjectList){
        Set<Id> contactIdSet = new Set<Id>();
        Set<Id> assetIdSet = new Set<Id>();
        
        //if(!tobeDeleted){
            for(AssetContactRoles__c acr : (List<AssetContactRoles__c>)newSObjectList){
                contactIdSet.add(acr.Contact__c);
                assetIdSet.add(acr.Asset__c);
            }
       /* }
        else{
            for(AssetContactRoles__c acr : (List<AssetContactRoles__c>)oldSObjectList){
                contactIdSet.add(acr.Contact__c);
                assetIdSet.add(acr.Asset__c);
            }
        }*/
        system.debug('assetIdSet in ASC ===== '+assetIdSet);
        if(!System.isbatch()){
            Database.executeBatch(new C360_handleAccountIndicators(null,null,assetIdSet,null),200);
        }
    }

}
