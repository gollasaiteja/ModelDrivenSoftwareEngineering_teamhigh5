global class C360_handleBusinessUnitBatch implements Database.Batchable<SObject>{
       
    String assetQuery;
    Set<ID> assetIdSet = new Set<Id>();
    global C360_handleBusinessUnitBatch(Set<Id> assetIds){
        assetIdSet = assetIds;
        assetQuery = 'Select Id,CCT_Contact_Center_BU__c,AccountId from Asset Where Id =: assetIdSet';
        system.debug('query string======'+assetQuery);
    }
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){        
        List<Account> custAccntList = new List<Account>();
        List<Account> custAccntUpdList = new List<Account>();
        List<AssetContactRoles__c> asstCntctRoleList = new List<AssetContactRoles__c>();
        List<Contact> contactList = new List<Contact>();
        List<Contact> contactUpdList = new List<Contact>();
        Set<ID> custAccntIdSet = new Set<Id>();
        Set<ID> contactIdSet = new Set<Id>();
        Map<Id,Account> assetAccntMap = new Map<Id,Account>();
        List<Asset> assetList = new List<Asset>();
        assetList = (List<Asset>)Scope;
        for(Asset asst : assetList){
           custAccntIdSet.add(asst.AccountId);
          // assetAccntMap.put(asst.Id,asst.AccountId);
        }        
        asstCntctRoleList = C360_SponsorIndicatorsUtil.findRelatedAssetContactRoles(assetIdSet);
        for(AssetContactRoles__c acr : asstCntctRoleList){
            contactIdSet.add(acr.Contact__c);
        }
        contactList = C360_SponsorIndicatorsUtil.findRelatedContactsByContactIds(contactIdSet);
        for(Contact cnt : contactList){
            custAccntIdSet.add(cnt.AccountId);
			for(Asset ast : assetList){
                if(ast.CCT_Contact_Center_BU__c == 'IIC'){
                    cnt.IIC__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'GB'){
                    cnt.GB__c = true;
                }   
                else if(ast.CCT_Contact_Center_BU__c == 'MI'){
                    cnt.MI__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MLB'){
                    cnt.MLB__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MMF'){
                    cnt.MMF__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MS'){
                    cnt.MS__c = true;
                }
                contactUpdList.add(cnt);
            }
        }
		
		custAccntList = C360_SponsorIndicatorsUtil.findRelatedCustomerAccountsList(custAccntIdSet);
        for(Account acnt : custAccntList){
            for(Asset ast : assetList){
                if(ast.CCT_Contact_Center_BU__c == 'IIC'){
                    acnt.IIC__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'GB'){
                    acnt.GB__c = true;
                }   
                else if(ast.CCT_Contact_Center_BU__c == 'MI'){
                    acnt.MI__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MLB'){
                    acnt.MLB__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MMF'){
                    acnt.MMF__c = true;
                }
                else if(ast.CCT_Contact_Center_BU__c == 'MS'){
                    acnt.MS__c = true;
                }
                custAccntUpdList.add(acnt);
            }
        }
        
        try{
            if(!custAccntUpdList.isEmpty() && custAccntUpdList != null){
                system.debug('custAccntUpdList===='+custAccntUpdList);
                update custAccntUpdList;
            }
            if(!contactUpdList.isEmpty() && contactUpdList != null){
                system.debug('contactUpdList===='+contactUpdList);
                update contactUpdList;
            }
        }
        catch(exception ex){
            system.debug('exception==='+ex);
        }

    }
    
    global void finish(Database.BatchableContext BC){
    }
}
