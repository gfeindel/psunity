<#
.Description
A Powershell module for interacting with the Cisco Unity Connection REST API.
#>

[CmdletBinding()]

$script:UnityServer = ''
$script:BaseUri = ''
$script:UnityCredential = [System.Management.Automation.PSCredential]::Empty

function Set-UnityServer {
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerName
    )
    $script:UnityServer = $ServerName
    $script:BaseUri = "https://$ServerName/vmrest"
}

function Set-UnityCredential {
    param(
        [parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$Credential
    )
    $script:UnityCredential = $Credential
}

function Initialize-UnityApi {
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerName,
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    Set-UnityServer -ServerName $ServerName
    Set-UnityCredential -Credential $Credential
}

function Invoke-UnityApi {
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Api,
        [ValidateSet('Get','Put','Post')]
        [string]$Method,
        [ValidateNotNull()]
        [Hashtable]$Body = @{}
    )

    $uri = "${script:BaseUri}${Api}"
    # See help for Invoke-RestMethod for behavior of Body parameter.
    # Default name=value body won't work for Unity API. Must be in JSON format.
    if($Method -eq 'Get') {
        $result = Invoke-RestMethod -Uri $uri -Method $Method -Credential $script:UnityCredential -Body $Body
    } else {
        $parms = @{
            Uri = $uri
            Method = $Method
            Credential = $script:UnityCredential
            ContentType = 'application/json'
            Body = ($Body | ConvertTo-Json)
        }
        $result = Invoke-RestMethod @parms
    }

    $result
}

function Get-UnityUser {
    param(
        [parameter(ParameterSetName='Id')]
        [string]$UserId,
        [parameter(ParameterSetName='Alias')]
        [string]$UserAlias,
        [parameter(ParameterSetName='All')]
        [switch]$All
    )
    # If no UserId or Alias, return all users.
    $api = "/users"
    if($UserId) {
        Invoke-UnityApi -Api "$api/$UserId" -Method Get
    } elseif($UserAlias) {
        $body = @{
            query = "(alias is $UserAlias)"
        }
        Invoke-UnityApi -Api $api -Method Get -Body $body
    } else {
        Invoke-UnityApi -Api $api -Method Get
    }
    # If UserId provided, return specific user.
    # If Alias provided, return user with matching alias.
}
function Get-UnityUserNotificationDevice {
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,
        [ValidateSet('Pager','Phone')]
        [string]$DeviceType,
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId
    )
    $api = "/users/$UserId/notificationdevices"

    # If a specific device type is provided, retrieve that device type.
    # Otherwise, retrieve all notification devices.
    switch($DeviceType) {
        'Pager' {
            $api = "$api/pagerdevices"
        }
        'Phone' {
            $api = "$api/phonedevices"
        }
    }
    # If a device ID is provided, retrieve that specific device.
    if($DeviceId) {
        $api = "$api/$DeviceId"
    }

    Invoke-UnityApi -Api $api -Method Get
}

function Set-UserNotificationDevice {
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId,
        [parameter(Mandatory)]
        [ValidateSet('Pager','Phone')]
        [string]$DeviceType,
        [string]$PhoneNumber
    )
    $api = "/users/$UserId/notificationdevices"

    switch($DeviceType) {
        'Pager' {
            $api = "$api/pagerdevices"
        }

        'Phone' {
            $api = "$api/phonedevices"
        }
    }
    $api = "$api/$DeviceId"

    $Body = @{PhoneNumber = $PhoneNumber}
    Invoke-UnityApi -Api $api -Method Put -Body $Body
}