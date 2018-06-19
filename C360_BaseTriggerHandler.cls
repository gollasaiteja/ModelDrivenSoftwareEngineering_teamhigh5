/**
 * Created by Reid Beckett, Jun 12/2018
 */
public abstract class C360_BaseTriggerHandler {
    public void run(){
        if(!isTriggerActive()) return;
        
        if(Trigger.isBefore){
            if(Trigger.isInsert){
                onBeforeInsert();
            }
            if(Trigger.isUpdate){
                onBeforeUpdate();
            }
            if(Trigger.isDelete){
                onBeforeDelete(trigger.new, trigger.newmap, trigger.old, trigger.oldMap);
            }
            if(Trigger.isUndelete){
                onBeforeUndelete();
            }
        }else if(Trigger.isAfter){
            if(Trigger.isInsert){
                onAfterInsert(trigger.new, trigger.newmap, trigger.old, trigger.oldMap);
            }
            if(Trigger.isUpdate){
                onAfterUpdate(trigger.new, trigger.newmap, trigger.old, trigger.oldMap);
            }
            if(Trigger.isDelete){
                onAfterDelete(trigger.new, trigger.newmap, trigger.old, trigger.oldMap);
            }
            if(Trigger.isUndelete){
                onAfterUndelete();
            }
        }
    }
    
    private Boolean isTriggerActive() {
        for(C360_Trigger__mdt t : [select Active__c from C360_Trigger__mdt where DeveloperName = :getTriggerID()]) {
            return t.Active__c;
        }
        return false;
    }
    
    public Boolean isChanged(sObject sobj, String fieldName) {
        if(Trigger.isInsert) return true;
        else {
            sObject oldSObj = Trigger.oldMap.get(sobj.Id);
            return oldSObj.get(fieldName) != sobj.get(fieldName);
        }
    }
    
    //unique identifier for the trigger
    public abstract String getTriggerID();
    public virtual void onBeforeInsert () {}
    public virtual void onBeforeUpdate() {}
    public virtual void onBeforeDelete(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap) {}
    public virtual void onBeforeUndelete() {}

    public virtual void onAfterInsert(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap) {}
    public virtual void onAfterUpdate(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap) {}
    public virtual void onAfterDelete(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap) {}
    public virtual void onAfterUndelete() {}
}
