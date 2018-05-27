public with sharing class C360_Services_mergeContacts {

    public C360_Services_mergeContacts() {
        // just to silence the SonarQube warning
    }

    public C360_Success mergeContacts(List<C360.MergeContactsRequest> requests) { 
 
        C360_Dml dmlHelper; 
        
        //Start - Merge Contacts using Custom settings logic
        List<Merge_Contacts__mdt> contactMergeMDTLst = new List<Merge_Contacts__mdt>();
        contactMergeMDTLst = [Select MasterLabel, DeveloperName, Field_API_Name__c from Merge_Contacts__mdt Where DeveloperName = 'Contact_Fields'];
        system.debug('contactMergeMDTLst===='+contactMergeMDTLst);
        List<String> fieldAPINamesLst = new List<String>();
        fieldAPINamesLst = contactMergeMDTLst[0].Field_API_Name__c.split(',');
        //End - Merge Contacts using Custom settings logic

        // NOTE: the code below has DML inside loop which is generally a bad approch, but
        // we are makeing exception here because the first parameter in the merge request is a single record
        // so we have to merge pairs one at the time. Haydar Hadi Sept 2017

        for (C360.MergeContactsRequest request : requests) {

            if (2!=request.sources.size())
                throw new C360_Error.PermanentFailureException('The number of (sources) must be exactly two, but received sources of size:' + request.sources.size());

            C360_Helper.Required(request.sources[0].recordId, 'MergeContactsRequest.sources[0].recordId');
            C360_Helper.Required(request.sources[1].recordId, 'MergeContactsRequest.sources[1].recordId');

            String key0 = 'MDM' + request.sources[0].recordId;
            String key1 = 'MDM' + request.sources[1].recordId;

            List<String> twoKeys = new List<String> {key0, key1};

            if (key0 == key1) throw new C360_Error.PermanentFailureException('The two unique keys are identical: ' + twoKeys); // StatusCode.DUPLICATE_EXTERNAL_ID, 

            //C360-264 - check target inactivateDate
            if(request.target != null && request.target.inactivateDate != null) {
                throw new C360_Error.PermanentFailureException('The target contact has been deactivated');
            }

            List<Contact> contacts = [
                SELECT 
                    Id, External_Id__c,Email,Contact_Type__c,IVR_Voice_Print_ID__c,Gender__c,Line_of_Business__c 
                FROM    
                    Contact 
                WHERE External_Id__c in :twoKeys
                ORDER BY CreatedDate
            ];

            if (2!=contacts.size()) throw new C360_Error.TemporaryFailureException('Not all source key provided exist in Saleforce. Provided: ' + twoKeys);

            System.assertNotEquals(contacts[1].Id, contacts[0].Id, 'The two contact ids to be merged have identical id {' + contacts[0].Id + '} which is invalid. They came from the two keys:' + twoKeys); // TODO, change to contacts[1].Idn

            Map<Id, Id> userIdByContactId = new Map<Id, Id>();
            for (User u : [Select Id, ContactId From User Where ContactId in :contacts]) {
                userIdByContactId.put(u.ContactId, u.Id);
            } 
            Boolean isCommunity0 = userIdByContactId.containsKey(contacts[0].Id);
            Boolean isCommunity1 = userIdByContactId.containsKey(contacts[1].Id);

            dmlHelper =  new C360_Services_updateContacts().updateContacts(new List<C360.ContactInfoType>{request.target}); 

            Contact created = C360_Services_updateContacts.lastUpsertedContacts[0];

            Contact master = CustomClone(created);

            if (isCommunity0 && isCommunity1) 
            {
                throw new C360_Error.PermanentFailureException('Cant merge two communite contacts:' + twoKeys);
            } 
            else 
            {   // if contact 1 is community use it, otherwise use the first created contact (that is contact[0])
                // note that "masterId" is never "createdid". This way we make sure "created" is deleted after the merge.
                master.Id = 
                    isCommunity1 
                    ? contacts[1].Id 
                    : contacts[0].Id;
            }

            C360_Helper.deleteContactMDMChildren(
                new List<String> {
                    contacts[0].External_Id__c,
                    contacts[1].External_Id__c
                }
            );
            //Start - Custom merge logic
            System.debug('contacts[0]==========='+contacts[0]+'contacts[1]==============='+contacts[1]);
            for(string fieldAPIName : fieldAPINamesLst){
               // contacts[0].fieldAPIName = contacts[1].fieldAPIName;
                if(contacts[1].get(fieldAPIName) != null && String.IsBlank(String.valueOf(contacts[0].get(fieldAPIName)))){
                  contacts[0].put(fieldAPIName,contacts[1].get(fieldAPIName));
                    master.put(fieldAPIName,contacts[0].get(fieldAPIName));
                }
            }
            System.debug('contacts[0]===after ========'+contacts[0]+'contacts[1]==============='+contacts[1]);
            //End - Custom merge logic
            Set<Id> sources = new Set<Id> {
                contacts[0].Id, 
                contacts[1].Id,
                created.Id
            };
                system.debug('sources===>'+sources);
            sources.remove(master.Id);
system.debug('sources after===>'+sources+'contacts===after ========'+contacts+'master==='+master);
            merge master new List<Id>(sources);
            //merge contacts[0] contacts[1];
 system.debug('sources after merge===>'+sources+'contacts===after ========'+contacts);
            // TODO: if the merge target contact turned out to be different from the one created in updateContacts above (because isCommuity),
            //          then the target contact is not included in the response.


            if (request.targetRoles != null && !request.targetRoles.isEmpty() ) {
                new C360_Services_updateAssetContactRoles(dmlHelper).updateAssetContactRoles(request.targetRoles);
            }
            system.debug('sources before return  ===>'+sources+'contacts===after ========'+contacts);
        } 

        return dmlHelper;
    }

    private static Contact CustomClone(Contact origContact) {
        Map<String, object> values = origContact.getPopulatedFieldsAsMap();
        
        Contact newContact = new Contact();
        for (String fieldName : values.keySet()) {
            if (fieldName == 'Account') continue;
            newContact.put(fieldName, values.get(fieldName));
        }

        return newContact;
    }

}