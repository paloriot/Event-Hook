# Event-Hook
Kong "Lambda event-hook" in Lua code 

Code to create application registration in a third party IDP
Purpose is to do dynamic registration when Kong Dev Portal is configure to use 3rd party registration & auth. 

Code executed : 
- Get dev portal application data
- Requests chaining in soap to create application registration and get credentials
- update Kong application 'custom_id' with 3rd party client-id to allow portal-registration ACL

How deploy the Lambda event Hook : 
https://docs.konghq.com/gateway/latest/kong-enterprise/event-hooks#custom-webhook

Exemple (trigger app creation) : 
http -f :8001/event-hooks \                      
 source=crud \
 event=applications:create \
 handler=lambda "config.functions[]=@application-create.lua"
 
