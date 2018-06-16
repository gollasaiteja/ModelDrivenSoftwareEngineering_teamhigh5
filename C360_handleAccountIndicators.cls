global class C360_handleAccountIndicators implements Database.Batchable<SObject>{
    
    Map<Id,Account> sponsorAccountsMap = new Map<Id,Account>();
    List<ID> sponsorIdLst = new List<ID>();
    global C360_handleAccountIndicators(Map<Id,Account> sponsorMap,List<Id> sponsorIds){
        sponsorAccountsMap = sponsorMap;
        sponsorIdLst = sponsorIds;
    }
    
    //sponsorIdLst = sponsorAccountsMap.keyset();
    public String assetQuery = 'Select Account.recordType.Name,GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Asset Where Sponsor__c =: sponsorIdLst';
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){
        List<Id> custAccntIdList = new List<Id>();
        Map<Id,Asset> assetCustomerMap = new Map<Id,Asset>();
        List<Account> custAccUpdateLst = new List<Account>();
        List<Id> assetIdLst = new List<Id>();
        List<Id> contactIdLst = new List<Id>();
        List<Contact> contactUpdateLst = new List<Contact>();
        for(Asset asst : (List<Asset>)Scope){
           system.debug('asst.Account.Recordtype.Name======'+asst.Account.Recordtype.Name);
            if(asst.Account.Recordtype.Name == 'Customer'){
               custAccntIdList.add(asst.AccountId); 
               assetCustomerMap.put(asst.AccountId,asst);
               assetIdLst.add(asst.Id);
            }
        }
        system.debug('assetCustomerMap====='+assetCustomerMap);
        for(Account custAccounts : [Select GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Account WHERE Id =: custAccntIdList]){
            if(!assetCustomerMap.isEmpty() && assetCustomerMap.get(custAccounts.Id) != null){
            custAccounts.GB_Canada_Only_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_Canada_Only_Indicator__c;
            custAccounts.GB_Data_Constraint_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_Data_Constraint_Indicator__c;
            custAccounts.GB_OTIP_Indicator__c = assetCustomerMap.get(custAccounts.Id).GB_OTIP_Indicator__c;
            custAccounts.Manulife_Staff_Indicator__c  = assetCustomerMap.get(custAccounts.Id).Manulife_Staff_Indicator__c;
            }
            custAccUpdateLst.add(custAccounts);
        }
        for(AssetContactRoles__c asr : [Select Id, Asset__c, Contact__c from AssetContactRoles__c WHERE Asset__c =: assetIdLst]){
            contactIdLst.add(asr.Contact__c);
        }
        system.debug('contactIdLst===='+contactIdLst+'assetCustomerMap====='+assetCustomerMap);
        for(Contact cntct : [Select Id,AccountId from Contact where Id =: contactIdLst]){
            if(!assetCustomerMap.isEmpty() && assetCustomerMap.get(cntct.AccountId) != null){
            cntct.GB_Canada_Only_Indicator__c = assetCustomerMap.get(cntct.AccountId).GB_Canada_Only_Indicator__c;
            cntct.GB_Data_Constraint_Indicator__c = assetCustomerMap.get(cntct.AccountId).GB_Data_Constraint_Indicator__c;
            cntct.GB_OTIP_Indicator__c = assetCustomerMap.get(cntct.AccountId).GB_OTIP_Indicator__c;
            cntct.Manulife_Staff_Indicator__c  = assetCustomerMap.get(cntct.AccountId).Manulife_Staff_Indicator__c;
            }
            contactUpdateLst.add(cntct);
        }
        update custAccUpdateLst;
        update contactUpdateLst;
   
    }
    
    global void finish(Database.BatchableContext BC){
    }
}