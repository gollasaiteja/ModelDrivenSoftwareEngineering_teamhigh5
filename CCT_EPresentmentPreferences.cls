public class CCT_EPresentmentPreferences {
    //Final variables declaration
    private static final String EPRESENTMENT_ACCESS_TOKEN = 'ePresentment Access Token';
    private static final String BEARER = 'Bearer ';
    private static final String AUTH = 'Authorization';
    
    static Map<String,Secret_Setting__c> settingsMap = new Map<String,Secret_Setting__c>();
    public static Contact contactData = new Contact();
    public static HttpResponse frameworkResponse;
    public static String testResponse;
    
    @AuraEnabled
    public static string /*List<PatternsAndFrameworksResponse>*/ onInitMethod(Id cntctId){
        List<PatternsAndFrameworksResponse> responseData;
        String test;
        if(cntctId != null){
            contactData = [select Id, MDM_Enterprise_ID__c  from Contact WHERE Id =: cntctId limit 1];  
            apigeeCallout(contactData.MDM_Enterprise_ID__c);
            system.debug('contactData====='+contactData + 'settingsMap=='+settingsMap);
            system.debug('++++++++++'+[select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                       from Secret_Setting__c where Project__c='CCT' and Name in (:EPRESENTMENT_ACCESS_TOKEN)]);
            
            CCT_EPresentmentPreferences.patternsAndFrameWorks(contactData.MDM_Enterprise_ID__c);
            /*HTTPResponse frameworkResponse = CCT_EPresentmentPreferences.patternsAndFrameWorks(settingsMap.get(EPRESENTMENT_ACCESS_TOKEN).Alternate_Token_Value__c,contactData.MDM_Enterprise_ID__c);
List<PatternsAndFrameworksResponse> patternResClass = new List<PatternsAndFrameworksResponse>();
system.debug('frameworkResponse in aura======='+frameworkResponse);
String frameworkStr = '[{"preferenceType": "global","productName": "all","preferenceDelivery": "electronic","preferenceIsChangeAllowed": true,"patternId": "5d7a88b07401e0006812ee90"}, {"productName": "securities", "preferenceIsChangeAllowed": true,  "_id": "5d1658d4783ee100627c1aa9", "preferenceType": "confirmations", "preferenceDelivery": "paper" },	{ "productName": "investments", "preferenceIsChangeAllowed": false, "_id": "5d408b56ec76bd005db93a74", "preferenceType": "statements", "preferenceDelivery": "paper" }]';
responseData = (List<PatternsAndFrameworksResponse>) JSON.deserialize( String.valueOf(frameworkResponse), List<PatternsAndFrameworksResponse>.class);
system.debug('Framework responseData======='+responseData);
test = frameworkStr;*/
            
        }
        return String.valueOf(responseData); //test; //responseData;
        //return 'sucess';
    } 
    
    @AuraEnabled
    public static String testResponseMethod()
    {
        system.debug('testResponse=======**********'+testResponse);
        return testResponse;
    }    
    public static void apigeeCallout(String mdmEnterprise){
        system.debug('callout====='+mdmEnterprise);        
        for(Secret_Setting__c setting: [select Id,Name,Encrypted_Value__c,Token_Validity_Limit__c,Alternate_Token_Value__c,LastModifiedDate
                                        from Secret_Setting__c where Project__c='CCT' and Name in (:EPRESENTMENT_ACCESS_TOKEN)]){
                                            
                                            settingsMap.put(setting.Name,setting);
                                        }
        
        Secret_Setting__c accessTokenSetting = settingsMap.get(EPRESENTMENT_ACCESS_TOKEN);
        system.debug('accessTokenSetting====='+accessTokenSetting);
        If(String.isBlank(accessTokenSetting.Alternate_Token_Value__c) 
           || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime()) >(accessTokenSetting.Token_Validity_Limit__c*60*1000)){
               system.debug('insider i ');
               getAccessToken(mdmEnterprise);
           }       
        
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
        request.setEndpoint(Label.lbl_CCT_ePresentment_GET_TOKEN);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        String requestBody = '{"client_id": "'+settingsMap.get('ePresentment Client Id').Encrypted_Value__c+'","client_secret": "'+settingsMap.get('ePresentment Client Secret').Encrypted_Value__c+'","grant_type": "client_credentials"}';
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
    private static void updateTokenSetting(HttpResponse response,Secret_Setting__c accessTokenSetting, String mdmEnterprise){
        
        JSONParser parser = JSON.createParser(response.getBody());
        HTTPResponse res;
        while (parser != null) {                
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'access_token')) {                       
                parser.nextToken();
                System.debug('--++--access_token:'+parser.getText());                        
                accessTokenSetting.Alternate_Token_Value__c=parser.getText();
                update accessTokenSetting;
                break;
                system.debug('mdmEnterpriseId===update . =='+mdmEnterprise);
                system.debug('***))))****'+[select Alternate_Token_Value__c,LastModifiedDate
                                 from Secret_Setting__c where Project__c='CCT' and Name in (:EPRESENTMENT_ACCESS_TOKEN)]);
                //res = CCT_EPresentmentPreferences.patternsAndFrameWorks(parser.getText(),mdmEnterprise);
                
                //update accessTokenSetting;
                
            }
            parser.nextToken();
        } 
        //return res;
    }
    
    /*************************************************************
*   @Author:  Cognizant                                      *
*   @Name: getAccessToken                                    *
*   @Return: null                                            *
*   @Description: method to get access token                 *
************************************************************/        
    @future(Callout=true)
    public static void getAccessToken(String mdmEnterprise){
        system.debug('mdmEnterpriseId=   getAccess===='+mdmEnterprise);
        for(Secret_Setting__c setting: [select Id,Name,Token_Validity_Limit__c,Encrypted_Value__c,Alternate_Token_Value__c,LastModifiedDate 
                                        from Secret_Setting__c where Project__c='CCT' 
                                        and Name in ('ePresentment Client Id','ePresentment Client Secret',:EPRESENTMENT_ACCESS_TOKEN)]){
                                            settingsMap.put(setting.Name,setting);
                                        }
        HttpResponse response;
        Secret_Setting__c accessTokenSetting=settingsMap.get(EPRESENTMENT_ACCESS_TOKEN);
        //Considering 60 minutes of token validity
        if((String.isBlank(accessTokenSetting.Alternate_Token_Value__c)) 
           || (Datetime.now().getTime()-accessTokenSetting.LastModifiedDate.getTime())>= (accessTokenSetting.Token_Validity_Limit__c*60*1000)){
               
               response = sendAccessTokenRequest(settingsMap);
               system.debug('res=='+response);
               if (response.getStatusCode() != 200) {
                   System.debug('The status code returned was not expected Create Token: ' +
                                response.getStatusCode() + ' ' + response.getStatus());
                   return ;
               }
               else if(response.getStatusCode() == 200) {
                   system.debug('Status CODE SUCCESS'+response.getStatusCode());
                   updateTokenSetting(response,accessTokenSetting, mdmEnterprise);
               }
               
           }
    }
    
    @future(callout=true)
    public static void patternsAndFrameWorks( String mdmEnterprise){
        system.debug('contactData====='+contactData);
        String mdmEnterpriseId = mdmEnterprise;
        system.debug('mdmEnterpriseId===444=='+mdmEnterpriseId);
        HttpResponse res = patternsAndFrameWorksCallOut(mdmEnterpriseId);
        frameworkResponse = res;
        string resData = res.getBody();
        testResponse = res.getBody();
        List<PatternsAndFrameworksResponse> responseData = (List<PatternsAndFrameworksResponse>) JSON.deserialize( resData, List<PatternsAndFrameworksResponse>.class);
system.debug('((((('+responseData);
        //return res;
        
        /*if(contactData != null){
mdmEnterpriseId = contactData.MDM_Enterprise_ID__c;
HttpResponse res = patternsAndFrameWorksCallOut(mdmEnterpriseId,accessToken);                    
}*/
    }
    //@future(callout=true)
    public static HttpResponse patternsAndFrameWorksCallOut(String mdmEnterpriseId){
        system.debug('mdmEnterpriseId====='+mdmEnterpriseId);
        system.debug('****'+[select Alternate_Token_Value__c,LastModifiedDate
                                 from Secret_Setting__c where Project__c='CCT' and Name in (:EPRESENTMENT_ACCESS_TOKEN)]);
        String accessToken = [select Alternate_Token_Value__c
                                 from Secret_Setting__c where Project__c='CCT' and Name in (:EPRESENTMENT_ACCESS_TOKEN)].Alternate_Token_Value__c;
            system.debug('----'+accessToken);
        Http http = new Http();
        HttpRequest request = new HttpRequest();  
        request.setEndpoint(Label.lbl_CCT_ePresentment_Framework+mdmEnterpriseId);
        request.setMethod('GET');
        request.setTimeout(120000); 
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/xml');
        //request.setHeader('Authorization','Bearer '+accessToken);
        request.setHeader(AUTH, BEARER + accessToken);
        request.setClientCertificateName('nonprod_sf_apigee_client_manulife_com');
        //settingsMap.get('').Alternate_Token_Value__c); 
        /*Blob headerValue = Blob.valueOf(accessToken);
String authorizationHeader = 'Bearer ' + EncodingUtil.base64Encode(headerValue);
request.setHeader('Authorization', authorizationHeader);*/
        //system.debug('request====='+request);
        system.debug('request====='+request);
        HttpResponse response = http.send(request);//response; //http.send(request);
        system.debug('framework response==='+response);
        return response;
    }
    
    public class PatternsAndFrameworksResponse{
        
        @AuraEnabled
        public String preferenceType;
        @AuraEnabled
        public String productName;
        @AuraEnabled
        public String preferenceDelivery;
        @AuraEnabled
        public Boolean preferenceIsChangeAllowed;
        @AuraEnabled
        public String patternId;        
    }
}