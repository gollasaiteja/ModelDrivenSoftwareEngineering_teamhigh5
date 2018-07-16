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
        assetQuery = 'Select Account.recordType.Name,Canada_Only__c, Id, Special_Handling__c,GB_OTIP_Indicator__c,Staff_Plan__c,GB_OTIP_Staff_Indicator__c from Asset Where '+whereCondition;
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
        Map<Id,AssetContactRoles__c> assetContactIdMap = new Map<Id,AssetContactRoles__c>();
        Map<Id,Asset> assetAccountIdMap = new Map<Id,Asset>();
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
            system.debug('asr====='+asr);
            if(assetTriggerIdset != null || assetIdSet != null){
                contactIdSet.add(asr.Contact__c);  
                system.debug('contactIdSet 1111111111111111====='+contactIdSet);
            }
            else{
                if((asr.End_Date__c == null || asr.End_Date__c > system.today()) && (asr.Asset__r.Coverage_End_Date__c == null || asr.Asset__r.Coverage_End_Date__c > system.today())){
                    contactIdSet.add(asr.Contact__c);
                    system.debug('contactIdSet 2222222222222====='+contactIdSet);
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
            List<AssetContactRoles__c> asstContactRolesLst = new List<AssetContactRoles__c>();
            asstContactRolesLst = C360_SponsorIndicatorsUtil.findRelatedAssetContactRolesByContacts(contactIds);
            for(AssetContactRoles__c acr : C360_SponsorIndicatorsUtil.findRelatedAssetContactRolesByContacts(contactIds)){
                assetContactIdMap.put(acr.contact__c, acr);
            }
            system.debug('assetContactIdMap======'+assetContactIdMap);
            Integer canadaOnlyCheck = 0;
            for(Contact cnt : contactsList){
                cnt.Canada_Only__c =  false;
                cnt.Is_Canada_Email__c =  false;
                cnt.Special_Handling__c = false;
                cnt.GB_OTIP_Indicator__c = false;
                cnt.Staff_Plan__c = false;
                cnt.GB_OTIP_Staff_Indicator__c = false;
                /*if(assetContactIdMap.get(cnt.Id) != null){
                    if(assetContactIdMap.get(cnt.Id).Asset__r.Canada_Only__c){
                        cnt.Canada_Only__c = true;
                    }
                    if(assetContactIdMap.get(cnt.Id).Asset__r.Special_Handling__c){
                        cnt.Special_Handling__c = true;
                    }
                    if(assetContactIdMap.get(cnt.Id).Asset__r.GB_OTIP_Indicator__c){
                        cnt.GB_OTIP_Indicator__c = true;
                    }
                    if(assetContactIdMap.get(cnt.Id).Asset__r.Staff_Plan__c){
                        cnt.Staff_Plan__c = true;
                    }
                }*/
                for(AssetContactRoles__c acr : asstContactRolesLst){                
                    if(cnt.Id == acr.Contact__c){
                        if(!acr.Asset__r.Canada_Only__c){
                            cnt.Canada_Only__c = acr.Asset__r.Canada_Only__c;
                            canadaOnlyCheck = canadaOnlyCheck + 1;
                        }
                        else if(acr.Asset__r.Canada_Only__c && canadaOnlyCheck == 0){
                            cnt.Canada_Only__c = true;
                        }
                        if(acr.Asset__r.Canada_Only__c){
                            cnt.Is_Canada_Email__c  = true ; 
                        }
                        if(acr.Asset__r.Special_Handling__c){
                            cnt.Special_Handling__c = acr.Asset__r.Special_Handling__c;
                        }
                        if(acr.Asset__r.GB_OTIP_Indicator__c){
                            cnt.GB_OTIP_Indicator__c = acr.Asset__r.GB_OTIP_Indicator__c;
                        }
                        if(acr.Asset__r.Staff_Plan__c){
                            cnt.Staff_Plan__c = acr.Asset__r.Staff_Plan__c;
                        }
                        if(acr.Asset__r.GB_OTIP_Staff_Indicator__c){
                            cnt.GB_OTIP_Staff_Indicator__c = acr.Asset__r.GB_OTIP_Staff_Indicator__c;
                        }
                    }                   
                }
                contactUpdateLst.add(cnt);
            }
        }
        system.debug('contactUpdateLst 135 line==='+contactUpdateLst);
        for(Asset ast : C360_SponsorIndicatorsUtil.findRelatedAssetByCustomers(custAccntIdSet)){
            assetAccountIdMap.put(ast.AccountId,ast);
        }
        Integer canadaOnlyCheck = 0;
        for(Account custAccounts : C360_SponsorIndicatorsUtil.findRelatedCustomerAccountsList(custAccntIdSet)){
            custAccounts.Canada_Only__c =  false;
            //custAccounts.Is_Canada_Email__c =  false;
            custAccounts.Special_Handling__c = false;
            custAccounts.GB_OTIP_Indicator__c = false;
            custAccounts.Staff_Plan__c = false;
            custAccounts.GB_OTIP_Staff_Indicator__c = false;
            if(assetAccountIdMap.get(custAccounts.Id) != null){                
                if(!assetAccountIdMap.get(custAccounts.Id).Canada_Only__c){
                    custAccounts.Canada_Only__c = false;
                    canadaOnlyCheck = canadaOnlyCheck + 1;
                }
                else if(assetAccountIdMap.get(custAccounts.Id).Canada_Only__c && canadaOnlyCheck == 0){
                    custAccounts.Canada_Only__c = true;
                }
               /* if(assetAccountIdMap.get(custAccounts.Id).Canada_Only__c){
                      custAccounts.Is_Canada_Email__c = true;
                } */
                if(assetAccountIdMap.get(custAccounts.Id).Special_Handling__c){
                    custAccounts.Special_Handling__c = true;
                }
                if(assetAccountIdMap.get(custAccounts.Id).GB_OTIP_Indicator__c){
                    custAccounts.GB_OTIP_Indicator__c = true;
                }
                if(assetAccountIdMap.get(custAccounts.Id).Staff_Plan__c){
                    custAccounts.Staff_Plan__c = true;
                }
                if(assetAccountIdMap.get(custAccounts.Id).GB_OTIP_Staff_Indicator__c){
                    custAccounts.GB_OTIP_Staff_Indicator__c = true;
                }
            }
            /*for(Asset ast : C360_SponsorIndicatorsUtil.findRelatedAssetByCustomers(custAccntIdSet)){
                if(ast.AccountId == custAccounts.Id){
                    if(ast.Canada_Only__c){
                        custAccounts.Canada_Only__c = ast.Canada_Only__c; 
                    }
                    if(ast.Special_Handling__c){
                        custAccounts.Special_Handling__c = ast.Special_Handling__c;
                    }
                    if(ast.GB_OTIP_Indicator__c){
                        custAccounts.GB_OTIP_Indicator__c = ast.GB_OTIP_Indicator__c;
                    }
                    if(ast.Staff_Plan__c){
                        custAccounts.Staff_Plan__c = ast.Staff_Plan__c;
                    }
                }               
            }*/           
            custAccUpdateLst.add(custAccounts);
        }
      /*  system.debug('assetCustomerMap====='+assetCustomerMap);
          system.debug('contactUpdateLst==='+contactUpdateLst);
          system.debug('custAccUpdateLst==='+custAccUpdateLst); */
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