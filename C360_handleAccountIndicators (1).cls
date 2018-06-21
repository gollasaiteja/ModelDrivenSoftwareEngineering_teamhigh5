global class C360_handleAccountIndicators implements Database.Batchable<SObject>{
    
    Map<Id,Account> sponsorAccountsMap = new Map<Id,Account>();
    Set<ID> sponsorIdSet = new Set<ID>();
    Set<ID> assetIdSet = new Set<ID>();
    //Boolean isToDelete = false;
    global String whereCondition;
    global String assetQuery;
    global C360_handleAccountIndicators(Map<Id,Account> sponsorMap,Set<Id> sponsorIds,Set<Id> assetIds/*, Boolean isDeleteVal*/){
        sponsorAccountsMap = sponsorMap;
        sponsorIdSet = sponsorIds;
        assetIdSet = assetIds;
        //isToDelete = isDeleteVal;
        system.debug('assetIdSet==='+assetIdSet);
        if(assetIdSet != null){
            whereCondition = 'Id =: assetIdSet';
        }
        else{
            whereCondition = 'Sponsor__c =: sponsorIdSet';
        }
        assetQuery = 'Select Account.recordType.Name,GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Asset Where '+whereCondition;
    }
    
    //sponsorIdLst = sponsorAccountsMap.keyset();
    //public String assetQuery = 'Select Account.recordType.Name,GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Asset Where Sponsor__c =: sponsorIdLst';
    
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
        //for(Account accnt : sponsorAccountsMap.values()){
            for(Asset asst : (List<Asset>)Scope){
               system.debug('asst.Account.Recordtype.Name======'+asst.Account.Recordtype.Name);
                if(asst.Account.Recordtype.Name == 'Customer'){
                   custAccntIdSet.add(asst.AccountId); 
                   assetCustomerMap.put(asst.AccountId,asst);
                   assetIdSet.add(asst.Id);
                   assetMap.put(asst.Id,asst);
                }
            }
        //}
        system.debug('assetCustomerMap====='+assetCustomerMap);
        system.debug('assetMap====='+assetMap);
        
        for(Account custAccounts : C360_SponsorIndicatorsUtil.findRelatedCustomerAccountsList(custAccntIdSet)){
            if(!assetCustomerMap.isEmpty() && assetCustomerMap.get(custAccounts.Id) != null){
                custAccounts.GB_Canada_Only_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_Canada_Only_Indicator__c;
                custAccounts.GB_Data_Constraint_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_Data_Constraint_Indicator__c;
                custAccounts.GB_OTIP_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_OTIP_Indicator__c;
                custAccounts.Manulife_Staff_Indicator__c  = assetCustomerMap.get(custAccounts.Id).Manulife_Staff_Indicator__c;
                custAccUpdateLst.add(custAccounts);
            }            
        }
        for(AssetContactRoles__c asr : C360_SponsorIndicatorsUtil.findRelatedAssetContactRoles(assetIdSet)){
            if(asr.End_Date__c != null && asr.End_Date__c > system.today()){
                endContactIdSet.add(asr.Contact__c);
                endAssetContactMap.put(asr.Contact__c,assetMap.get(asr.Asset__c));
            }
            else{
                contactIdSet.add(asr.Contact__c);
                assetContactMap.put(asr.Contact__c,assetMap.get(asr.Asset__c));
            }
            
        }
        system.debug('contactIdSet===='+contactIdSet+'assetContactMap====='+assetContactMap);
        List<Contact> contactsList = new List<Contact>();
        List<Contact> endContactsList = new List<Contact>();
        if(!endContactIdSet.isEmpty() && endContactIdSet != null){
            endContactsList = C360_SponsorIndicatorsUtil.findRelatedContactsByContactIds(endContactIdSet);
        }
        else{
            contactsList = C360_SponsorIndicatorsUtil.findRelatedContactsByContactIds(contactIdSet);
        }
        for(Contact cntct : contactsList){
            //if(!isToDelete){
                if(!assetContactMap.isEmpty() && assetContactMap.get(cntct.Id) != null){
                    cntct.GB_Canada_Only_Indicator__c = assetContactMap.get(cntct.Id).GB_Canada_Only_Indicator__c;
                    cntct.GB_Data_Constraint_Indicator__c = assetContactMap.get(cntct.Id).GB_Data_Constraint_Indicator__c;
                    cntct.GB_OTIP_Indicator__c = assetContactMap.get(cntct.Id).GB_OTIP_Indicator__c;
                    cntct.Manulife_Staff_Indicator__c  = assetContactMap.get(cntct.Id).Manulife_Staff_Indicator__c;
                    contactUpdateLst.add(cntct);
                }
            /*}else{
                cntct.GB_Canada_Only_Indicator__c = false;
                cntct.GB_Data_Constraint_Indicator__c = false;
                cntct.GB_OTIP_Indicator__c = false;
                cntct.Manulife_Staff_Indicator__c  = false;
                contactUpdateLst.add(cntct);
            }*/
                        
        }
        Set<Id> endContactIds = new Set<Id>();
        for(Contact endCntct : endContactsList){
            endContactIds.add(endCntct.Id);
        }
        if(!endContactIds.isEmpty() && endContactIds != null){
            Boolean canadaIndicator = true;
            for(AssetContactRoles__c acr : C360_SponsorIndicatorsUtil.findRelatedAssetContactRolesByContacts(endContactIds)){
                for(Contact cnt : endContactsList){
                    if(canadaIndicator && acr.Asset__r.GB_Canada_Only_Indicator__c){
                        cnt.GB_Canada_Only_Indicator__c = acr.Asset__r.GB_Canada_Only_Indicator__c;
                    }
                    else{
                        cnt.GB_Canada_Only_Indicator__c =  false;
                        canadaIndicator = false;
                    }
                    if(acr.Asset__r.GB_Data_Constraint_Indicator__c){
                        cnt.GB_Data_Constraint_Indicator__c = acr.Asset__r.GB_Data_Constraint_Indicator__c;
                    }
                    else{
                        cnt.GB_Data_Constraint_Indicator__c=  false;
                    }
                    if(acr.Asset__r.GB_OTIP_Indicator__c){
                        cnt.GB_OTIP_Indicator__c = acr.Asset__r.GB_OTIP_Indicator__c;
                    }
                    else{
                        cnt.GB_OTIP_Indicator__c =  false;
                    }
                    if(acr.Asset__r.Manulife_Staff_Indicator__c){
                        cnt.Manulife_Staff_Indicator__c = acr.Asset__r.Manulife_Staff_Indicator__c;
                    }
                    else{
                        cnt.Manulife_Staff_Indicator__c =  false;
                    }                    
                }
            }
        }
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