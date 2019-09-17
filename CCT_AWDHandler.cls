public with sharing class CCT_AWDHandler {

    private static final String BEARER = 'Bearer ';
    private static final String AUTH = 'Authorization';
    private static final String UPDATESTRING = 'update';        
    private static final String CANCELSTRING = 'cancel';
    //LITERALS
    private static final string  QUEUEDTOAWD = 'Queued to AWD';
    private static final String AWD_ACCESS_TOKEN = 'AWD Access Token';
    private static final String TWO_HUNDRED = '200';
    private static final String TRANSACTION_I_ID = 'transactionInstanceId';
    private static final String SOURCE_I_ID = 'sourceInstanceId';
    //LITERALS
   

    static Map<String,Secret_Setting__c> settingsMap = new Map<String,Secret_Setting__c>();
    
    @InvocableMethod(label='sendTaskToAWD' description='Sends task to AWD')
    public static void sendTaskToAWD (Request[] requests) {
        
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                             from Secret_Setting__c where Project__c='CCT' and Name in (:AWD_ACCESS_TOKEN)]){
            
            settingsMap.put(setting.Name,setting);
        }
        
        Secret_Setting__c accessTokenSetting = settingsMap.get(AWD_ACCESS_TOKEN);
        
        If(String.isBlank(accessTokenSetting.Alternate_Token_Value__c) 
                || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime()) >(accessTokenSetting.Token_Validity_Limit__c*60*1000)){
            system.debug('insider i ');
            getAccessToken();
        }
        
        for(request req : requests){
            System.debug('PARAM VALUE ::: '+req.recordId);
            System.debug('Request Type ::: '+req.requestType);
            if (req.requestType =='Create' )
                callAWDServiceTask(req.recordId);
            else if ( req.requestType =='Update')
                callUpdateAWDServiceTask(req.recordId,UPDATESTRING);
        }
       
    }
    
    public class Request {
        @InvocableVariable(label='Record ID' required=true)
        public Id recordId;
        
        @InvocableVariable(label='RequestType' required=true)
        public string requestType;
        
    }
    
/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: sendAccessTokenRequest                            *
*   @Return: HttpResponse                                    *
*   @Description: method to send request for access token    *
 ************************************************************/     
    private static HttpResponse sendAccessTokenRequest(Map<String,Secret_Setting__c> settingsMap){
    
        System.debug('TOKEN IS CALLED *******');
        Http http = new Http();
        HttpRequest request = new HttpRequest();  
        request.setEndpoint(Label.lbl_CCT_AWD_GetToken);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        String requestBody = '{"client_id": "'+settingsMap.get('AWD Client Id').Encrypted_Value__c+'","client_secret": "'+settingsMap.get('AWD Client Secret').Encrypted_Value__c+'","grant_type": "client_credentials"}';
        request.setBody(requestBody);            
        HttpResponse response = http.send(request);
        return response;
    }

/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: updateTokenSetting                                *
*   @Return: null                                            *
*   @Description: method to update access token in           *
*                       custom setting                       *
 ************************************************************/      
    private static void updateTokenSetting(HttpResponse response,Secret_Setting__c accessTokenSetting){
        JSONParser parser = JSON.createParser(response.getBody());
        while (parser != null) {                
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'access_token')) {                       
                parser.nextToken();
                System.debug('--++--access_token:'+parser.getText());                        
                accessTokenSetting.Alternate_Token_Value__c=parser.getText();
                update accessTokenSetting;
                break;
            }
            parser.nextToken();
        }     
    }

/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAccessToken                                    *
*   @Return: null                                            *
*   @Description: method to get access token                 *
 ************************************************************/        
    @future(Callout=true)
    public static void getAccessToken(){
        
        for(Secret_Setting__c setting: [select Id,Name,Token_Validity_Limit__c,Encrypted_Value__c,Alternate_Token_Value__c,LastModifiedDate 
                                                from Secret_Setting__c where Project__c='CCT' 
                                                            and Name in ('AWD Client Id','AWD Client Secret',:AWD_ACCESS_TOKEN)]){
            settingsMap.put(setting.Name,setting);
        }
        HttpResponse response;
        Secret_Setting__c accessTokenSetting=settingsMap.get(AWD_ACCESS_TOKEN);
        //Considering 60 minutes of token validity
        if((String.isBlank(accessTokenSetting.Alternate_Token_Value__c)) 
                    || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime())>= (accessTokenSetting.Token_Validity_Limit__c*60*1000)){
                        
            response = sendAccessTokenRequest(settingsMap);
            if (response.getStatusCode() != 200) {
                System.debug('The status code returned was not expected Create Token: ' +
                              response.getStatusCode() + ' ' + response.getStatus());
                return;
            }
            else if(response.getStatusCode() == 200) {
                system.debug('Status CODE SUCCESS'+response.getStatusCode());
                updateTokenSetting(response,accessTokenSetting);
            }
            
        }
    }

 
/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAWDTaskMapping                                 *
*   @Return: List<AWD_Mapping__c>                      *
*   @Description: method to get AWD task Mapping             *
 ************************************************************/      
    private static List<AWD_Mapping__c> getAWDTaskMapping(Task singleTask ,string taskPriority){
        
       
        system.debug('Task_Type__c = '+singleTask.Task_Type__c);
        system.debug('Priority__c '+taskPriority);
        system.debug('Staff_Plan__c = '+singleTask.Related_Case__r.Staff_Plan__c);
        system.debug('OTIP__c '+singleTask.Related_Case__r.Asset.Is_OTIP__c);
        system.debug('Language__c '+singleTask.Related_Case__r.language__C);
        system.debug('Area_Being_Sent_To__c = '+singleTask.Area_Being_Sent_To__c);
        system.debug('System of record = '+singleTask.Related_Case__r.Asset.System_of_Record__c == null?'': singleTask.Related_Case__r.Asset.System_of_Record__c);
        system.debug('Canada_Only__c= '+singleTask.Related_Case__r.Canada_Only__c);
        system.debug('Business_Unit__c = '+singleTask.Related_Case__r.Business_Unit__c);
        system.debug('Case_Type__c= '+singleTask.Related_Case__r.Type__c);


        //System of record is only applicable for GB Plan Member Admin type business Unit
        if(singleTask.Area_Being_Sent_To__c.equalsIgnoreCase('GB Plan Member Admin')){
                System.debug(singleTask.description + 'Mapping in GB Plan Member Admin');

            return([select Group__c,Unit__c,Work_Type__c,Status__c from AWD_Mapping__c 
            
                       where 
                       Area_Being_Sent_To__c =: singleTask.Area_Being_Sent_To__c
                       AND 
                       Task_Type__c =: singleTask.Task_Type__c AND 
                       Priority__c =: taskPriority AND 
                       //Staff_Plan__c =: singleTask.Related_Case__r.Staff_Plan__c AND 
                      // OTIP__c =: singleTask.Related_Case__r.Asset.Is_OTIP__c AND 
                       Language__c =: singleTask.Related_Case__r.language__C AND
                       //AND 
                       System_of_Record__c =: (singleTask.Related_Case__r.Asset.System_of_Record__c == null?'': singleTask.Related_Case__r.Asset.System_of_Record__c) AND 
                       Canada_Only__c =: singleTask.Related_Case__r.Canada_Only__c 
                       //AND 
                       //Business_Unit__c =: singleTask.Related_Case__r.Business_Unit__c AND
                       //Case_Type__c =: singleTask.Related_Case__r.Type__c
                        limit 1]);

        } else if(singleTask.Area_Being_Sent_To__c.equalsIgnoreCase('GB Claims')) {
            System.debug(singleTask.description + 'Mapping in GB Claims');
            return([select Group__c,Unit__c,Work_Type__c,Status__c from AWD_Mapping__c where 
                        Area_Being_Sent_To__c =: singleTask.Area_Being_Sent_To__c
                       AND 
                       Task_Type__c =: singleTask.Task_Type__c AND 
                       //Priority__c =: taskPriority AND 
                       Staff_Plan__c =: singleTask.Related_Case__r.Staff_Plan__c AND 
                       OTIP__c =: singleTask.Related_Case__r.Asset.Is_OTIP__c AND 
                       Language__c =: singleTask.Related_Case__r.language__C AND 
                       //System_of_Record__c =: (singleTask.Related_Case__r.Asset.System_of_Record__c == null?'': singleTask.Related_Case__r.Asset.System_of_Record__c) AND 
                       Canada_Only__c =: singleTask.Related_Case__r.Canada_Only__c AND 
                       Business_Unit__c =: singleTask.Related_Case__r.Business_Unit__c AND
                       Case_Type__c =: singleTask.Related_Case__r.Type__c
                        limit 1]);

        } else if(singleTask.Area_Being_Sent_To__c.equalsIgnoreCase('GB Admin Advantage')){

            System.debug(singleTask.description + 'Mapping in Admin Advantage');
            return([select Group__c,Unit__c,Work_Type__c,Status__c from AWD_Mapping__c where 
                        Area_Being_Sent_To__c =: singleTask.Area_Being_Sent_To__c
                       AND 
                       Task_Type__c =: singleTask.Task_Type__c AND 
                       Priority__c =: taskPriority AND 
                       Staff_Plan__c =: singleTask.Related_Case__r.Staff_Plan__c AND 
                       //OTIP__c =: singleTask.Related_Case__r.Asset.Is_OTIP__c AND 
                       Language__c =: singleTask.Related_Case__r.language__C 
                        //AND 
                       //System_of_Record__c =: (singleTask.Related_Case__r.Asset.System_of_Record__c == null?'': singleTask.Related_Case__r.Asset.System_of_Record__c) AND 
                       //Canada_Only__c =: singleTask.Related_Case__r.Canada_Only__c 
                       //AND 
                       //Business_Unit__c =: singleTask.Related_Case__r.Business_Unit__c AND
                       //Case_Type__c =: singleTask.Related_Case__r.Type__c
                        limit 1]);
        }
        system.debug (singleTask.description + ' nothing is found line 209 ');
        return new List<AWD_Mapping__c>();

        
    }
    
    
 /*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: createIntegrationLog                              *
*   @Return: null                                            *
*   @Description: method to create integration log           *
 ************************************************************/      
    private static void createIntegrationLog(Task singleTask){
        String paramVal = ' Task_Type__c = '+singleTask.Task_Type__c + ' Priority__c '+singleTask.Priority+ ' Staff_Plan__c = '+singleTask.Related_Case__r.Staff_Plan__c+' OTIP__c '+singleTask.Related_Case__r.Asset.Is_OTIP__c;
        paramVal = paramVal + ' Language__c '+singleTask.Related_Case__r.language__c + ' Area_Being_Sent_To__c = '+singleTask.Area_Being_Sent_To__c + ' System of record = '+singleTask.Related_Case__r.Asset.System_of_Record__c;
        paramVal = paramVal + ' Canada_Only__c= '+singleTask.Related_Case__r.Canada_Only__c+' Business_Unit__c = '+singleTask.Contact_Center_BU__c+ ' Case_Type__c= '+singleTask.Related_Case__r.Type__c;
        Integration_Log__c integrationLog = new Integration_Log__c(Input_Parameters__c = paramVal,Transaction_Id__c = singleTask.id);
        insert integrationLog;
    }
 
/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: updateTaskMappingError                            *
*   @Return: null                                            *
*   @Description: method to update task in case of error     *
 ************************************************************/      
    private static void updateTaskMappingError(Id taskId , string CallType){
        Task updatetsk = new Task(Id = taskId ,Mapping_Issue__c = true , AWD_Error__c= CallType );
        update updatetsk;
    }

/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAWDUserMapping                                 *
*   @Return: List<AWD_User_Mapping__c>                       *
*   @Description: method to get AWD User Mapping data        *
 ************************************************************/      
    private static List<AWD_User_Mapping__c> getAWDUserMapping(Task singleTask){
        return([select User_Name__c from AWD_User_Mapping__c where Plan_Number__c =: singleTask.Related_Case__r.plan_number__c]);
    }

/*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAWDTaskPriority                                *
*   @Return: List<AWD_Task_Priority__c>                      *
*   @Description: method to get AWD Task Priority data       *
 ************************************************************/      
    private static List<AWD_Task_Priority__c> getAWDTaskPriority(Task singleTask){
        return([select AWD_Task_Priority__c from AWD_Task_Priority__c where Name =: singleTask.Priority]);
    }
                 
    @future(Callout=true)
    public static void callAWDServiceTask(Id taskId)
    {
        createAWDService(taskId);
    }

    public static void createAWDService(Id taskId)
    {  
        Task singleTask = CCT_AWDUtility.getTask(taskId);
        //add
        system.debug ('-----------+++++++++++----------- task is ' + singleTask);
        //add
        System.debug('TASK PRIORITY :: '+singleTask.Priority);
        string taskPriority = '';
        if(!singleTask.Priority.equalsIgnoreCase('None')){
            taskPriority = singleTask.Priority;
        }
        System.debug('After Prority '+ taskPriority);

        List<AWD_Mapping__c> objMappingDataList = getAWDTaskMapping(singleTask , taskPriority);
        if(objMappingDataList.isEmpty()){
            System.debug('++ Mapping not Found --- 1');
            //CCT_AWDUtility.updateTaskMappingError(singleTask.id , 'DataMapError');
            if(System.isBatch()){
                System.debug('ERROR HAPPENS FROM BATCH FOR CREATE DATAMAP###################################'); 
                CCT_AWDUtility.updateTasKExceptionFromBatch(singleTask,'DataMapError');
                } else {
                    CCT_AWDUtility.updateTaskMappingError(singleTask.id,'DataMapError');
                }
            createIntegrationLog(singleTask);
            return;
        }
        AWD_Mapping__c objMappingData = objMappingDataList[0];
        
        List<AWD_User_Mapping__c> userMappingObj = getAWDUserMapping(singleTask);
        List<AWD_Task_Priority__c> taskPriorityObj = getAWDTaskPriority(singleTask);
        //Map<String,Secret_Setting__c> settingsMap1 = new Map<String,Secret_Setting__c>();
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Alternate_Token_Value__c,LastModifiedDate 
                                                    from Secret_Setting__c where Project__c='CCT' 
                                                                    and Name in ('AWD_ldappassword','AWD_ldapuserid',
                                                                                    'AWD_Password','AWD_ExternalID',
                                                                                    :AWD_ACCESS_TOKEN,'AWD_UserID')]){
            settingsMap.put(setting.Name,setting);
            System.debug('System Name ::'+setting.Name +' Setting '+setting);
        }
        
        //System.debug('Setting map callAWDServiceTask'+settingsMap1);
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setEndpoint(Label.lbl_CCT_AWD_CreateInstance);
       // request.setEndpoint('https://cac.mesh.preprod.api.manulife.com/v1/groupbenefitscct/shared/workflow/awdservices/ca/uat/api/createInstances');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/xml'); 
        request.setHeader('userid', settingsMap.get('AWD_UserID').Encrypted_Value__c);
        request.setHeader('ldappassword', settingsMap.get('AWD_ldappassword').Encrypted_Value__c);
        request.setHeader('ldapuserid', settingsMap.get('AWD_ldapuserid').Encrypted_Value__c);          
        request.setHeader('pwd', settingsMap.get('AWD_Password').Encrypted_Value__c); 
        request.setHeader(AUTH, BEARER + settingsMap.get(AWD_ACCESS_TOKEN).Alternate_Token_Value__c);      
        String jsonBodyParam = null;
        String updateType = '';
        system.debug ('----------line 320 ----------' + String.IsBLANK(singleTask.Task_Attachments__c) + ' task is ' + singleTask.Description);
        if(String.IsBLANK(singleTask.Task_Attachments__c)) {
            System.debug('Without Attachment ::');
            jsonBodyParam = createJsonwithoutAttachment(singleTask,settingsMap,objMappingData,userMappingObj,taskPriorityObj);
            updateType = 'Create';
        }else {
            System.debug('With Attachment ::');
            jsonBodyParam = createJsonwithAttachment(singleTask,settingsMap,objMappingData ,userMappingObj,taskPriorityObj);
            updateType = 'Create With Attachment';
        }
        request.setBody(jsonBodyParam); 
        
        System.debug('Request ------>'+request);
        System.debug('Request Type -->'+updateType);
        HttpResponse response = http.send(request);
        Map<String,String> jsonParseResult = new Map<String,String>();
        if(String.valueof(response.getStatusCode()) == TWO_HUNDRED) {
            String jsonbody = response.getBody();
            jsonParseResult = parseJson(jsonbody);
            if(jsonParseResult.size() > 0) {
                if(!Test.isRunningTest())
                { 
                    if(System.isBatch()){
                        System.debug('Create into AWD Side FROM BATCH ###################################'); 
                        
                        System.debug('Transaction ID :: '+jsonParseResult);
                        //singleTask.External_ID__c = jsonParseResult.get('transactionInstanceId');
                        //singleTask.status = 'Active';
                        CCT_AWDUtility.updateTasKSuccessFromBatch(singleTask,updateType,jsonParseResult.get(TRANSACTION_I_ID));
                        System.debug('sourceInstanceId ## '+ jsonParseResult.get(SOURCE_I_ID));                    
                        //update singleTask;
                    } else {
                        //CCT_AWDUtility.updateTaskSucess(taskId,updateType);
                        System.debug('Transaction ID :: '+jsonParseResult);
                        singleTask.External_ID__c = jsonParseResult.get(TRANSACTION_I_ID);
                        singleTask.status = 'Active';
                        System.debug('sourceInstanceId ## '+ jsonParseResult.get(SOURCE_I_ID));                    
                        update singleTask;
                    }
                
                
                  
                
                }
            }             
        }else if(String.valueof(response.getStatusCode()) != TWO_HUNDRED) {
            System.debug('The status code returned was not expected: ' +response.getStatusCode() + ' ' + response.getStatus() + ' GETBODY '+response.getBody());
             // UTIL_LoggingService.logHandledException(null, UserInfo.getOrganizationId(), String.valueof(response.getStatusCode()), 'CCT_AWDHandler','callAWDServiceTask', null, LoggingLevel.DEBUG);
                if(String.valueof(response.getStatusCode()) == '401'){
                    //getAccessToken();
                // UTIL_LoggingService.logHandledException(null, UserInfo.getOrganizationId(), String.valueof(response.getStatusCode()), 'CCT_AWDHandler','callAWDServiceTask', null, LoggingLevel.DEBUG);
                }
                if(!Test.isRunningTest()){
                   if(System.isBatch()){
                            System.debug('ERROR HAPPENS FROM BATCH FOR CREATE ###################################'); 
                            CCT_AWDUtility.updateTasKExceptionFromBatch(singleTask,updateType);
                        } else {
                             CCT_AWDUtility.updateTaskMappingError(singleTask.id,updateType);
                        }
                }
            }
    }
    
    private static MAP<String,String> parseJson(String jsonResponse){
        system.debug('JSOn respose :: '+jsonResponse);
        // Parse JSON response to get all the totalPrice field values.
        JSONParser parser = JSON.createParser(jsonResponse);
        Map<String,String> parserMap = new Map<String,String>();
        while (parser.nextToken() != null) {
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == TRANSACTION_I_ID)) {
                // Get the value.
                parser.nextToken();              
                parserMap.put(TRANSACTION_I_ID, parser.getText());
            }
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == SOURCE_I_ID)) {
                // Get the value.
                parser.nextToken(); 
                System.debug('sourceInstanceId :: '+parser.getText());              
                parserMap.put(SOURCE_I_ID, parser.getText());
            }
        }
        return parserMap;
        
    }
    private static String createJsonwithoutAttachment(Task task,Map<String,Secret_Setting__c> settingsMap1, 
                                                      AWD_Mapping__c objMappingData,
                                                      List<AWD_User_Mapping__c> userMappingObj,
                                                      List<AWD_Task_Priority__c> taskPriorityObj){
      System.debug('Mapping Data :: '+objMappingData);
      String jsonStructure = '';
      Task singleTask = task;
      CCT_AWDCreateJSONWithoutAttachment objcls = new CCT_AWDCreateJSONWithoutAttachment();
      CCT_AWDCreateJSONWithoutAttachment.lobField lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      List<CCT_AWDCreateJSONWithoutAttachment.lobField> lslobField = new List<CCT_AWDCreateJSONWithoutAttachment.lobField>();
      lobFieldObj.name = 'FNAM';
      lobFieldObj.value= singleTask.Related_Case__r.contact.firstname == null?'':singleTask.Related_Case__r.contact.firstname;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'LNAM';
      lobFieldObj.value= singleTask.Related_Case__r.contact.lastname == null?'':singleTask.Related_Case__r.contact.lastname;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'PPNU';
      lobFieldObj.value= singleTask.Related_Case__r.plan_number__c == null?'':singleTask.Related_Case__r.plan_number__c;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'CERT';
      lobFieldObj.value= singleTask.Related_Case__r.Certificate_Name__c == null?'':singleTask.Related_Case__r.Certificate_Name__c;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'DIVN';
      lobFieldObj.value= singleTask.Related_Case__r.Division_Number__c == null?'':singleTask.Related_Case__r.Division_Number__c;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'CPHN';
      lobFieldObj.value= String.ValueOf(singleTask.Contact_Phone_Number__c) == null?'':String.ValueOf(singleTask.Contact_Phone_Number__c);
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'SFID';
      lobFieldObj.value= singleTask.Id;
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      
      lobFieldObj.name = 'HPRT';
      lobFieldObj.value= !taskPriorityObj.isEmpty()?taskPriorityObj[0].AWD_Task_Priority__c:'';
      lslobField.add(lobFieldObj);
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'LOCN';
      lobFieldObj.value= '';
      lslobField.add(lobFieldObj);
      
      /*
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'NTFY';
      lobFieldObj.value= singleTask.NotifyCSP__c?'Y':'N';
      lslobField.add(lobFieldObj);
      
      */
      
      lobFieldObj = new CCT_AWDCreateJSONWithoutAttachment.lobField();
      lobFieldObj.name = 'LAGE';
      lobFieldObj.value= singleTask.Related_Case__r.Language__c=='English'?'E':singleTask.Related_Case__r.Language__c=='French'?'F':'';
      lslobField.add(lobFieldObj);     
      
      CCT_AWDCreateJSONWithoutAttachment.lobFields lobFieldsObj = new CCT_AWDCreateJSONWithoutAttachment.lobFields();
      lobFieldsObj.lobField = lslobField;        
      CCT_AWDCreateJSONWithoutAttachment.createTransaction createTransactionObj = new CCT_AWDCreateJSONWithoutAttachment.createTransaction();
      createTransactionObj.assignTo = !userMappingObj.isEmpty()?userMappingObj[0].User_Name__c:'';
      createTransactionObj.businessArea = objMappingData.Unit__c!=null?objMappingData.Unit__c:'';
      createTransactionObj.type = objMappingData.Work_Type__c!=null?objMappingData.Work_Type__c:'';
      createTransactionObj.status = objMappingData.Status__c!=null?objMappingData.Status__c:'';
      createTransactionObj.comment = singleTask.Description;
      createTransactionObj.queue = 'DOCREV';
      createTransactionObj.lobFields = lobFieldsObj;
      CCT_AWDCreateJSONWithoutAttachment.CreateInstancesRq CreateInstancesRqObj = new CCT_AWDCreateJSONWithoutAttachment.CreateInstancesRq();
      CreateInstancesRqObj.externalId = settingsMap1.get('AWD_ExternalID').Encrypted_Value__c;
      CreateInstancesRqObj.createTransaction = createTransactionObj;
      objcls.CreateInstancesRq = CreateInstancesRqObj;
      jsonStructure = JSON.serialize(objcls);
      system.debug('jsonStructure = '+jsonStructure);
      return jsonStructure;
      
  }
    /*
    private static void wait(Integer millisec) {
        
        if(millisec == null || millisec < 0) {
            millisec = 0;
        }
        
        Long startTime = DateTime.now().getTime();
        Long finishTime = DateTime.now().getTime();
        while ((finishTime - startTime) < millisec) {
            //sleep for parameter x millisecs
            finishTime = DateTime.now().getTime();
        }
        // System.debug('>>> Done from ' + startTime + ' to ' + finishTime);
    }*/
     private static String createJsonwithAttachment(Task task,Map<String,Secret_Setting__c> settingsMap1, AWD_Mapping__c objMappingData,List<AWD_User_Mapping__c> userMappingObj,
                                                   List<AWD_Task_Priority__c> taskPriorityObj){
                                                       
                                                       List<String> attachmentIDs = new List<String>();
                                                       if(task.Task_Attachments__c.contains(',')){
                                                           attachmentIDs = task.Task_Attachments__c.split(',');
                                                       }
                                                       else {
                                                           attachmentIDs.add(task.Task_Attachments__c);
                                                       }
                                                       
                                                       System.debug('Attachment ID :: '+attachmentIDs);
                                                       
                                                       
                                                       String jsonbody = null;
                                                       AWDDataTransfer objAWDDataTransfer = new AWDDataTransfer();
                                                       
                                                       
                                                       //Populating the LOB values
                                                       AWDDataTransfer.lobField objLobField = new AWDDataTransfer.lobField();
                                                       objLobField.name = 'FNAM';
                                                       objLobField.value =  task.Related_Case__r.contact.firstname == null  ?'' :  task.Related_Case__r.contact.firstname ;
                                                       
                                                       AWDDataTransfer.lobField objLobField2 = new AWDDataTransfer.lobField();
                                                       objLobField2.name = 'LNAM';
                                                       objLobField2.value =  task.Related_Case__r.contact.lastname == null  ?'' :  task.Related_Case__r.contact.lastname ;
                                                       
                                                       AWDDataTransfer.lobField objLobField3 = new AWDDataTransfer.lobField();
                                                       objLobField3.name = 'CPHN';
                                                       objLobField3.value = task.Contact_Phone_Number__c == null  ?'' : String.valueOf(task.Contact_Phone_Number__c) ;
                                                       
                                                       AWDDataTransfer.lobField objLobField4 = new AWDDataTransfer.lobField();
                                                       objLobField4.name = 'PPNU';
                                                       objLobField4.value =  task.Related_Case__r.plan_number__c == null  ?'' : task.Related_Case__r.plan_number__c;
                                                       
                                                       AWDDataTransfer.lobField objLobField5 = new AWDDataTransfer.lobField();
                                                       objLobField5.name = 'CERT';
                                                       objLobField5.value =  task.Related_Case__r.Certificate_Name__c == null  ?'' :  task.Related_Case__r.Certificate_Name__c;
                                                       
                                                       AWDDataTransfer.lobField objLobField6 = new AWDDataTransfer.lobField();
                                                       objLobField6.name = 'DIVN';
                                                       objLobField6.value = task.Related_Case__r.Division_Number__c == null  ?'' : task.Related_Case__r.Division_Number__c;
                                                       
                                                       AWDDataTransfer.lobField objLobField7 = new AWDDataTransfer.lobField();
                                                       objLobField7.name = 'SFID';
                                                       objLobField7.value = task.Id ;
                                                       
                                                       AWDDataTransfer.lobField objLobField8 = new AWDDataTransfer.lobField();
                                                       objLobField8.name = 'HPRT';   
                                                       objLobField8.value= !taskPriorityObj.isEmpty()?taskPriorityObj[0].AWD_Task_Priority__c:'';  
                                                       
                                                       AWDDataTransfer.lobField objLobField9 = new AWDDataTransfer.lobField();
                                                       objLobField9.name = 'LOCN';         
                                                       objLobField9.value = '';
                                                       AWDDataTransfer.lobField objLobField10 = new AWDDataTransfer.lobField();
                                                       objLobField10.name = 'NTFY';  
                                                       objLobField10.value=task.NotifyCSP__c?'Y':'N';          
                                                       
                                                       
                                                       AWDDataTransfer.lobField objLobField11 = new AWDDataTransfer.lobField();
                                                       objLobField11.name = 'LAGE';  
                                                       objLobField11.value=task.Related_Case__r.Language__c=='English'?'E':task.Related_Case__r.Language__c=='French'?'F':'';          
                                                       
                                                       
                                                       
                                                       AWDDataTransfer.lobFields objfileds = new AWDDataTransfer.lobFields();
                                                       
                                                       objfileds.lobField.add(objLobField);
                                                       objfileds.lobField.add(objLobField2);
                                                       objfileds.lobField.add(objLobField3);
                                                       objfileds.lobField.add(objLobField4);
                                                       objfileds.lobField.add(objLobField5);
                                                       objfileds.lobField.add(objLobField6);
                                                       objfileds.lobField.add(objLobField7);
                                                       objfileds.lobField.add(objLobField8);
                                                       objfileds.lobField.add(objLobField9);
                                                       objfileds.lobField.add(objLobField10);
                                                       objfileds.lobField.add(objLobField11);
                                                       
                                                       
                                                       
                                                       //Create Transaction Start
                                                       AWDDataTransfer.createTransaction objCreateTransaction = new AWDDataTransfer.createTransaction();
                                                       objCreateTransaction.type = objMappingData.Work_Type__c;
                                                        //Change to WorkType to DELREQ
                                                       //objCreateTransaction.type = 'DELREQ';
                                                      
                                                       objCreateTransaction.status = objMappingData.Status__c;
                                                       objCreateTransaction.businessArea = objMappingData.Unit__c;
                                                       //objCreateTransaction.businessArea = 'ILC';
                                                       objCreateTransaction.assignTo = !userMappingObj.isEmpty()?userMappingObj[0].User_Name__c:'';
                                                       objCreateTransaction.comment = task.Description== null ? '' : task.Description;
                                                       objCreateTransaction.queue = 'DOCREV';
                                                       objCreateTransaction.relationshipId = '1';
                                                       objCreateTransaction.lobFields = objfileds; 
                                                       
                                                       AWDDataTransfer.CreateInstancesRq objCreateInstancesRq = new AWDDataTransfer.CreateInstancesRq();
                                                       //Create Relationships Start
                                                       AWDDataTransfer.relationships objrelationships = new AWDDataTransfer.relationships();
                                                       
                                                       //END Relationships Start
                                                       AWDDataTransfer.attachment objAttachmant = null;
                                                       AWDDataTransfer.createSource objCreateSource = null;
                                                       AWDDataTransfer.relationship objRelationship = null;
                                                       integer counter = 2;                                                       
                                                       List<String> ContentDocumentIds = new List<String>();
                                                       for(ContentDocumentLink objContentDocumentLink :[select ContentDocumentId from ContentDocumentLink where id in: attachmentIDs]) {
                                                           ContentDocumentIds.add(objContentDocumentLink.ContentDocumentId);

                                                       }
                                                       
                                                      // for (Attachment attachmentObject : [select body,id,ContentType,Description,name FROM Attachment where id in: attachmentIDs]){
                                                         for(CCT_AWDUtility.AttachmanetProperty SingleContentDocumentLink : CCT_AWDUtility.getAttachmentsByIds(ContentDocumentIds)) 
                                                           {
                                                           AWDDataTransfer.lobField objLobField12 = new AWDDataTransfer.lobField();
                                                          
                                                          /*
                                                           String attachemntName = attachmentObject.name;
                                                           String[] SplitName = attachemntName.split('\\.');                                                           
                                                           objLobField12.name = 'EXT';                                                              
                                                           objLobField12.value = SplitName[SplitName.size()-1] ;

                                                           String extension = SplitName[SplitName.size()-1];

                                                           AWDDataTransfer.lobField objLobField13 = new AWDDataTransfer.lobField();
                                                           objLobField13.name = 'FLNM';            
                                                           objLobField13.value = + attachmentObject.Name  ;

                                                           */

                                                           objLobField12.name = 'EXT';                                                              
                                                           objLobField12.value = SingleContentDocumentLink.fileExtension;
                                                           String extension = SingleContentDocumentLink.fileExtension;
                                                           AWDDataTransfer.lobField objLobField13 = new AWDDataTransfer.lobField();
                                                           objLobField13.name = 'FLNM';            
                                                           objLobField13.value = SingleContentDocumentLink.fileName;
                                                           AWDDataTransfer.lobFields objfiledFOrCreateSOurce = new AWDDataTransfer.lobFields();
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField);
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField2);
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField4);
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField5);
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField12);
                                                           objfiledFOrCreateSOurce.lobField.add(objLobField13);
                                                           // objfiledFOrCreateSOurce.lobField.add(objLobField14);                                                           
                                                           //Create Attachment Start
                                                           objAttachmant = new AWDDataTransfer.attachment();
                                                           objAttachmant.contentType = String.isblank(SingleContentDocumentLink.fileType)?'text/plain': SingleContentDocumentLink.fileType;
                                                           
                                                           System.debug('Content Type  ::'+objAttachmant.contentType);
                                                          // objAttachmant.binaryData = String.valueof(SingleContentDocumentLink.contentInBase64Format);
                                                           objAttachmant.binaryData= EncodingUtil.base64Encode(SingleContentDocumentLink.contentInBase64Format);
                                                           
                                                           //Create Attachment End
                                                           
                                                           //Create Source Start
                                                           objCreateSource = new AWDDataTransfer.createSource();
                                                           //objCreateSource.businessArea = 'ILC';//objMappingData.Unit__c;
                                                           objCreateSource.businessArea = objMappingData.Unit__c;
                                                           objCreateSource.comment = task.Description== null ? '' :task.Description;
                                                           objCreateSource.securityLevel = '000';
                                                           objCreateSource.lobFields = objfiledFOrCreateSOurce;
                                                           if(extension.equalsIgnoreCase('TIFF') || extension.equalsIgnoreCase('TIF') || extension.equalsIgnoreCase('TXT')){
                                                                objCreateSource.type = 'MAIL';
                                                           }else {
                                                                objCreateSource.type = 'GDL';
                                                           }
                                                           //objMappingData.Work_Type__c;
                                                           //objCreateSource.type = objMappingData.Work_Type__c;
                                                           objCreateSource.attachment = objAttachmant;
                                                           objCreateSource.relationshipId = counter;
                                                           //Create Source End
                                                           objCreateInstancesRq.createSource.add(objCreateSource);
                                                           //Create Relationship Start
                                                           objRelationship = new AWDDataTransfer.relationship();
                                                           objRelationship.parentRelationshipId = '1';
                                                           objRelationship.childRelationshipId = counter;
                                                           //Create Relationship End
                                                           
                                                           objrelationships.relationship.add(objRelationship);
                                                           System.debug('INSIDE LOOP :: '+counter);
                                                           counter ++;
                                                           //End Relationships 
                                                       }
                                                       
                                                       //Create Transaction Start
                                                       objCreateInstancesRq.createTransaction = objCreateTransaction;
                                                       objCreateInstancesRq.relationships = objrelationships;
                                                       objCreateInstancesRq.externalId = settingsMap1.get('AWD_ExternalID').Encrypted_Value__c;
                                                       //Create Transaction End
                                                       objAWDDataTransfer.CreateInstancesRq = objCreateInstancesRq;
                                                       jsonbody = JSON.serialize(objAWDDataTransfer);
                                                       System.debug('JSOn BODY '+JSON.serialize(objAWDDataTransfer));
                                                       return jsonbody;
                                                   }
    
    
    /*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAWDTaskPriority                                *
*   @Return: void                                            *
*   @Description: Method to callAWD update service           *
 ************************************************************/   
    @future(Callout=true)
    public static void callUpdateAWDServiceTask(Id taskId,String updateType)
    {
        updateAWDServiceTask(taskId,updateType);
    } 

    public static void updateAWDServiceTask(Id taskId,String updateType)
    { 
        
        Task singleTask = CCT_AWDUtility.getTask(taskId);           
        Map<String,Secret_Setting__c> settingsMap1 = new Map<String,Secret_Setting__c>();
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Alternate_Token_Value__c,LastModifiedDate 
                                                    from Secret_Setting__c where Project__c='CCT' 
                                                                    and Name in ('AWD_ldappassword','AWD_ldapuserid',
                                                                                    'AWD_Password','AWD_ExternalID',
                                                                                    :AWD_ACCESS_TOKEN,'AWD_UserID')])
        {
            settingsMap1.put(setting.Name,setting);
            System.debug('System Name ::'+setting.Name +' Setting '+setting);
        }
        System.debug('TASK ID '+taskId);
        System.debug('Setting map callAWDServiceTask'+settingsMap1);
        Http http = new Http();
        HttpRequest request = new HttpRequest();       
        request.setEndpoint(label.lbl_CCT_AWD_UpdateInstance);     
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/xml'); 
        request.setHeader('userid', settingsMap1.get('AWD_UserID').Encrypted_Value__c);
        request.setHeader('ldappassword', settingsMap1.get('AWD_ldappassword').Encrypted_Value__c);
        request.setHeader('ldapuserid', settingsMap1.get('AWD_ldapuserid').Encrypted_Value__c);          
        request.setHeader('pwd', settingsMap1.get('AWD_Password').Encrypted_Value__c); 
        request.setHeader(AUTH, BEARER + settingsMap1.get(AWD_ACCESS_TOKEN).Alternate_Token_Value__c);        
        String jsonBodyParam = null;  
        CCT_AWDUpdateData objCCT_AWDUpdateData = new CCT_AWDUpdateData();
        CCT_AWDUpdateData.UpdateInstanceRq objUpdateInstanceRq = new CCT_AWDUpdateData.UpdateInstanceRq();
        CCT_AWDUpdateData.Transaction_Z  objTransaction = new CCT_AWDUpdateData.Transaction_Z();
        CCT_AWDUpdateData.LobFields objLobFields = new CCT_AWDUpdateData.LobFields();
        List<CCT_AWDUpdateData.LobField> objLobFieldLst =  new  List<CCT_AWDUpdateData.LobField>();
        //Adding LOB fields
        CCT_AWDUpdateData.LobField objLobField = new CCT_AWDUpdateData.LobField();
        objLobField.name = 'SFID';
        objLobField.value  = singleTask.Id;
        objLobFieldLst.add(objLobField);
        objLobFields.lobField = objLobFieldLst;
        // Adding LOB fields
        //Adding Transaction parameter
        objTransaction.instanceId = singleTask.External_ID__c;
        objTransaction.lobFields = objLobFields;
        //Condition added to remove status for 'Life Moment Task' records.
        if(singleTask.recordType.Name != 'Life Moment Task'){
            if(updateType.equalsIgnoreCase('update')){
                objTransaction.status = 'SFUNPEND';
            } else {
                objTransaction.status = 'END';
            }
        }
        else{
            objTransaction.status = '';
        }
        
        objTransaction.addManualComment = String.isnotBlank(singleTask.Description) ? singleTask.Description : '';

        //Adding Transaction Parameter
        //Adding update Insatance
        objUpdateInstanceRq.externalId = settingsMap1.get('AWD_ExternalID').Encrypted_Value__c;
        objUpdateInstanceRq.transaction_Z = objTransaction;
        //Adding update instance
        objCCT_AWDUpdateData.UpdateInstanceRq = objUpdateInstanceRq;
        jsonBodyParam = JSON.serialize(objCCT_AWDUpdateData);
        System.debug('Before Change '+ jsonBodyParam);
        jsonBodyParam = jsonBodyParam.replaceAll('"transaction_Z"','"transaction"');
        System.debug('After Change '+ jsonBodyParam);
       
       
        system.debug('Json structure is ' + jsonBodyParam);
        request.setBody(jsonBodyParam); 
        HttpResponse response = http.send(request);
        Map<String,String> jsonParseResult = new Map<String,String>();
        if(String.valueof(response.getStatusCode()) == TWO_HUNDRED) {
                       
            if(System.isBatch()){
                System.debug('Updated into AWD Side FROM BATCH ###################################'); 
                CCT_AWDUtility.updateTasKSuccessFromBatch(singleTask,updateType,'');
            } else {
                CCT_AWDUtility.updateTaskSucess(singleTask,updateType);
            }
            
            /* if(updateType.equalsIgnoreCase('cancel')){
                singleTask.status = 'Cancelled';
                update singleTask;
            }
             if(updateType.equalsIgnoreCase('update')){
                singleTask.description = singleTask.description+ '\r\n' + singleTask.AWD_Comment__c;
                singleTask.status = CCT_AWDUtility.SFUNPEND;
                update singleTask;
            }*/
        }             
        else if(String.valueof(response.getStatusCode()) != TWO_HUNDRED) {
            System.debug('The status code returned was not expected: ' +response.getStatusCode() + ' ' + response.getStatus() + ' GETBODY '+response.getBody());
            //UTIL_LoggingService.logHandledException(null, UserInfo.getOrganizationId(), String.valueof(response.getStatusCode()), 'CCT_AWDHandler','callAWDServiceTask', null, LoggingLevel.DEBUG);
            if(String.valueof(response.getStatusCode()) == '401'){
                //getAccessToken();
                //UTIL_LoggingService.logHandledException(null, UserInfo.getOrganizationId(), 'UNAUTHORIZED', 'CCT_AWDHandler','callAWDServiceTask', null, LoggingLevel.DEBUG);
            }
                if(!Test.isRunningTest()){
                        if(System.isBatch()){
                            System.debug('ERROR HAPPENS FROM BATCH ###################################'); 
                            CCT_AWDUtility.updateTasKExceptionFromBatch(singleTask,updateType);
                        } else {
                             //CCT_AWDUtility.updateTaskMappingError(singleTask.id,updateType);
                             singleTask.status = QUEUEDTOAWD;
                             update singleTask;
                        }
                                                  
                    }
            }
        
    }
    
    @AuraEnabled
    public static void cancelTaskToAWDLtng(Id recordId) {
        system.debug('___+___'+recordId);
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                        from Secret_Setting__c where Project__c='CCT' and Name in (:AWD_ACCESS_TOKEN)]){
                                            
                                            settingsMap.put(setting.Name,setting);
                                        }
        system.debug('settingsMap'+settingsMap);
        Secret_Setting__c accessTokenSetting = settingsMap.get(AWD_ACCESS_TOKEN);
        If(String.isBlank(accessTokenSetting.Alternate_Token_Value__c) 
           || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime()) >(accessTokenSetting.Token_Validity_Limit__c*60*1000)){
               system.debug('insider i ');
               getAccessToken();
           }
        callUpdateAWDServiceTask(recordId,CANCELSTRING);
    }
    
    @AuraEnabled
    public static void editTaskToAWDLtng(Id recordId) {
        /*List<Request> requests = new List<Request>();
        Request req = new Request();
        req.recordId = recordId;
        req.requestType = 'Update';
        requests.add(req);*/
        system.debug('___+___'+recordId);
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                        from Secret_Setting__c where Project__c='CCT' and Name in (:AWD_ACCESS_TOKEN)]){
                                            
                                            settingsMap.put(setting.Name,setting);
                                        }
        system.debug('settingsMap'+settingsMap);
        Secret_Setting__c accessTokenSetting = settingsMap.get(AWD_ACCESS_TOKEN);
        If(String.isBlank(accessTokenSetting.Alternate_Token_Value__c) 
           || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime()) >(accessTokenSetting.Token_Validity_Limit__c*60*1000)){
               system.debug('insider i ');
               getAccessToken();
           }
        callUpdateAWDServiceTask(recordId,UPDATESTRING);
    }
        
    @AuraEnabled
    public static List<Task> loadTasks(Id recordId){
            return [SELECT Task_Type__c,What.Name,ActivityDate,Priority,Area_Being_Sent_To__c,Contact_Center_BU__c,Contact_Phone_Number__c,Subject,Status,Description,Task_Attachments__c FROM Task WHERE Id=:recordId];
    }
    
    public static void callUpdateAttachment(Id RecordId){
         system.debug('___+___'+recordId);
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                        from Secret_Setting__c where Project__c='CCT' and Name in (:AWD_ACCESS_TOKEN)]){
                                            
                                            settingsMap.put(setting.Name,setting);
                                        }
        system.debug('settingsMap'+settingsMap);
        Secret_Setting__c accessTokenSetting = settingsMap.get(AWD_ACCESS_TOKEN);
        If(String.isBlank(accessTokenSetting.Alternate_Token_Value__c) 
           || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime()) >(accessTokenSetting.Token_Validity_Limit__c*60*1000)){
               system.debug('insider callUpdateAttachment calling GetToken service ');
               getAccessToken();
           }else {
               CCT_AWDAddAttachment.addMoreAttachment(RecordId);
           }
        
        
    }
    @AuraEnabled
    public static Task saveTask(string request){
        System.debug('Request Part----->'+request);
        CCT_AWDJsonData requestObj = CCT_AWDJsonData.parse(request);
        string taskId = requestObj.taskId;
        string awdComments = requestObj.awdComment;
        string attachmentIds = requestObj.attachmentIds;
        string alreadyAttachmentIds = requestObj.alreadyAttachment;
        if(string.isNotBlank(attachmentIds)){
                attachmentIds = attachmentIds.replaceAll(':', ',');//Replacing ':' delimeter by ','
                attachmentIds = attachmentIds.replaceFirst(',', '');
                system.debug('attachments . refined==='+attachmentIds);
         }
        Task task = new Task();
        task.id = Id.valueOf(taskId);
        task.Description  = awdComments;
        task.Additional_Task_Attachment__c = attachmentIds;
        if(String.isnotBlank(alreadyAttachmentIds) && String.isnotBlank(attachmentIds)){
            task.Task_Attachments__c = alreadyAttachmentIds+','+attachmentIds;
        } else if(String.isNotBlank(attachmentIds)){
             task.Task_Attachments__c = attachmentIds;
        }
        
        update task;
        editTaskToAWDLtng(task.id);
        if(String.isNotBlank(attachmentIds))
        {
            System.debug('Calling update attachment service');
            callUpdateAttachment(task.id);
        }
    

        return task;
    }
    
     @AuraEnabled
     public static String TaskOwner(String recordId){
         String  taskowner;
         Try{
             Task ownercheck = [select OwnerID, Contact_Phone_Number__c from Task where OwnerID=:UserInfo.getUserId() and ID=:recordId Limit 1];
             if(ownercheck!= null ){
                 system.debug('yyyyyyyyyy'+ownercheck);
                 taskowner = 'validuser';
             }else {
                 system.debug('iiiiiiiiiiii'+ownercheck);
                 taskowner = 'Invaliduser';
             }  
         } catch(Exception e){
             system.debug('XXXXXXXXXX'+e.getMessage()+' line number == '+e.getLineNumber()+'&&&&&&'+recordId);
             taskowner = 'Invaliduser';
         }   
         return taskowner;
     }
   @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
        List < String > allOpts = new list < String > ();
        // Get the object type of the SObject.
        Schema.sObjectType objType = objObject.getSObjectType();
        
        // Describe the SObject using its object type.
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        // Get a map of fields for the SObject
        map < String, Schema.SObjectField > fieldMap = objDescribe.fields.getMap();
        
        // Get the list of picklist values for this field.
        list < Schema.PicklistEntry > values =
            fieldMap.get(fld).getDescribe().getPickListValues();
        
        // Add these values to the selectoption list.
        for (Schema.PicklistEntry a: values) {
            allOpts.add(a.getValue());
        }
        system.debug('allOpts ---->' + allOpts);
        allOpts.sort();
        return allOpts;
    }
    
    
    //for attachment
    
    @AuraEnabled
    public static List<Attachment_Wrapper> getAttchment(string recordId){
        system.debug('recordId@' + recordId);
        List<Attachment_Wrapper> ContentDocumentLinkNames = new List<Attachment_Wrapper>();
        List<ContentDocumentLink> contentDocsList = null;
        List<String> alreadyPresent = new List<String>();
        Task tskRecord  = [select whatId,Contact_Phone_Number__c,Task_Attachments__c from Task where id =: recordId limit 1];
        System.debug('task Record'+tskRecord);
        String splited = tskRecord.Task_Attachments__c;
        if(String.isNotBlank(splited)){
            
            for(String singleId : splited.split(',')){
                alreadyPresent.add(singleId);            
            }
            System.debug('Already present ---->'+alreadyPresent);
        } 
            contentDocsList = [select contentDocument.title,Id, ContentDocumentId,contentDocument.FileExtension, LinkedEntityId from ContentDocumentLink where LinkedEntityId =: tskRecord.WhatId AND id NOT IN : alreadyPresent] ;
        
        System.debug('COntent Doc link '+contentDocsList);
        for(ContentDocumentLink cdl : contentDocsList){
            ContentDocumentLinkNames.add(new Attachment_Wrapper(false,cdl.contentDocument.title+'.'+cdl.contentDocument.FileExtension, cdl.Id));
        }
        system.debug('ContentDocumentLinkNames@' + ContentDocumentLinkNames);
        return ContentDocumentLinkNames;
    }
    
    Public Class Attachment_Wrapper implements cct_BindWrapperInterface{
        @AuraEnabled public boolean checked{get;set;}
        @AuraEnabled public string attchmentName{get;set;}
        @AuraEnabled public string attchmentId{get;set;}  
        Attachment_Wrapper(boolean checked,string attchmentName, string attchmentId){
            this.checked = checked;
            this.attchmentName = attchmentName;
            this.attchmentId = attchmentId;
        }
    }  
    
    
    
    
}