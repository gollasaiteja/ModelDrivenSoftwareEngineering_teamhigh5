global class C360_handleAssetContactIndicators implements Database.Batchable<SObject>{
    
    //Map<Id,Account> sponsorAccountsMap = new Map<Id,Account>();
    Set<ID> assetIdSet = new Set<ID>();
    String whereCondition ;
    Set<ID> sponsorIdLst = new Set<ID>();
    global C360_handleAssetContactIndicators(Set<Id> assetIds,Set<Id> sponsorIds){
        //sponsorAccountsMap = sponsorMap;
        assetIdSet = assetIds;
         sponsorIdLst = sponsorIds;
         system.debug('assetIdSet==='+assetIdSet);
        if(!assetIdSet.isEmpty() && assetIdSet != null){
            whereCondition = 'Id =: assetIdSet';
        }
        else{
            whereCondition = 'Sponsor__c =: sponsorIdLst';
        }
    }
    
    //sponsorIdLst = sponsorAccountsMap.keyset();
    
    public String assetQuery = 'Select Account.recordType.Name,GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Asset '+whereCondition;
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('assetQuery===='+assetQuery);
        return Database.getQueryLocator(assetQuery);
    }
    
    global void execute(Database.BatchableContext BC, SObject[] Scope){
       
    }
    
    global void finish(Database.BatchableContext BC){
    }
}