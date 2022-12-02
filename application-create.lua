local clock = os.clock
function sleep(n)
    local t0 = clock()
while clock() - t0 <= n do end
end

return function (data, event, source, pid)
  sleep(3)
  kong.log.info("####################################### WSO2 - PRODUCTION #######################################")
  local http = require "resty.http"
  local httpc = http.new()
  local urlIDP = "url"
  local authorizationIDP = "auth"

  local applicationname = data.entity.name .. "_PRODUCTION"
  local applicationdescription = ""
  if data.entity.description ~= nil then
    applicationdescription = "" ..data.entity.description
  end
  local applicationId = data.entity.id

 
  -- CALL 1 : register oauth2 application
  kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 1 - register oauth2 app #######################################")

  local body_soap_register_oauth2_app = "<soapenv:Envelope xmlns:soapenv=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsd=\"http://org.apache.axis2/xsd\" xmlns:xsd1=\"http://dto.oauth.identity.carbon.wso2.org/xsd\">"..
  " <soapenv:Header/>"..
  " <soapenv:Body>"..
  "    <xsd:registerOAuthApplicationData>"..
  "        <xsd:application>"..
  "            <xsd1:OAuthVersion>OAuth-2.0</xsd1:OAuthVersion>"..
  "            <xsd1:applicationAccessTokenExpiryTime>3600</xsd1:applicationAccessTokenExpiryTime>"..
  "            <xsd1:applicationName>".. applicationname .."</xsd1:applicationName>"..
  "            <xsd1:callbackUrl>http://application_kong.fr</xsd1:callbackUrl>"..
  "            <xsd1:grantTypes>refresh_token urn:ietf:params:oauth:grant-type:saml2-bearer implicit password client_credentials iwa:ntlm authorization_code</xsd1:grantTypes>"..
  "            <xsd1:pkceMandatory>false</xsd1:pkceMandatory>"..
  "            <xsd1:pkceSupportPlain>true</xsd1:pkceSupportPlain>"..
  "            <xsd1:refreshTokenExpiryTime>84000</xsd1:refreshTokenExpiryTime>"..
  "            <xsd1:userAccessTokenExpiryTime>3600</xsd1:userAccessTokenExpiryTime>"..
  "        </xsd:application>"..
  "    </xsd:registerOAuthApplicationData>"..
  " </soapenv:Body>"..
  "</soapenv:Envelope>"
  
  kong.log.info ("WSO2: body_soap_register_oauth2_app=" .. body_soap_register_oauth2_app)

  local res, err = httpc:request_uri("https://".. urlIDP .."/services/OAuthAdminService?wsdl", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/soap+xml",
      ["Authorization"] = "Basic ".. authorizationIDP
    },
    query = {
    },
    body = body_soap_register_oauth2_app,
    keepalive_timeout = 10,
    keepalive_pool = 10
    })
--[[ 
    if err then
      kong.log.info ("WSO2: function OAuthAdminService: err=" .. err)
        return kong.response.exit(500, "{\
        \"Error Code\": " .. 500 .. ",\
        \"Error Message\": \"WSO2: Kong function OAuthAdminService: Unable to call correctly the IdP Endpoint\"\
        }",
        {
        ["Content-Type"] = "application/json"
        }
      )
      -- return nil, err
    end

    kong.log.info ("WSO2: function OAuthAdminService register: res.body=" .. res.body)
    
    if res.status ~= 200 then
        return kong.response.exit(res.status, "{\
        \"Error Code\": " .. res.status .. ",\
        \"Error Message\": \"WSO2: Kong function OAuthAdminService: Unable to call correctly the IdP Endpoint\"\
        }",
        {
        ["Content-Type"] = "application/json"
        }
      )
    end
]]


  -- CALL 2 : get oauth2 application
  kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 2 - get oauth2 application #######################################")
  
  local body_soap_get_oauth2_app = "<soapenv:Envelope xmlns:soapenv=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsd=\"http://org.apache.axis2/xsd\">"..
  "<soapenv:Header/>"..
  "<soapenv:Body>"..
  "   <xsd:getOAuthApplicationDataByAppName>"..
  "     <xsd:appName>".. applicationname .."</xsd:appName>"..
  "   </xsd:getOAuthApplicationDataByAppName>"..
  "</soapenv:Body>"..
"</soapenv:Envelope>"
  
  kong.log.info ("WSO2: body_soap_get_oauth2_app=" .. body_soap_get_oauth2_app)

  local res, err = httpc:request_uri("https://".. urlIDP .."/services/OAuthAdminService?wsdl", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/soap+xml",
      ["Authorization"] = "Basic ".. authorizationIDP
    },
    query = {
    },
    body = body_soap_get_oauth2_app,
    keepalive_timeout = 10,
    keepalive_pool = 10
    })

  kong.log.info ("WSO2: function OAuthAdminService get: res.body=" .. res.body)

  -- Extract the ClientId 
  local clientId
  local b2, e2 = string.find(res.body, "<ax2447:oauthConsumerKey>")
  local b3, e3 = string.find(res.body, "</ax2447:oauthConsumerKey>")
  if e2 ~= nil and b3 ~= nil then
    clientId = string.sub(res.body, e2 + 1, b3 - 1)
  end
   -- Extract the ClientSecret
   local clientSecret
   local b2, e2 = string.find(res.body, "<ax2447:oauthConsumerSecret>")
   local b3, e3 = string.find(res.body, "</ax2447:oauthConsumerSecret>")
   if e2 ~= nil and b3 ~= nil then
    clientSecret = string.sub(res.body, e2 + 1, b3 - 1)
   end


  kong.log.info ("WSO2: function OAuthAdminService get: clientID=" .. clientId)
  kong.log.info ("WSO2: function OAuthAdminService get: clientSecret=" .. clientSecret)


  -- CALL 3 : create service provider
  kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 3 - create service provider #######################################")

  local body_create_SP = "<soapenv:Envelope xmlns:soapenv=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsd=\"http://org.apache.axis2/xsd\" xmlns:xsd1=\"http://model.common.application.identity.carbon.wso2.org/xsd\"> "..
    " <soapenv:Header/> "..
    "  <soapenv:Body> "..
    "      <xsd:createApplication> <xsd:serviceProvider> "..
    "     <xsd1:applicationName>" .. applicationname  .."</xsd1:applicationName> "..
    "     <xsd1:description>" .. applicationdescription  .. "</xsd1:description> </xsd:serviceProvider> </xsd:createApplication> "..
    "  </soapenv:Body>"..
    "</soapenv:Envelope>"

  kong.log.info ("WSO2: body_create_SP=" .. body_create_SP)

  local res, err = httpc:request_uri("https://".. urlIDP .."/services/IdentityApplicationManagementService?wsdl", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/soap+xml",
      ["Authorization"] = "Basic ".. authorizationIDP
    },
    query = {
    },
    body = body_create_SP,
    keepalive_timeout = 10,
    keepalive_pool = 10
    })

  
  kong.log.info ("WSO2: function IdentityApplicationManagementService create: res.body=" .. res.body)

  
  
  -- CALL 4 : get service provider
  kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 4 - get service provider #######################################")
  local body_get_SP = "<soapenv:Envelope xmlns:soapenv=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsd=\"http://org.apache.axis2/xsd\"> "..
  " <soapenv:Header/> "..
  "  <soapenv:Body> "..
  "     <xsd:getApplication>"..
  "       <xsd:applicationName>".. applicationname .."</xsd:applicationName>"..
  "    </xsd:getApplication>"..
  "  </soapenv:Body>"..
  "</soapenv:Envelope>"

  kong.log.info ("WSO2: body_get_SP=" .. body_get_SP)

  local res, err = httpc:request_uri("https://".. urlIDP .."/services/IdentityApplicationManagementService?wsdl", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/soap+xml",
      ["Authorization"] = "Basic ".. authorizationIDP
    },
    query = {
    },
    body = body_get_SP,
    keepalive_timeout = 10,
    keepalive_pool = 10
    })

  kong.log.info ("WSO2: function IdentityApplicationManagementService get: res.body=" .. res.body)

    -- Extract the ClientSecret
    local idApplication
    local b2, e2 = string.find(res.body, "<ax2216:applicationID>")
    local b3, e3 = string.find(res.body, "</ax2216:applicationID>")
    if e2 ~= nil and b3 ~= nil then
      idApplication = string.sub(res.body, e2 + 1, b3 - 1)
    end
   
  kong.log.info ("WSO2: function IdentityApplicationManagementService get IDApplication: res.body=" .. idApplication) 


  
  -- CALL 5 : update service provider
  kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 5 - update service provider #######################################")
  local body_update_SP = "<soapenv:Envelope xmlns:soapenv=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsd=\"http://org.apache.axis2/xsd\" xmlns:xsd1=\"http://model.common.application.identity.carbon.wso2.org/xsd\"> "..
  " <soapenv:Header/> "..
  "  <soapenv:Body> "..
  "<xsd:updateApplication>"..
  "<xsd:serviceProvider>"..
      "<xsd1:applicationID>"..idApplication.."</xsd1:applicationID>"..
      "<xsd1:applicationName>"..applicationname.."</xsd1:applicationName>"..
      "<xsd1:claimConfig>"..
          "<xsd1:alwaysSendMappedLocalSubjectId>false</xsd1:alwaysSendMappedLocalSubjectId>"..
          "<xsd1:localClaimDialect>true</xsd1:localClaimDialect>"..
      "</xsd1:claimConfig>"..
      "<xsd1:description>"..applicationdescription.."</xsd1:description>"..
      "<xsd1:inboundAuthenticationConfig>"..
          "<xsd1:inboundAuthenticationRequestConfigs>"..
              "<xsd1:inboundAuthKey>"..clientId.."</xsd1:inboundAuthKey>"..
              "<xsd1:inboundAuthType>oauth2</xsd1:inboundAuthType>"..
              "<xsd1:properties>"..
                  "<xsd1:name>oauthConsumerSecret</xsd1:name>"..
                  "<xsd1:value>"..clientSecret.."</xsd1:value>"..
              "</xsd1:properties>"..
          "</xsd1:inboundAuthenticationRequestConfigs>"..
          "<xsd1:inboundAuthenticationRequestConfigs>"..
              "<xsd1:inboundAuthKey>test.com</xsd1:inboundAuthKey>"..
              "<xsd1:inboundAuthType>samlsso</xsd1:inboundAuthType>"..
              "<xsd1:properties>"..
                  "<xsd1:name>attrConsumServiceIndex</xsd1:name>"..
                  "<xsd1:value>202240762</xsd1:value>"..
              "</xsd1:properties>"..
          "</xsd1:inboundAuthenticationRequestConfigs>"..
      "</xsd1:inboundAuthenticationConfig>"..
      "<xsd1:inboundProvisioningConfig>"..
          "<xsd1:provisioningEnabled>false</xsd1:provisioningEnabled>"..
          "<xsd1:provisioningUserStore>PRIMARY</xsd1:provisioningUserStore>"..
      "</xsd1:inboundProvisioningConfig>"..
      "<xsd1:localAndOutBoundAuthenticationConfig>"..
          "<xsd1:alwaysSendBackAuthenticatedListOfIdPs>false</xsd1:alwaysSendBackAuthenticatedListOfIdPs>"..
          "<xsd1:authenticationStepForAttributes></xsd1:authenticationStepForAttributes>"..
          "<xsd1:authenticationStepForSubject></xsd1:authenticationStepForSubject>"..
          "<xsd1:authenticationType>default</xsd1:authenticationType>"..
          "<xsd1:subjectClaimUri>http://wso2.org/claims/fullname</xsd1:subjectClaimUri>"..
      "</xsd1:localAndOutBoundAuthenticationConfig>"..
      "<xsd1:outboundProvisioningConfig>"..
          "<xsd1:provisionByRoleList></xsd1:provisionByRoleList>"..
      "</xsd1:outboundProvisioningConfig>"..
      "<xsd1:permissionAndRoleConfig></xsd1:permissionAndRoleConfig>"..
      "<xsd1:saasApp>false</xsd1:saasApp>"..
  "</xsd:serviceProvider>"..
"</xsd:updateApplication>"..
"</soapenv:Body>"..
"</soapenv:Envelope>"

local res, err = httpc:request_uri("https://".. urlIDP .."/services/IdentityApplicationManagementService?wsdl", {
  method = "POST",
  headers = {
    ["Content-Type"] = "application/soap+xml",
    ["Authorization"] = "Basic ".. authorizationIDP
  },
  query = {
  },
  body = body_update_SP,
  keepalive_timeout = 10,
  keepalive_pool = 10
  })

  kong.log.info ("WSO2: function IdentityApplicationManagementService update: res.body=" .. res.body)


    kong.log.info(">>>>> WSO2 id: "..applicationId)
    -- CALL 6 : update description
    kong.log.info("####################################### [WSO2-PRODUCTION] : CALL 7 - update description #######################################")
    applicationdescription = applicationdescription .. "[PRODUCTION] ClientID: " .. clientId .. " / ClientSecret: " .. clientSecret
  
    local body_update_desc = '{ "description": "'.. applicationdescription..'", "custom_id" : "'.. clientId ..'"}'
  
  
    kong.log.info ("WSO2: update desc: res.body=" ..body_update_desc)
  
    local res, err = httpc:request_uri("url/kong/applications/"..applicationId, {
      method = "PATCH",
      headers = {
        ["Kong-Admin-Token"] = "token",
        ["Content-Type"] = "application/json"
      },
      query = {
      },
      body = body_update_desc,
      keepalive_timeout = 10,
      keepalive_pool = 10
      })

      kong.log.info ("WSO2: PRODUCTION body=" ..res.body)



end

