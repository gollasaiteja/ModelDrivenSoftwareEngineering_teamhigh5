/**
 * Created by Reid Beckett, Jun 12/2018
 */
public class C360_SponsorIndicatorsUtil {

    public static List<Account> findRelatedCustomerAccountsBySponsors(Set<Id> sponsorAccountIds){
        //TODO
        return null;
    }

    public static List<Account> findRelatedContactsBySponsors(Set<Id> sponsorAccountIds){
        //TODO
        return null;
    }

    public static List<Account> findRelatedCustomerAccounts(Set<Id> assetContactRoleIds){
        //TODO
        return null;
    }

    public static List<Account> findRelatedContacts(Set<Id> assetContactRoleIds){
        //TODO
        return null;
    }

    public static Map<Id, C360.SponsorIndicators> getSponsorIndicators(List<Account> customerAccounts){
        //TODO
        return null;
    }

    public static Map<Id, C360.SponsorIndicators> getSponsorIndicators(List<Contact> contacts){
        //TODO
        return null;
    }
    
    public static List<Account> findRelatedCustomerAccountsList(Set<Id> custAccountIdSet){
        return [Select GB_Canada_Only_Indicator__c, Id, GB_Data_Constraint_Indicator__c,GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c from Account WHERE Id =: custAccountIdSet];
    }
    
    public static List<AssetContactRoles__c> findRelatedAssetContactRoles(Set<Id> assetIds){
        return [Select Id, Asset__c, Contact__c,End_Date__c from AssetContactRoles__c WHERE Asset__c =: assetIds];
    }
    
    public static List<Contact> findRelatedContactsByContactIds(Set<Id> contactIds){
        return [Select Id,AccountId, Account.RecordType.Name from Contact where Id =: contactIds];
    }
    
    public static List<AssetContactRoles__c> findRelatedAssetContactRolesByContacts(Set<Id> contactIds){
        return [Select Id, Asset__c, Contact__c,End_Date__c,Asset__r.GB_Canada_Only_Indicator__c,Asset__r.GB_Data_Constraint_Indicator__c,Asset__r.GB_OTIP_Indicator__c,Asset__r.Manulife_Staff_Indicator__c from AssetContactRoles__c WHERE Contact__c =: contactIds AND (End_Date__c = null OR End_Date__c >: system.today()) AND (Asset__r.Coverage_End_Date__c = null OR Asset__r.Coverage_End_Date__c >: system.today())];
    }
    
    public static List<Asset> findRelatedAssetByCustomers(Set<Id> custAccountIds){
        return [Select Id,GB_Canada_Only_Indicator__c, GB_OTIP_Indicator__c,Manulife_Staff_Indicator__c,GB_Data_Constraint_Indicator__c from Asset Where AccountId =: custAccountIds  AND (Coverage_End_Date__c = null OR Coverage_End_Date__c >: system.today())];
    }
}
