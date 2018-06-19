/**
 * Created by Reid Beckett, Jun 12/2018
 */
public class C360_AccountTriggerHandler extends C360_BaseTriggerHandler {
      
    public override String getTriggerID() {
        return 'Account';
    }
        
    public override void onAfterUpdate(List<SObject> newSObjectList, Map<Id,SObject> newSObjectMap,List<SObject> oldSObjectList, Map<Id,SObject> oldSObjectMap){
        //TODO
		Id recordTypeIdValue = Schema.SobjectType.Account.getRecordtypeInfosByname().get('Sponsor Customer').getRecordTypeId();
		Set<Id> accountIdSet = new Set<Id>();
		Map<Id,Account> accountMap = new Map<Id,Account>();
		
		for(Account accnt : (List<Account>)newSObjectList){
		   Account oldAccount = (Account)oldSObjectMap.get(accnt.Id);
		   system.debug('record type==='+accnt.recordType.Name);
			if(accnt.recordTypeId == recordTypeIdValue){
				if(accnt.GB_Canada_Only_Indicator__c != oldAccount.GB_Canada_Only_Indicator__c ||
					accnt.GB_Data_Constraint_Indicator__c != oldAccount.GB_Data_Constraint_Indicator__c ||
					accnt.GB_OTIP_Indicator__c != oldAccount.GB_OTIP_Indicator__c ||
					accnt.Manulife_Staff_Indicator__c!= oldAccount.Manulife_Staff_Indicator__c){
						accountIdSet.add(accnt.Id);
						accountMap.put(accnt.Id,accnt);
					}
			}
		}
		system.debug('accountIdLst====='+accountIdSet);
		if(!system.isBatch() && !accountIdSet.isEmpty()){
			database.ExecuteBatch(new C360_handleAccountIndicators(accountMap,accountIdSet,null),200);
		}
    }

}
