({
    onPageLoad : function(component, event, helper) {
        var contactId = component.get("v.contactId");        
        var frameworkRes = component.get("v.frameworkResponseClass");
        var params = {"cntctId":contactId};
        var action = component.get("c.onInitMethod");
        action.setParams(params);
        action.setCallback(this,function(response){
            var state = response.getState();
            if(state == "SUCCESS"){
                if(response.getReturnValue()){
                    var res = JSON.parse(response.getReturnValue());
                    console.log('res===='+res);
                    component.set("v.frameworkResponseClass",res);
                    var uniqueProductNames = [...new Set(res.map(x => x.productName))];
                    console.log('res===='+uniqueProductNames);
                    component.set("v.uniqueProdNames",uniqueProductNames);
                    for(var i=0; i<res.length; i++){
                        if(res[i].productName == 'all'){
                            if(res[i].preferenceDelivery == 'electronic'){
                                component.set("v.isElectronic",true);
                            }
                            else if(res[i].preferenceDelivery == 'notselected'){
                                component.set("v.isNotSelected",true);
                            }                            
                        }
                        
                    }
                    
                    var electronicVal = component.get("v.isElectronic"); 
                    var customizeVal = component.get("v.isNotSelected");
                    //alert(electronicVal+'====='+customizeVal)
                    if(electronicVal){
                        component.set("v.isDisabled",true);
                    }
                    if(customizeVal){
                        component.set("v.isDisabled",false);
                    }
                    if(!electronicVal && !customizeVal){
                        component.set("v.isDisabled",true);
                    }                  
                    
                }
                else{
                    alert('Either enterprise ID is null or response is null');
                    //stay on same contact page. - logic
                }
                
                
                /*var redirectEvent = $A.get("e.c:CCT_RedirectToUrl");
                    alert(redirectEvent);
                    redirectEvent.setParams({"redirectRecId":contactId,"SObject":"Contact"});
                redirectEvent.fire();*/
            }
            else{
                alert('Unexpected error');
            }
        });
        $A.enqueueAction(action);       
        
    },
    onSave: function(component, event, helper) {
        var items = component.find("preferenceTypeId");
        var inputParams = [];
        var action = component.get("c.sendUpdateRequest");
        var reqClass = component.get("v.frameworkRequestClass");
        for(var i=0; i<=items.length; i++){
            //alert(items[i].get("v.checked"));
            alert("val"+items[i].get("v.value").split('-')[0]);
            inputParams.push(reqClass['user']='test',reqClass['enterpriseId']='222222',
                            reqClass['preferenceType']=items[i].get("v.value").split('-')[0],reqClass['productName']=items[i].get("v.value").split('-')[1],
                            reqClass['preferenceSubType']='all',reqClass['preferenceDelivery']='electronic',
                            reqClass['preferenceIsChangeAllowed']=true,reqClass['patternId']='222222',
                            reqClass['defaultVal']=true);            
        }
        console.log(inputParams);
        console.log(JSON.stringify(inputParams));
        var params = {"inputData":JSON.stringify([{'user':'tst',
                      'enterpriseId':'222222',
                      'preferenceType':'all',
                      'productName':'all',
                      'preferenceSubType':'all',
                      'preferenceDelivery':'electronic',
                      'preferenceIsChangeAllowed':true,
                      'patternId':'hjhj',
                                                  'defaultVal':true},{'user':'tst',
                      'enterpriseId':'222222',
                      'preferenceType':'all',
                      'productName':'all',
                      'preferenceSubType':'all',
                      'preferenceDelivery':'electronic',
                      'preferenceIsChangeAllowed':true,
                      'patternId':'hjhj',
                                                  'defaultVal':true}])}//{"inputData":reqClass};
        action.setParams(params);
        action.setCallback(this,function(response){
            var state = response.getState();
            if(state == "SUCCESS"){
                if(response.getReturnValue()){
                    /*var res = JSON.parse(response.getReturnValue());
                    console.log('res===='+res);
                    component.set("v.frameworkResponseClass",res);*/
                                     
                    
                }
                
            }
            else{
                alert('Unexpected error');
            }
        });
        $A.enqueueAction(action);
    },
    
})
