function Get-AzureADToken
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $clientId,
    [String]
    [Parameter(Mandatory)]
    $clientSecret,
    [string]
    [Parameter(Mandatory)]
    $RedirectURI,
    [string]
    [Parameter(Mandatory)]
    $resource,
    [string]
    [Parameter(Mandatory)]
    $useremail
  )
  Add-Type -AssemblyName system.web
  #encoded Variables for the oauth string. 
  $clientIDEncoded = [Web.HttpUtility]::UrlEncode($clientid)
  $clientSecretEncoded = [Web.HttpUtility]::UrlEncode($clientSecret)
  $redirectUriEncoded =  [Web.HttpUtility]::UrlEncode($redirectUri)
  $resourceEncoded = [Web.HttpUtility]::UrlEncode($resource)
  # Get oauth2 Code
  $url = ('https://login.microsoftonline.com/vitlabs.onmicrosoft.com/oauth2/authorize?response_type=code&redirect_uri={0}&client_id={1}&resource={2}&prompt=admin_consent&login_hint={3}' -f $redirectUriEncoded, $clientIDEncoded, $resourceEncoded, $useremail)
  # Pops a window to Authenticate to Microsoft Online.
  $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=420;Height=600}
  $web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=420;Height=600;Url=$url}
  $DocComp  = {$script:uri = $web.Url.AbsoluteUri; if ($script:uri -match "error=[^&]*|code=[^&]*") {$form.Close()}}
  $web.ScriptErrorsSuppressed = $true
  $web.Add_DocumentCompleted($DocComp)
  $form.Controls.Add($web)
  $form.Add_Shown({$form.Activate()})
  $null = $form.ShowDialog()
  if(([Web.HttpUtility]::ParseQueryString($web.Url.Query))["error"] -ne 'access_denied')
  {
    $authCode = ([Web.HttpUtility]::ParseQueryString($web.Url.Query))["code"]
    # Convert the oAuth2 code into a Token.
    $body = ('grant_type=authorization_code&redirect_uri={0}&client_id={1}&client_secret={2}&code={3}&resource={4}' -f $redirectUri, $clientId, $clientSecretEncoded, $authCode, $resource)
    (Invoke-RestMethod -Uri https://login.microsoftonline.com/vitlabs.onmicrosoft.com/oauth2/token -Method Post -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorAction STOP).access_token
  }
  else
  {
    Write-Output -InputObject 'Access Denied'
  }
}
#region action functions
function get-AzureSubs
{
  param
  (
    [String]
    [parameter(Mandatory)]
    $token
  )
  # Get Azure Subscriptions
  $subsweb = 'https://management.azure.com/subscriptions?api-version=2014-04-01-preview'
  (Invoke-RestMethod -Headers @{Authorization = "Bearer $token"} -uri $subsweb -Method Get).value
}

function get-azurepro
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [string]
    [Parameter(Mandatory)]
    $subid
  )
  # Get Azure Providers
  $providersweb = "https://management.azure.com/subscriptions/$subid/providers?api-version=2016-09-01"
  (Invoke-RestMethod -Headers @{Authorization = "Bearer $token"} -uri $providersweb -Method Get).value  
}

function get-azureregions
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [String]
    [Parameter(Mandatory)]
    $Providers
  )
  # Get VM Regions
  (($providers | Where-Object {$_.namespace -eq 'microsoft.compute'}).resourcetypes | Where-Object {$_.resourceType -eq 'virtualMachines'}).locations
}

function get-azureversion
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [String]
    [Parameter(Mandatory)]
    $Providers
  )
  # Get VM APIVersion
  (($providers | Where-Object {$_.namespace -eq 'microsoft.compute'}).resourcetypes | Where-Object {$_.resourceType -eq 'virtualMachines'}).apiversions
}

function get-azureResGroup
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [String]
    [Parameter(Mandatory)]
    $subid
  )
  # Get Resource Groups
  $resGrpWeblist = "https://management.azure.com/subscriptions/$subid/resourcegroups?api-version=2016-09-01"
  (Invoke-RestMethod -Headers @{Authorization = "Bearer $token"} -uri $resGrpWeblist -Method Get).value
}

function add-azureResGrp
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [String]
    [Parameter(Mandatory)]
    $subid,
    [string]
    [Parameter(Mandatory)]
    $ResGrpName,
    [string]
    [Parameter(Mandatory)]
    $vmregions
  )
  # New Resource Group
  $NewresGrpWeb = "https://management.azure.com/subscriptions/$subid/resourcegroups/$($ResGrpName)?api-version=2016-09-01"
  $newResGovbody = @"
{"Location":"$vmregions",
"name":"$($ResGrpName)"}
"@
  $json = Convertfrom-Json $newResGovbody
  (Invoke-RestMethod -Headers @{Authorization = "Bearer $token"} -uri $NewresGrpWeb -Method Put -ContentType application/json -Body (convertto-json $json)).value
}

function remove-azureResGrp
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $token,
    [String]
    [Parameter(Mandatory)]
    $subid,
    [string]
    [Parameter(Mandatory)]
    $resgrpname
  )
  $removeResGovWeb = "https://management.azure.com/subscriptions/$subid/resourcegroups/$($ResGrpName)?api-version=2016-09-01"
  Invoke-RestMethod -Headers @{Authorization = "Bearer $token"} -uri $removeResGovWeb -Method Delete
}
#endregion

#region do stuff

if ($token -eq '')
{$token = Get-AzureADToken -clientId $clientId -clientSecret $clientSecret -RedirectURI $RedirectURI -resource $resource -useremail $useremail}

$subs = get-AzureSubs -token $token

#endregion
