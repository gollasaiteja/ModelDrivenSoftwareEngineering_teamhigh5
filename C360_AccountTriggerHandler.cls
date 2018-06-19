/**
 * Created by Reid Beckett, Jun 12/2018
 */
public class C360_AccountTriggerHandler extends C360_BaseTriggerHandler {

    public C360_AccountTriggerHandler (boolean isUpdate, List<SObject> newObjectList, List<SObject> oldObjectList, 
        Map<Id,SObject> newObjectMap, Map<Id,SObject> oldObjectMap){
        //super(isUpdate, newObjectList, oldObjectList, newObjectMap, oldObjectMap);
    }
    
    public override String getTriggerID() {
        return 'Account';
    }
    
    //public override void onAfterUpdate(){
        //TODO
        //List<Account> newAccountList = (List<Account>)this.newObjectList;
        //for(Account accnt : newAccountList){}
    //}
}