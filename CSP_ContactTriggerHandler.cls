/**
* Author    :   Cognizant
* Name      :   CSP_ContactTriggerHandler.cls
* Purpose   :   To create Portal users for advisors on update operation if Advisor with same External Id is not found

* DATE        Author        User Story/Description
  09/08       Ratan Kumar     Original
*/
public class CSP_ContactTriggerHandler{
    
    public static map<String,user> ContactIduserMap;
    public static list<string> advisorIdLst;
    public static map<Id,Contact> advisorMap;
    public static string advisorid;
    
    /**
    * @description  :   This method is responsible for creating new Partner User records for existing Advisors if User does not exist 
    * @param        :   List<Contact> (Trigger.new), Map<Id,Contact> (Trigger.oldMap)
    * @return       :   Void
    * @throws       :   None
    */      
    public static void createUserOnUpdate(List<Contact> conLst, Map<Id,Contact> oldConLst){
        try{
            advisorIdLst = new list<string>();
            ContactIduserMap = new map<String,user>();
            advisorMap = new map<Id,Contact>();
            Profile dataAnalystProf = [Select Id, Name 
                                       FROM Profile 
                                       WHERE Name = 'Cross Sell Data Analyst' Limit 1];
            String portalUserProfileId = [SELECT Id 
                                          FROM Profile 
                                          WHERE Name = 'Cross Sell Portal User'].get(0).Id;
            String advisorRecType = [SELECT DeveloperName,Name 
                                     FROM RecordType 
                                     WHERE developername='Distributor' and SobjectType  = 'Contact'].get(0).id;
            //if(profile.id=dataAnalystProf.id){
            for(Contact c :conlst){ 
                If(c.recordtypeid==advisorRecType &&
                    oldConLst.get(c.Id).Journey_Status__c != c.Journey_Status__c){                
                    /*system.debug('@@@@c.id '+c.id);
                    advisorId = c.id;
                    system.debug('@@@@advisorid '+advisorId);
                    advisorIdLst.add(advisorId);*/
                    advisorMap.put(c.id,c);
                }
            }
            system.debug('@@@advisorMap'+advisorMap.size());
            // system.debug('@@@advisorIdLst'+advisorIdLst);
            
            if(advisorMap.size() > 0){
                List<User> userlst = [Select id,contactid FROM user 
                                      WHERE contactId IN:advisorMap.keyset() 
                                      AND profileid =: portalUserProfileId];
                system.debug('@@@@usrlst' +userlst);
                for(User u :userlst){
                    system.debug('@@@User is : '+u);
                    ContactIduserMap.put(u.contactid,u);
                }
                system.debug('@@@ContactIduserMap'+ContactIduserMap);       
                //}
                List<User> usrListToInsert= new List<User>();
                for(Contact c:advisorMap.values()){
                    if(!ContactIduserMap.containsKey(c.id) ){
                        //string fedId = c.External_ID__c.substringAfter('DSS'); //As the Contact external Id has a preceding 'DSS'
                        User uObj= new User();
                        uObj.firstname = c.firstname;
                        uObj.lastname = c.lastName;
                        uObj.Username = (c.Email == null) ? (c.External_ID__c + '@manulife-cdn.com') : (c.External_ID__c + c.Email);
                        uObj.Email = (c.Email == null) ? (c.External_ID__c + '@testmanulife-cdn.com') : c.Email;
                        uObj.Alias = c.lastName.right(3)+c.firstName.right(3);
                        uObj.ProfileId = portalUserProfileId;
                        uObj.IsActive = true; 
                        uObj.TimeZoneSidKey = 'GMT';
                        uObj.LanguageLocaleKey = 'en_US';
                        uObj.EmailEncodingKey = 'UTF-8';
                        uObj.LocaleSidKey = 'en_US';
                        uObj.ContactId = c.Id;
                        uObj.FederationIdentifier = c.External_ID__c.substringAfter('DSS'); //As the Contact external Id has a preceding 'DSS'
                        usrListToInsert.add(uObj);
                    }
                }
                system.debug('@@@usrListToInsert before : '+usrListToInsert);
                
                if(usrListToInsert!=NULL){
                    insert usrListToInsert;
                    system.debug('@@@Inserted User after : '+usrListToInsert);
                }
            }
        }
        catch(Exception ex){
            System.debug('**** Exception Occoured ****'+ex);
        }
    }
    
    /**
    * @description  :   This method is responsible for generating error if the Advisor Contact does not exist while Partner User creation 
    * @param        :   List<Contact> (Trigger.new)
    * @return       :   Void
    * @throws       :   None
    */    
    public static void restrictUserCreatedOnInsert(List<Contact> conLst){
        System.debug('New Contact List Insert : ' + conLst);
        Profile dataAnalystProf = [Select Id, Name 
                                       FROM Profile 
                                       WHERE Name = 'Cross Sell Data Analyst' Limit 1];
        String advisorRecType = [SELECT DeveloperName,Name 
                                 FROM RecordType 
                                 WHERE developername='Distributor' and SobjectType  = 'Contact'].get(0).id;
        if(UserInfo.getProfileId() == dataAnalystProf.Id){                                     
            for(Contact newCon : conLst){
                if(newCon.recordTypeId == advisorRecType){
                    newCon.addError(System.Label.CSP_ADVISOR_PARTYID_NOMATCH_ERROR + ' (' + newCon.External_ID__c.substringAfter('DSS') + ');');
                }
            }                   
        }
    }
    
}