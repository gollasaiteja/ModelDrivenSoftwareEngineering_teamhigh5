/**
   @Author  : Saumil Bapat, Chris Southworth
   @name  : CCT_CaseCreateService
   @CreateDate : 07/19/2016
   @Description : This class is a webservice for creating cases.
   @Version : 1.0
  */
@RestResource(urlMapping='/IVRCaseCreateService/*')
global with sharing class CCT_CaseCreateService1 {
    //STRING LITERAL
    public static final String LBL_ENROLLED_LIT = 'lbl_Enrolled';
    public static final String THIS_CLASS = 'CCT_CaseCreateService'; 

    global class CCT_CaseCreateServiceInput {
        public String authenticationStatus;
        public String authenticationStatusMessage;
        public String bu;
        public String callerIntent;
        public String callerIntentSemanticTag;
        public String callerName;
        public String callerUniqueID;
        public String callSource;
        public String customerType;
        public String enrollErrors;
        public String enrollmentStatus;
        public String enrollmentStatusMessage;
        public String language;
        public String tokenIdentifier;
        public String tokenType;
        public String ani;
        public String eduID;
        public String callerRole;
        public String systemId;
        public String dnis;
    }

    global class CCT_CaseCreateServiceOutput {
        public Boolean isSuccess;
        public String CaseNumber;
        public String errorMessage;
    }

    public static CCT_CaseCreateServiceOutput outputResults;

    /**
    * @description  Webservice method to create a new case/interaction/case interaction for a new call.  For a failed enrollment
    *                   an existing case is queried for and cloned.  If no case is found, a new case is created.
    * @param        CCT_CaseCreateServiceInput
    * @return       CCT_CaseCreateServiceOutput
    * @throws       Error and returns failure from the service
    */
    @HttpPost
    global static CCT_CaseCreateServiceOutput createCase(CCT_CaseCreateServiceInput InputParams) {
        
        RestRequest req = RestContext.request;
        String jSONParser = req.requestBody.toString(); 
        CCT_CaseCreateServiceInput InputParams = (CCT_CaseCreateServiceInput)JSON.Deserialize(jSONParser, CCT_CaseCreateServiceInput.class);
        System.debug('InputParams======'+InputParams); 
        logWebserviceRequest(InputParams);

        String caseNumber = '';

        try{

            Map<String, Apex_Strings__c> apexStrings = Apex_Strings__c.getAll();
            String ENROLLMENT_STATUS_FAILURE = apexStrings.get('lbl_TransferedCall').value__c;
            String NEW_CALL = apexStrings.get('lbl_newcall').value__c;

            if(InputParams == NULL){
                return createOutputResults(false, '', Label.Case_Webservice_Error_No_Input_Params);
            } else {

                if(String.IsNotBlank(InputParams.callSource)
                        && !InputParams.callSource.equalsIgnoreCase(NEW_CALL)
                        && !InputParams.callSource.equalsIgnoreCase(ENROLLMENT_STATUS_FAILURE)
                        ){
                    return createOutputResults(false, '', Label.Case_Webservice_Error_Invalid_Call_Source);
                }

                if( (String.isBlank(InputParams.callSource)
                        || (String.isNotBlank(InputParams.callSource) && InputParams.callSource.equalsIgnoreCase(NEW_CALL)))
                        && (String.isBlank(InputParams.dnis)
                        || String.isBlank(InputParams.ani)
                        || String.isBlank(InputParams.language)
                        || String.isBlank(InputParams.bu)
                )
                        ){
                    return createOutputResults(false, '', Label.Case_Webservice_Error_Missing_NewCall_Params);
                } else if(
                        String.isNotBlank(InputParams.callSource)
                                && InputParams.callSource.equalsIgnoreCase(ENROLLMENT_STATUS_FAILURE)
                                && (String.isBlank(InputParams.dnis)
                                || String.isBlank(InputParams.ani)
                                || String.isBlank(InputParams.language)
                                || String.isBlank(InputParams.callerUniqueID)
                                || String.isBlank(InputParams.enrollmentStatus)
                        )
                        ){
                    return createOutputResults(false, '', Label.Case_Webservice_Missing_Transfer_Params);
                }
            }


            String callSource = InputParams.callSource;
            String enrollmentStatus = InputParams.enrollmentStatus;
            String callerUniqueID = InputParams.callerUniqueID;

            String businessUnit;
            if(InputParams.bu.equalsIgnoreCase('GB')){
                businessUnit = InputParams.bu + ' - '+InputParams.callerIntent;
            }else{
                businessUnit = getBusinessUnitFromMapping(InputParams.bu, apexStrings.get('lbl_IVR_Business_Unit').value__c);
            }

            System.debug('***Business Unit: ' + businessUnit);

            Interaction__c currentInteraction = NULL;
            Case currentCase = NULL;
            Contact currentContact = NULL;
            Asset currentAsset = NULL;
            Account planAccount = NULL;
            Id divAccount = NULL;
            List<String> gbDetails;

            Boolean enrollmentFailedCaseFound = false;
            Boolean caseCloned = false;
            Case caseToCloneFrom = NULL;

            if(callSource != NULL
                    && callSource.equalsIgnoreCase(ENROLLMENT_STATUS_FAILURE)
                    ){

                //Query for Existing Interaction using EDUID
                currentInteraction = queryForInteraction(InputParams.eduID);

                //If Interaction is found
                if(currentInteraction != NULL){

                    //Update Enrollment Status and Enrollment Failure Message on Interaction (enrollmentStatus, enrollErrors)
                    currentInteraction.Enrollment_Status__c = InputParams.enrollmentStatus;
                    currentInteraction.Enrollment_Failure_Msg__c = InputParams.enrollmentStatusMessage;
                    update currentInteraction;

                    //Query for the latest case associated with the interaction (Order by Creation Date)
                    Case queryCase = queryForCase(currentInteraction.Id);

                    //Existing Case found
                    if(queryCase != NULL){

                        //create clone of the case
                        currentCase = cloneExistingCase(queryCase);

                        if(outputResults != NULL){
                            return outputResults;
                        }

                        caseToCloneFrom = queryCase;

                        if(currentCase != NULL){
                            caseCloned = true;
                        }

                        //If case is found set enrollmentFailedCaseFound = true;
                        enrollmentFailedCaseFound = true;

                    }

                }

            }

            //New Call or Failed Enrollment with no case found
            if(callSource == NULL
                    || callSource.equalsIgnoreCase(NEW_CALL)
                    || enrollmentFailedCaseFound == false
                    ){

                Boolean voicePrintFound = false;
                //Look for Contact using Voice Print (callerUniqueID)

                if(InputParams.bu.equalsIgnoreCase('GB')){
                    String tokenIdentifierString = InputParams.tokenIdentifier;
                    System.Debug('--++-- tokenIdentifierString: ' + tokenIdentifierString);
                    gbDetails = identifyGBDetails(tokenIdentifierString);

                    //Plan and certificate provided
                    if(gbDetails.size() > 1){
                        currentAsset = CCT_GBUtility.findAssetBy(gbDetails.get(0)+'_'+gbDetails.get(1));
                        System.Debug('--++-- currentAsset: ' + currentAsset);
                    }
                }

                if(!String.isBlank(InputParams.callerUniqueID)){
                    System.debug('***Searching for contact by callerUniqueID');
                    currentContact = queryForContact(callerUniqueID,InputParams.customerType);

                    if(currentContact != NULL){
                        voicePrintFound = true;
                    }

                    System.debug('****Contact: ' + currentContact);

                }

                if(voicePrintFound && currentContact != NULL){
                    Boolean contactAuthenticated = false;

                    //Check if contact is authenticated at IVR (authenticationStatus)
                    if(!String.isBlank(InputParams.authenticationStatus)
                            && InputParams.authenticationStatus.equalsIgnoreCase(apexStrings.get('lbl_Enrollment_Status_success').value__c)
                            ){

                        //Is Contact Enrollment Status == Transferred?
                        if(currentContact.Enrollment_Status__c == apexStrings.get('lbl_Transferred').value__c){
                            //Set Contact Enrollment Status = Enrolled;
                            currentContact.Enrollment_Status__c = apexStrings.get(LBL_ENROLLED_LIT).value__c;

                        } else {

                            //Is Contact Enrollment Status != Transferred?
                            if(currentContact.Enrollment_Status__c != apexStrings.get(LBL_ENROLLED_LIT).value__c){
                                currentContact.Enrollment_Status__c = apexStrings.get(LBL_ENROLLED_LIT).value__c;
                                currentContact.Enrollment_Status_Date__c = System.Today();
                            }

                        }

                        update currentContact;
                    }

                } else {
                    System.debug('***No Contact found');
                    //Search for contact using ANI

                    if(currentContact == NULL){
                        System.debug('****Searching for Contact by ANI');
                        currentContact = searchForContact(InputParams.ani);
                    }

                }

                //Create New Interaction Record if one doesn't exist
                currentInteraction = createNewInteraction(currentInteraction);
                currentInteraction.Token_Type__c = InputParams.tokenType;
                currentInteraction.Token_Identifier__c = InputParams.tokenIdentifier;
                currentInteraction.Business_Unit__c = businessUnit;
                currentInteraction.Contact_Language__c = InputParams.language;
                currentInteraction.Direction__c = apexStrings.get('lbl_Inbound').value__c;
                currentInteraction.Origin__c = apexStrings.get('lbl_Phone').value__c;
                currentInteraction.Start_Time__c = System.now();
                //currentInteraction.DNIS__c
                currentInteraction.ANI__c = InputParams.ani;
                //currentInteraction.Queue__c
                //currentInteraction.UCID__c
                currentInteraction.UUI__c = InputParams.eduID;
                currentInteraction.EDUID__c = InputParams.eduID;
                currentInteraction.Unique_Id__c = InputParams.callerUniqueID;
                currentInteraction.DNIS__c = InputParams.dnis;

                if(InputParams.bu != 'GB'){
                    currentInteraction.Caller_Intent_Semantic_Tag__c = InputParams.callerIntentSemanticTag;
                }else if(InputParams.bu == 'GB'){
                    currentInteraction.Caller_Intent_Semantic_Tag__c = (InputParams.callerIntentSemanticTag == '') ? InputParams.callerIntent : InputParams.callerIntentSemanticTag;
                }

                currentInteraction.Authentication_Status__c = InputParams.authenticationStatus;
                currentInteraction.Authentication_Status_Msg__c = InputParams.authenticationStatusMessage;
                currentInteraction.Caller_Type__c = InputParams.customerType;
                currentInteraction.Contact_Name__c = InputParams.callerName;
                currentInteraction.IVR_Caller_Role__c = InputParams.callerRole;
                insert currentInteraction;

                //Create New Case record
                currentCase = createNewCase(apexStrings, businessUnit, InputParams.language);

                //Link Case and Interaction using Case.Current_Interaction__c
                currentCase.Current_Interaction__c = currentInteraction.Id;

                //Link Contact to Case using Case.ContactId = contact, if found
                //If Contact Found Update Enrollment Status and Date on Case from Contact:
                //For Non GB Business Unit
                if(currentContact != NULL && !InputParams.bu.equalsIgnoreCase('GB')){
                    currentCase.ContactId = currentContact.Id;
                    List<Source_System_Identifier__c> cifNumber;

                    //Enrollment Status
                    currentCase.Contact_Enrollment_Status__c = apexStrings.get(LBL_ENROLLED_LIT).value__c;

                    //Enrollment Date
                    if(currentContact.Enrollment_Status__c != apexStrings.get('lbl_Transferred').value__c
                            && currentContact.Enrollment_Status__c != apexStrings.get(LBL_ENROLLED_LIT).value__c
                            ){
                        currentCase.Enrollment_Status_Date__c = System.Today();
                    }

                }else if(InputParams.bu.equalsIgnoreCase('GB')){      //For GB Business Unit

                    System.Debug('--++-- CurrentAsset: ' + currentAsset);
                    if(currentAsset != null){
                        divAccount                      = currentAsset.GB_Division__c;
                    }

                    if(gbDetails.size() > 0){
                        planAccount     = CCT_GBUtility.findPlanAccount(gbDetails.get(0));
                        if(planAccount != null){
                            currentCase.Plan_Account__c     = planAccount.Id;
                        }
                    }

                    if(InputParams.customerType.equalsIgnoreCase('Plan Member')){
                        if(currentAsset != null){
                            currentCase.AssetId             = currentAsset.Id;
                            currentCase.Division_Account__c = divAccount;
                            currentCase.ContactId = CCT_GBUtility.findPlanMember(currentAsset);
                            /*
                            if (CCT_GBUtility.checkValidRelationshipForPlanMember(currentContact, currentAsset)){
                                System.Debug('--++-- Found relationship for Plan Member');
                                currentCase.ContactId = currentContact.Id;
                            }
                            */
                        }
                    }else if(InputParams.customerType.equalsIgnoreCase('Dental Provider') ||
                            InputParams.customerType.equalsIgnoreCase('Health Provider')){
                        currentCase.Contact_Type__c = InputParams.customerType;
                        if(currentAsset != null){
                            currentCase.AssetId             = currentAsset.Id;
                            currentCase.Division_Account__c = divAccount;
                            /*
                            currentCase.ContactId = CCT_GBUtility.findPlanMember(currentAsset);
                            if (CCT_GBUtility.checkValidRelationshipForPlanMember(currentContact, currentAsset)){
                                System.Debug('--++-- Found relationship for Plan Member');
                                currentCase.ContactId = currentContact.Id;
                            }
                            */
                        }
                    }else {
                        currentCase.Contact_Type__c = InputParams.customerType;
                        /*
                        currentCase.Division_Account__c = divAccount;
                        if (CCT_GBUtility.checkValidRelationshipForPlanAdmin(currentContact, planAccount, divAccount)){
                            System.Debug('--++-- Found relationship for Plan Admin');
                            currentCase.ContactId = currentContact.Id;
                        }
                        */
                    }

                    if(currentCase.ContactId != null && !InputParams.bu.equalsIgnoreCase('GB')){
                        //Enrollment Status
                        currentCase.Contact_Enrollment_Status__c = apexStrings.get(LBL_ENROLLED_LIT).value__c;

                        //Enrollment Date
                        if(currentContact.Enrollment_Status__c != apexStrings.get('lbl_Transferred').value__c
                                && currentContact.Enrollment_Status__c != apexStrings.get(LBL_ENROLLED_LIT).value__c
                                ){
                            currentCase.Enrollment_Status_Date__c = System.Today();
                        }
                    }

                } else { //When no contact found
                    System.debug('****Checking CallerRole/Type');
                    System.debug('***Role: ' + InputParams.callerRole);
                    System.debug('***Type: ' + InputParams.customerType);

                    if(InputParams.bu.equalsIgnoreCase('GB')){
                        currentCase.Contact_Type__c = InputParams.customerType;
                    }else{
                        String searchValue = '';

                        if(String.isNotBlank(InputParams.callerRole)){
                            searchValue = InputParams.callerRole;
                        } else {
                            searchValue = InputParams.customerType;
                        }

                        //Caller Role compared to case caller role
                        if(String.isNotBlank(searchValue)){
                            System.debug('***Searching by Role');
                            //Set ContactType from mapping object (caller role)
                            List<Mapping__c> mappingList = [
                                    SELECT
                                            Case_Contact_Type__c,
                                            IVR_Contact_Type__c
                                    FROM Mapping__c
                                    WHERE IVR_Contact_Type__c = :searchValue
                                    LIMIT 1
                            ];

                            if(!mappingList.isEmpty()){
                                currentCase.Contact_Type__c = mappingList[0].Case_Contact_Type__c;
                            }
                        }
                    }
                }

                //Update Asset and Selling Code on Case (Token Type, Token Identifier) - Applicable only for Non-GB
                if( !InputParams.bu.equalsIgnoreCase('GB') &&
                        String.isNotBlank(currentInteraction.Token_Type__c)
                        && String.isNotBlank(currentInteraction.Token_Identifier__c)
                        ){
                    currentCase = updateAssetOrSellingCode(
                            currentCase,
                            currentInteraction,
                            apexStrings.get('lbl_Account_Number').value__c,
                            apexStrings.get('lbl_Advisor_Code').value__c,
                            apexStrings.get('lbl_Dealer_Rep_Code').value__c,
                            InputParams.systemId
                    );

                    if(outputResults != NULL){
                        return outputResults;
                    }
                }

            }
            System.Debug('--++-- SD: enrollmentFailedCaseFound: ' + enrollmentFailedCaseFound);
            System.Debug('--++-- SD: callSource: ' + callSource);
            /*Start CCT-1623*/
            if(InputParams.authenticationStatus != null && InputParams.authenticationStatus != '') {
                if(currentCase.ContactId == null && currentCase.Contact_Type__c != null && currentCase.Contact_Type__c.equalsIgnoreCase('Advisor')
                        && InputParams.authenticationStatus.equalsIgnoreCase(apexStrings.get('lbl_Enrollment_Status_success').value__c)){
                    List<ContractContactRelationship__c> contractContactList = null;
                    if(String.isNotBlank(currentCase.AssetId)){
                        List<Asset> assetList = [SELECT id,Selling_Code__c FROM Asset WHERE Id =:currentCase.AssetId];
                        if(!assetList.isEmpty()){
                            contractContactList = [select id, Contactid__c, Contract__c, Type__c
                            from ContractContactRelationship__c
                            where Contract__c in
                            (select Contract__c
                            from Selling_Code__c
                            where id =:assetList.get(0).Selling_Code__c)];
                        }
                    }else If(String.isNotBlank(currentCase.Selling_Code__c)){
                        contractContactList = [select id, Contactid__c, Contract__c, Type__c
                        from ContractContactRelationship__c
                        where Contract__c in
                        (select Contract__c
                        from Selling_Code__c
                        where id =:currentCase.Selling_Code__c)];
                    }
                    if(contractContactList != null && !contractContactList.isEmpty() && contractContactList.size() == 1){
                        currentCase.ContactId = contractContactList.get(0).Contactid__c;
                    }
                }
            }
            /*End CCT-1623*/
            if(enrollmentFailedCaseFound
                    || callSource == ENROLLMENT_STATUS_FAILURE
                    ){
                //Update Case Type = Voice Enrollment
                //Case SubType = Voice Enrollment Failure
                currentCase.Type__c = currentCase.Business_Unit__c + ' ' + apexStrings.get('lbl_Voice_Enrollment').value__c;
                currentCase.Case_Subtype__c =  apexStrings.get('lbl_Voice_Enrollment_Failure').value__c ;

                //Update Case Authentication Option and Status to Manual
                currentCase.Authentication_Option__c = apexStrings.get('lbl_Manually_Authenticated').value__c;
                currentCase.Authentication_Status_Case__c = apexStrings.get('lbl_Authenticated').value__c;
            }

            if(  currentInteraction.Authentication_Status__c.equalsIgnoreCase('Success') ||
                    currentInteraction.Authentication_Status__c.equalsIgnoreCase('PIN Verified')
                    ){
                currentCase.Authentication_Status_Case__c = apexStrings.get('lbl_Authenticated').value__c;
            }

            if(InputParams.bu.equalsIgnoreCase('GB')){
                currentInteraction.Authentication_Status__c = 'Failure';
                currentCase.Authentication_Status_Case__c = 'Authentication Needed';
            }

            if(currentAsset != null && InputParams.bu.equalsIgnoreCase('GB')){
                currentCase.IsClientPopup__c = true;
            }
            //insert/update case records
            upsert currentCase;

            //Query for Case Number
            caseNumber = [
                    SELECT
                            Id,
                            CaseNumber
                    FROM Case
                    WHERE Id = :currentCase.Id
                    LIMIT 1
            ].CaseNumber;

            //Create Case Interaction record
            //  Link to Case and Interaction Records
            Case_Interaction__c currentCaseInteraction = new Case_Interaction__c(
                    Interaction__c = currentInteraction.Id,
                    Case__c = currentCase.Id
            );
            insert currentCaseInteraction;

            //If case was cloned, call future methods to create emails and case interactions records
            if(caseCloned){
                CCT_NewCaseCloneController.createRelatedEmailMessages(caseToCloneFrom.Id, currentCase.Id);
                CCT_NewCaseCloneController.createEmailCaseInteractionRecords(caseToCloneFrom.Id, currentCase.Id, currentCaseInteraction.Id);
            }

            System.debug('***CaseRecord: ' + currentCase);

            //Create Recording Record
            //  Recording moved to CasePop
         } catch (DMLException e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'createCase', null, LoggingLevel.ERROR);

            return createOutputResults(false, '', e.getMessage());
      
         } catch (QueryException e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'createCase', null, LoggingLevel.ERROR);

            return createOutputResults(false, '', e.getMessage());        
        } catch (Exception e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'createCase', null, LoggingLevel.ERROR);

            return createOutputResults(false, '', e.getMessage());

        }

        //return new CCT_CaseCreateServiceOutput for success
        return createOutputResults(true, caseNumber, '');

    }

    /**
    * @description  Creates an List of String by Splitting the input string with delimiter
    * @param        String tokenIdentifierString
    * @return       List<String>
    * @throws       none
    */
    public static List<String> identifyGBDetails(String tokenIdentifierString){
        List<String> gbDetails = new List<String>();
        System.Debug('--++-- tokenIdentifierString: ' + tokenIdentifierString);
        gbDetails = tokenIdentifierString.split('-');
        System.Debug('--++-- gbDetails size: ' + gbDetails.size());
        return gbDetails;
    }

    /**
    * @description  Creates an output response from the webservice based on the provided parameters
    * @param        Boolean success, String numberString, String errorString
    * @return       CCT_CaseCreateServiceOutput
    * @throws       none
    */
    public static CCT_CaseCreateServiceOutput createOutputResults(Boolean success, String numberString, String errorString){
        CCT_CaseCreateServiceOutput results = new CCT_CaseCreateServiceOutput();
        results.isSuccess = success;
        results.CaseNumber = numberString;
        results.errorMessage = errorString;

        return results;
    }

    /**
    * @description  Updates the Asset or Selling Code on a Case and returns the updated Case
    * @param        Case inCase, Interaction__c interaction, String accountNumber, String advisorCode, String dealerRepCode
    * @return       Case
    * @throws       If an issue occurs it returns a failure response
    */
    public static Case updateAssetOrSellingCode(Case inCase, Interaction__c interaction, String accountNumber, String advisorCode, String dealerRepCode, String systemId){
        Case caseRecord = inCase;
        try{
            //Update Asset
            if(interaction.Token_Type__c.equalsIgnoreCase(accountNumber)){
                List<Asset> assetList = new List<Asset>();
                Map<String, System_Id_Mapping__c> systemMapping = System_Id_Mapping__c.getAll();
                if(String.isNotBlank(systemId)
                        && systemMapping != NULL
                        && systemMapping.containsKey(systemId)
                        ){

                    String mappedSystem = systemMapping.get(systemId).System_Id__c;

                    assetList = [
                            SELECT
                                    Id
                            FROM Asset
                            WHERE Name = :interaction.Token_Identifier__c
                            AND System_Of_Record__c = :mappedSystem
                            LIMIT 2
                    ];
                } else {
                    assetList = [
                            SELECT
                                    Id
                            FROM Asset
                            WHERE Name = :interaction.Token_Identifier__c
                            LIMIT 2
                    ];
                }
                if(!assetList.isEmpty() && assetList.size() == 1){
                    caseRecord.AssetId = assetList[0].Id;
                }
            } else if(interaction.Token_Type__c.equalsIgnoreCase(advisorCode)){

                List<Selling_Code__c> sellingCodeList = [
                        SELECT
                                Id
                        FROM Selling_Code__c
                        WHERE Name = :interaction.Token_Identifier__c
                        LIMIT 2
                ];

                if(!sellingCodeList.isEmpty() && sellingCodeList.size() == 1){
                    caseRecord.Selling_Code__c = sellingCodeList[0].Id;
                }

            } else if(interaction.Token_Type__c.equalsIgnoreCase(dealerRepCode)
                    && String.isNotBlank(interaction.Token_Identifier__c)
                    ){
                String tokenIdentifier = interaction.Token_Identifier__c;
                String processedTokenIdentifier = tokenIdentifier.substring(0,4) + '-' + tokenIdentifier.substring(4);

                List<Selling_Code__c> sellingCodeList = [
                        SELECT
                                Id
                        FROM Selling_Code__c
                        WHERE Name = :processedTokenIdentifier
                        LIMIT 2
                ];

                if(!sellingCodeList.isEmpty() && sellingCodeList.size() == 1){
                    caseRecord.Selling_Code__c = sellingCodeList[0].Id;
                }
            }
        } catch(QueryException e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'updateAssetOrSellingCode', null, LoggingLevel.ERROR);
            outputResults = createOutputResults(false, '', e.getMessage());
        } catch(Exception e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'updateAssetOrSellingCode', null, LoggingLevel.ERROR);
            outputResults = createOutputResults(false, '', e.getMessage());
        }

        return caseRecord;

    }


    /**
    * @description  Creates a case
    * @param        Map<String, Apex_Strings__c> strings, String businessUnit, String language
    * @return       Case
    * @throws       none
    */
    public static Case createNewCase(Map<String, Apex_Strings__c> strings, String businessUnit, String language){

        Case newCase = new Case(
                Status = strings.get('lbl_Case_Status_Active').value__c,
                RecordTypeId = System.Label.Record_Type_1_ID,
                is_Avaya_Created__c = true,
                Origin = strings.get('lbl_Phone').value__c,
                Case_Origin__c = strings.get('lbl_Phone').value__c,
                Business_Unit__c = businessUnit,
                Language__c = language
        );

        return newCase;
    }


    /**
    * @description  Returns the Business Unit based on the buString and mappingType
    * @param        String buString, String mappingType
    * @return       String, or Null if nothing found
    * @throws       none
    */
    public static String getBusinessUnitFromMapping(String buString, String mappingType){

        if(String.isNotBlank(buString)){
            List<Mapping__c> mappingList = [
                    SELECT
                            Id,
                            CCT_Business_Unit__c
                    FROM Mapping__c
                    WHERE IVR_Business_Unit__c = :buString
                    AND Type__c = :mappingType
                    LIMIT 1
            ];

            System.debug('****Business Unit results: ' + mappingList);
            if(!mappingList.isEmpty()
                    && String.isNotBlank(mappingList[0].CCT_Business_Unit__c)
                    ){
                return mappingList[0].CCT_Business_Unit__c;
            }
        }
        return '';
    }


    /**
    * @description  Query for Interaction__c based on EDUID
    * @param        String eduId
    * @return       Interaction__c, NULL if no Interaction__c is found
    * @throws       none
    */
    public static Interaction__c queryForInteraction(String eduId){
        List<Interaction__c> existingInteractions = [
                SELECT
                        Id
                //OtherFields
                FROM Interaction__c
                WHERE EDUID__c = :eduId
                LIMIT 1
        ];

        if(!existingInteractions.isEmpty()){
            return existingInteractions[0];
        }

        return NULL;
    }

    /**
    * @description  Queries for a case based on the Interaction__c.Id
    * @param        String interactionId
    * @return       Case, NULL if no Case is found
    * @throws       none
    */
    public static Case queryForCase(String interactionId){
        List<Case> existingCases = [
                SELECT
                        Id
                //OtherFields
                FROM Case
                WHERE Current_Interaction__c = :interactionId
                Order By CreatedDate DESC
                LIMIT 1
        ];

        if(!existingCases.isEmpty()){
            return existingCases[0];
        }

        return NULL;
    }

    /**
    * @description  Creates an Interaction record if one has not been created already
    * @param        Interaction__c currentRecord
    * @return       Interaction__c
    * @throws       none
    */
    public static Interaction__c createNewInteraction(Interaction__c currentRecord){
        if(currentRecord == NULL){
            Interaction__c newInteraction = new Interaction__c();
            return newInteraction;

        }

        return currentRecord;
    }


    /**
    * @description  Calls the clone code from CCT_NewCaseCloneController to create a clone of a case
    * @param        Case existingCase
    * @return       Case, NULL if no Case is created
    * @throws       Error for issue creating the cloned case
    */
    public static Case cloneExistingCase(Case existingCase){

        Case cloned = NULL;

        try{

            CCT_NewCaseCloneController.isCloneExecuting = true;

            cloned = CCT_NewCaseCloneController.cloneCase(existingCase.Id);
            insert cloned;

            CCT_NewCaseCloneController.isCloneExecuting = false;
         } catch (DMLException e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'cloneExistingCase', null, LoggingLevel.ERROR);
            outputResults = createOutputResults(false, '', e.getMessage());

        } catch (Exception e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'cloneExistingCase', null, LoggingLevel.ERROR);
            outputResults = createOutputResults(false, '', e.getMessage());
        }

        return cloned;

    }


    /**
    * @description  Query for Contact using callerUniqueID
    * @param        String callerUniqueID
    * @return       Contact, NULL if no contact found
    * @throws       none
    */
    public static Contact queryForContact(String callerUniqueID, String customerType){

        if(String.isNotBlank(customerType) && 'CUSTOMER'.equalsIgnoreCase(customerType)){
            if(String.isNotBlank(callerUniqueID)){
                List<Contact> contactList = [
                        SELECT
                                Id,
                                Enrollment_Status__c,
                                Enrollment_Status_Date__c,
                                Contact_Type__c
                        FROM Contact
                        WHERE IVR_Voice_Print_ID__c = :callerUniqueID
                        AND ID in (Select Contact__c from AssetContactRoles__c)
                        LIMIT 1
                        //LIMIT 2
                ];

                if(!contactList.isEmpty() && contactList.size() == 1){
                    return contactList[0];
                }
            }
        }else{
            if(String.isNotBlank(callerUniqueID)){
                List<Contact> contactList = [
                        SELECT
                                Id,
                                Enrollment_Status__c,
                                Enrollment_Status_Date__c,
                                Contact_Type__c
                        FROM Contact
                        WHERE IVR_Voice_Print_ID__c = :callerUniqueID
                        LIMIT 2
                ];

                if(!contactList.isEmpty() && contactList.size() == 1){
                    return contactList[0];
                }
            }
        }
        return NULL;
    }


    /**
    * @description  Searches for a contact using the ANI
    * @param        String ani
    * @return       Contact, NULL if no contact found
    * @throws       none
    */
    public static Contact searchForContact(String ani){

        if(String.isNotBlank(ani)){
            System.debug('***Contact SOSL Search');
            List<List<SObject>> results = [
                    FIND
                            :ani
                    IN PHONE FIELDS
                            RETURNING Contact (id, Contact_Type__c, Enrollment_Status__c, Enrollment_Status_Date__c)
            ];

            System.debug('***SOSL Results: ' + results);
            if(!results.isEmpty() && results.size() > 0){
                List<Contact> contactList = (List<Contact>)results[0];
                if(contactList.size() == 1){
                    return contactList[0];
                }
            }
        }

        return NULL;
    }

    /**
    * @description  Log the request in the Integration_Log__c object
    * @param        CCT_CaseCreateServiceInput inputs
    * @return       void
    * @throws       Error to logging framework
    */
    public static void logWebserviceRequest(CCT_CaseCreateServiceInput inputs){
        try{
            Integration_Log__c log = new Integration_Log__c(
                    Transaction_Id__c = inputs.eduId + '-' +String.valueOf(System.now()),
                    Input_Parameters__c = String.valueOf(inputs)
            );

            insert log;
        } catch(DMLException e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'logWebserviceRequest', null, LoggingLevel.ERROR);
        } catch(Exception e){
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, THIS_CLASS,
                    'logWebserviceRequest', null, LoggingLevel.ERROR);
        }
    }

}
