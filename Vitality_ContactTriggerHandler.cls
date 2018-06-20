/**********************************************************************
Name:      Vitality_ContactTriggerHandler
Purpose:   This handler class is responsible for all trigger event                                                       
**********************************************************************/
public class Vitality_ContactTriggerHandler {
    
    public static void stopUpdatingEmailForCastIron(List<Contact> conList, Map<id,Contact> oldContact) {
        Profile castIronProf = [Select Id, Name From Profile where Name = 'Integration - Cast Iron' Limit 1];
        For(Contact con : conList) {
            //If the request is coming from Cast Iron Profile and Email Sync is not Sync Failed
            if((UserInfo.getProfileId() == castIronProf.Id) && (con.Email_Sync_Status__c != 'Sync Failed')){
                //If the contact's old email address is not null and changed, then only replace the new email value with the old value,
                //Thus blocking the update from Cast Iron.
                if(oldContact.get(con.Id).Email != null && con.Email != oldContact.get(con.Id).Email){
                    con.Email = oldContact.get(con.Id).Email;
                }
            }
        }
    }
    
    public static void updateDOB(List<Contact> conList) {
        for(Contact con: conList) {
            if(con.Birthdate__c != null) {
                try {
                    String dob = con.Birthdate__c;
                    List<String> contactBirthdate = dob.split('/');
                    String newDob = Math.abs(Integer.valueOf(contactBirthdate[0]))+'/'+Math.abs(Integer.valueOf(contactBirthdate[1]))+'/'+contactBirthdate[2];
                    String inputEncryption = newDob + userinfo.getOrganizationId();
                    Blob b = Crypto.generateDigest('SHA-256', Blob.valueOf(inputEncryption));
                    con.Vitality_DOB__c = EncodingUtil.base64Encode(b);
                }
                Catch(Exception ex) {
                    con.Birthdate__c.Adderror(Label.Vitality_Enter_DateOfBirth);
                }
            }
        }
    }
    
    public static void onBeforeInsert(List<Contact> conList) {
        updateDOB(conList);
    }
    
    public static void onBeforeUpdate(List<Contact> conList, Map<Id, Contact> oldContact) {
        updateDOB(conList);
        stopUpdatingEmailForCastIron(conList, oldContact);
    }
    
    public static void onAfterUpdate(List<Contact> conList, Map<Id, Contact> oldContact) {
        //stopUpdatingEmailForCastIron(conList, oldContact);
        /***Start JIRA SSSS-9 ****/
        //updatePortalUserEmailOnChange(conList, oldContact);
        /***End JIRA SSSS-9 ****/
        try {
            //TODO: Below call is for updating C360 with SF changes.
            //ContactTriggerHandler.findContactsWithEmailUpdate(conList,oldContact);
            //Set<Id> setOfProfileId = new Set<Id>(); // not needed
            //if(conList.get(0).Email != oldContact.get(conList[0].Id).Email) {
            if(conList.size() == 1) {

                Contact newC = conList.get(0);
                Contact oldC = oldContact.get(newC.Id);
                if(newC.Email != oldC.Email) {

                    // ++CHANGE FOR CP2: If a CP2 User is trying to update their email, allow it. Don't proceed to update ISAM twice.
                    Map<Id,Profile> profilesMap = new Map<Id,Profile>([Select Id, Name FROM Profile WHERE Name =: CP2_Constants.TEXT_CP2_PORTAL_USER_PROFILE_NAME]);
                    if(profilesMap.containsKey(UserInfo.getProfileId()))
                    {
                        updatePortalUserEmailOnChange(conList, oldContact);
                        return;
                    }
                    // --CHANGE FOR CP2
                    
                    if(newC.VitalityMembershipCount__c > 0) {
                        //system.debug('VitalityMembershipCount__c ->'+newC.VitalityMembershipCount__c);
                        //system.debug('***Inside if block line 60**** ContactTriggerHandler');
                        List<Membership__c> memberRec = [select Id, member__r.Email From Membership__c where member__c = :newC.Id];
                        //List<User> usrList = [select email from user where email =: oldContact.get(conList.get(0).Id).Email];
                        // needs more deterministic criteria
                        List<User> usrList = [select id, email from user where ContactId = :newC.Id];
                        //system.debug('***Inside onAfterUpdate()**** ContactTriggerHandler -> usrList'+usrList.size());
                        String[] allowedProfiles = Vitality_ContactTriggerAllowedProfiles__c.getInstance('Default').ProfileNames__c.split(',');
                        Map<Id, Profile> listOfProfile = new Map<Id, Profile>([Select Id, Name From Profile where Name IN :allowedProfiles]);

                        // ++CHANGE FOR CP2: fetch profiles to allow legacy users to update email (aka portal username)
                        List<String> cp2Profiles = CP2_Profiles__c.getInstance('Default').ProfileNames__c.split(',');
                        Map<Id, Profile> cp2AllowedProfiles = new Map<Id, Profile>([Select Id, Name From Profile where Name in :cp2Profiles]);
                        // --CHANGE FOR CP2
                        if (!listOfProfile.isEmpty()) {
                            //For(Profile pro:listOfProfile) {
                            //    setOfProfileId.add(pro.Id);
                            //}
                            if (memberRec.size() > 0 && usrList.size() > 0) {
                                //if(setOfProfileId.contains(UserInfo.getProfileId())) {
                                if (listOfProfile.containsKey(UserInfo.getProfileId())) {
                                    //system.debug('***Inside onAfterUpdate() line 71**** ContactTriggerHandler'); 
                                    Vitality_ChangeISAMUsername.changeISAMEmail(oldC.Email, newC.Email, newC.Id);
                                    //if(!response.equalsIgnoreCase('success')) { // this will never be reached since the method above is @future
                                    //    conList.get(0).Email.AddError(Label.Vitality_PortalAccount_AlreadyExist );
                                    //}
                                }
                                // ++CHANGE FOR CP2: Update email on USER without calling ISAM
                                else if(cp2AllowedProfiles.containsKey(UserInfo.getProfileId())){
                                    updatePortalUserEmailOnChange(conList, oldContact);
                                }
                                // --CHANGE FOR CP2:
                                else {
                                    conList.get(0).Email.AddError(Label.Vitality_Update_VitalityUserEmail_NotAllowed);
                                }
                            }
                        }

                    }
                    else{
                        //system.debug('***Inside else block line 60**** ContactTriggerHandler -> updatePortalUserEmailOnChange');
                        // ++CHANGE FOR CP2: Allow non vitality CP1 users to change the email on user
                        updatePortalUserEmailOnChange(conList, oldContact);
                        // --CHANGE FOR CP2
                    }


                }
            }
        }catch(Exception ex) {
            conList.get(0).AddError(ex.getMessage());
        }
    }
    
    public static void updatePortalUserEmailOnChange(List<Contact> conList, Map<Id, Contact> oldContact) {
        Map<Id, String> oldEmailId = new Map<Id, String>();
        Map<Id, String> newEmailId = new Map<Id, String>();
        List<String> emailList = new List<String>();
        List<User> updatedPortalUser = new List<User>();
        for(Contact con:conList) {
            if(con.Email != oldContact.get(con.Id).Email) {
                newEmailId.put(con.Id, con.Email);
                oldEmailId.put(con.Id, oldContact.get(con.Id).Email);
            }
        }
        if(newEmailId.size() > 0) {
            For(Id key:oldEmailId.keySet()) {
                emailList.add(oldEmailId.get(key));
            }

            List<String> cp2Profiles = CP2_Profiles__c.getInstance('Default').ProfileNames__c.split(',');
            List<User> portalUserList =     [Select id, email, Profile.Name, ContactId 
                                            FROM User
                                            WHERE email In:(emailList) AND (Profile.Name = 'Customer Community Login User' OR Profile.Name IN :cp2Profiles)]; // // ++CHANGE FOR CP2: also allow profiles from cp2Profiles
            if(!portalUserList.isEmpty() && portalUserList.size() > 0) {
                for(User portalUser:portalUserList) {
                    if(oldEmailId.keySet().contains(portalUser.ContactId)) {
                        portalUser.Email = newEmailId.get(portalUser.ContactId);
                        //portalUser.Username = newEmailId.get(portalUser.ContactId);
                        updatedPortalUser.add(portalUser);
                    }
                }
                if(Test.isRunningTest()){
                    system.runAs(new User(Id=userinfo.getUserId())){
                        update updatedPortalUser;
                    }
                }else {
                    
                    
                    update updatedPortalUser;
                    
                }
            }
        }
    }
}