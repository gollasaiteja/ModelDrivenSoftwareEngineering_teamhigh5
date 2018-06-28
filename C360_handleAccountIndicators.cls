global class C360_handleAccountIndicators implements Database.Batchable<SObject>{
    
    Map<Id,Account> sponsorAccountsMap = new Map<Id,Account>();
    Set<ID> sponsorIdSet = new Set<ID>();
    Set<ID> assetIdSet = new Set<ID>();
	Set<ID> assetTriggerIdSet = new Set<ID>();
    //Boolean isToDelete = false;
    global String whereCondition;
    global String assetQuery;
    global Date todayDate = system.today();
    global C360_handleAccountIndicators(Map<Id,Account> sponsorMap,Set<Id> sponsorIds,Set<Id> assetIds, Set<Id> assetTriggerIds/*, Boolean isDeleteVal*/){
        sponsorAccountsMap = sponsorMap;
        sponsorIdSet = sponsorIds;
        assetIdSet = assetIds;
		assetTriggerIdSet = assetTriggerIds;
        //isToDelete = isDeleteVal;
        system.debug('assetIdSet==='+assetIdSet);
        if(assetIdSet != null){
            whereCondition = 'Id =: assetIdSet';
        }
		else if(assetTriggerIdSet != null){
			whereCondition = 'Id =: assetTriggerIdSet';
		}
        else{
            whereCondition = 'Sponsor__c =: sponsorIdSet';
        }
        assetQuery = 'Select Account.recordType.Name,GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Asset Where '+whereCondition;
        system.debug('query string======'+assetQuery);
    }
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){
        Set<Id> custAccntIdSet = new Set<Id>();
        Map<Id,Asset> assetCustomerMap = new Map<Id,Asset>();
        Map<Id,Asset> assetMap = new Map<Id,Asset>();
        Map<Id,Asset> assetContactMap = new Map<Id,Asset>();
        Map<Id,Asset> endAssetContactMap = new Map<Id,Asset>();
        List<Account> custAccUpdateLst = new List<Account>();
        Set<Id> assetIdSet = new Set<Id>();
        Set<Id> contactIdSet = new Set<Id>();
        Set<Id> endContactIdSet = new Set<Id>();
        List<Contact> contactUpdateLst = new List<Contact>();
		for(Asset asst : (List<Asset>)Scope){
		   system.debug('asst.Account.Recordtype.Name======'+asst.Account.Recordtype.Name);
			if(asst.Account.Recordtype.Name == 'Customer'){
			   custAccntIdSet.add(asst.AccountId); 
			   assetCustomerMap.put(asst.AccountId,asst);
			   assetIdSet.add(asst.Id);
			   assetMap.put(asst.Id,asst);
			}
		}
        
        system.debug('custAccntIdSet from sponsor account====='+custAccntIdSet);
        system.debug('assetMap====='+assetMap);      
        
        for(AssetContactRoles__c asr : C360_SponsorIndicatorsUtil.findRelatedAssetContactRoles(assetIdSet)){            
            if(assetTriggerIds != null){
				contactIdSet.add(asr.Contact__c);  
			}
			else{
				if((asr.End_Date__c = null OR asr.End_Date__c >: system.today()) AND (asr.Asset__r.Coverage_End_Date__c = null OR asr.Asset__r.Coverage_End_Date__c >: system.today())){
					contactIdSet.add(asr.Contact__c);
				}
			}			          
        }
        system.debug('contactIdSet===='+contactIdSet);
        List<Contact> contactsList = new List<Contact>();
        contactsList = C360_SponsorIndicatorsUtil.findRelatedContactsByContactIds(contactIdSet);
        system.debug('contactsList====='+contactsList);
        Set<Id> contactIds = new Set<Id>();
        for(Contact cntct : contactsList){
            contactIds.add(cntct.Id);
            if(cntct.Account.Recordtype.Name == 'Customer'){
                custAccntIdSet.add(cntct.AccountId);
                assetCustomerMap.put(cntct.AccountId,assetContactMap.get(cntct.Id));
            }
        }
        system.debug('custAccntIdSet end contacts 103 line====='+custAccntIdSet);
        if(!contactIds.isEmpty() && contactIds != null){
            for(Contact cnt : contactsList){
                cnt.GB_Canada_Only_Indicator__c =  false;
                cnt.GB_Data_Constraint_Indicator__c = false;
                cnt.GB_OTIP_Indicator__c = false;
                cnt.Manulife_Staff_Indicator__c = false;
                for(AssetContactRoles__c acr : C360_SponsorIndicatorsUtil.findRelatedAssetContactRolesByContacts(contactIds)){                
                    if(acr.Asset__r.GB_Canada_Only_Indicator__c){
                        cnt.GB_Canada_Only_Indicator__c = acr.Asset__r.GB_Canada_Only_Indicator__c; 
                    }
                    if(acr.Asset__r.GB_Data_Constraint_Indicator__c){
                        cnt.GB_Data_Constraint_Indicator__c = acr.Asset__r.GB_Data_Constraint_Indicator__c;
                    }
                    if(acr.Asset__r.GB_OTIP_Indicator__c){
                        cnt.GB_OTIP_Indicator__c = acr.Asset__r.GB_OTIP_Indicator__c;
                    }
                    if(acr.Asset__r.Manulife_Staff_Indicator__c){
                        cnt.Manulife_Staff_Indicator__c = acr.Asset__r.Manulife_Staff_Indicator__c;
                    }                   
                }
                contactUpdateLst.add(cnt);
            }
        }
        system.debug('contactUpdateLst 135 line==='+contactUpdateLst);
        for(Account custAccounts : C360_SponsorIndicatorsUtil.findRelatedCustomerAccountsList(custAccntIdSet)){
            custAccounts.GB_Canada_Only_Indicator__c =  false;
            custAccounts.GB_Data_Constraint_Indicator__c = false;
            custAccounts.GB_OTIP_Indicator__c = false;
            custAccounts.Manulife_Staff_Indicator__c = false;
            for(Asset ast : C360_SponsorIndicatorsUtil.findRelatedAssetByCustomers(custAccntIdSet)){
                if(ast.GB_Canada_Only_Indicator__c){
                    custAccounts.GB_Canada_Only_Indicator__c = ast.GB_Canada_Only_Indicator__c; 
                }
                if(ast.GB_Data_Constraint_Indicator__c){
                    custAccounts.GB_Data_Constraint_Indicator__c = ast.GB_Data_Constraint_Indicator__c;
                }
                if(ast.GB_OTIP_Indicator__c){
                    custAccounts.GB_OTIP_Indicator__c = ast.GB_OTIP_Indicator__c;
                }
                if(ast.Manulife_Staff_Indicator__c){
                    custAccounts.Manulife_Staff_Indicator__c = ast.Manulife_Staff_Indicator__c;
                }
            }           
            custAccUpdateLst.add(custAccounts);
        }
        system.debug('assetCustomerMap====='+assetCustomerMap);
        system.debug('contactUpdateLst==='+contactUpdateLst);
        system.debug('custAccUpdateLst==='+custAccUpdateLst);
        try{
            if(custAccUpdateLst != null && !custAccUpdateLst.isEmpty()){
                update custAccUpdateLst;
            }               
            if(contactUpdateLst != null && !contactUpdateLst.isEmpty()){
                update contactUpdateLst;
            }           
        }
        catch(exception ex){
            system.debug('Exception ==='+ex);
        }
   
    }
    
    global void finish(Database.BatchableContext BC){
    }
}
