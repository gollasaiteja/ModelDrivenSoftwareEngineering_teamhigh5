global class C360_handleAssetIndicators implements Database.Batchable<SObject>{
    
    Map<Id,Account> sponsorAccountsMap = new Map<Id,Account>();
    global C360_handleAssetIndicators(Map<Id,Account> sponsorMap){
        sponsorAccountsMap = sponsorMap;
        assetQuery = 'Select Account.recordType.Name,Canada_Only__c, Id, Special_Handling__c,GB_OTIP_Indicator__c,Staff_Plan__c,GB_OTIP_Staff_Indicator__c from Asset Where Sponsor__c =: sponsorAccountsMap.keyset()';
        system.debug('query string======'+assetQuery);
    }
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){        
        for(Asset asst : (List<Asset>)Scope){
           asst.Canada_Only__c = sponsorAccountsMap.get(asst.Sponsor__c).Canada_Only__c;
		   asst.Special_Handling__c = sponsorAccountsMap.get(asst.Sponsor__c).Special_Handling__c;
		   asst.GB_OTIP_Indicator__c = sponsorAccountsMap.get(asst.Sponsor__c).GB_OTIP_Indicator__c;
		   asst.Staff_Plan__c = sponsorAccountsMap.get(asst.Sponsor__c).Staff_Plan__c;
		   asst.GB_OTIP_Staff_Indicator__c = sponsorAccountsMap.get(asst.Sponsor__c).GB_OTIP_Staff_Indicator__c;
		   assetUpdateLst.add(asst);
        }
		Database.SaveResult[] saveRes = Database.update(assetUpdateLst, false);
		// Iterate through each returned result
		for (Database.SaveResult res : saveRes) {
			if (!res.isSuccess()) {
				// Operation failed, so get all errors                
				for(Database.Error err : res.getErrors()) {
					//TODO
				}
			}
		}

    }
    
    global void finish(Database.BatchableContext BC){
		database.ExecuteBatch(new C360_handleAccountIndicators(sponsorAccountsMap,sponsorAccountsMap.keyset(),null,null),200);
	}
}