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
        assetQuery = 'Select Account.recordType.Name from Asset Where '+whereCondition;
        system.debug('query string======'+assetQuery);
    }
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){
        
   
    }
    
    global void finish(Database.BatchableContext BC){
    }
}
