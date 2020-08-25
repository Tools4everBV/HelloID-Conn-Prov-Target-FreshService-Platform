Add-Type -AssemblyName System.Web;

$ServiceURL = "https://<customer>.freshservice.com"
$ApiKey = "<KEY>"
 
# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
 
#Initialize default properties
$success = $False;
$p = $person | ConvertFrom-Json
$auditMessage = "Account for person " + $p.DisplayName + " not created successfully";

#Change mapping here
$account = @{
                first_name          = $p.Name.NickName;
                last_name          = $p.Name.FamilyName;
                primary_email               = $p.Contact.Business.Email
                job_title          = $p.Custom.PrimaryPositionDesc
}

try{
    # Create authorization headers with HelloID API key
    $pair = "${ApiKey}:${ApiKey}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"

    $headers = @{"authorization" = $Key}

    # Define specific endpoint URI
    if($ServiceUrl.EndsWith("/") -eq $false){ $ServiceUrl = $ServiceUrl + "/" }
    $uri = "$($ServiceURL)api/v2/requesters"
    
    try{
        #Check for existing account, by email
        $queryUri = ("$($uri)?email=" + ([System.Web.HTTPUtility]::UrlEncode("$($account.primary_email)")));
        
        $response = Invoke-RestMethod -Method GET -Uri $queryUri -Headers $headers -ContentType "application/json" -Verbose:$false
        if($response.requesters.id -eq $null) { throw "no result" }
        $aRef = "$($response.requesters[0].id)";
        $existingAccount = $response.requesters[0];
        $existing = $true
    }
    catch
    {
        Write-Verbose -Verbose "No existing account."
    }
    
    if($existing -eq $true)
    {
        Write-Verbose -Verbose "Found existing account. $($aRef)"

        #Activate account if not active
        if($existingAccount.active -eq $false)
        {
            Write-Verbose -Verbose "Account is not active, updating active status"
            if(-Not($dryRun -eq $True)) {
                $activateuri = "$($ServiceURL)api/v2/requesters/$($aRef)/reactivate"
                $activateResponse = Invoke-RestMethod -Method PUT -Uri $activateuri -Headers $headers -ContentType "application/json" -Verbose:$false
            }
            
        }

        #Update account
        Write-Verbose -Verbose "Updating existing account."
        if(-Not($dryRun -eq $True)) {
                $uri = "$($ServiceURL)api/v2/requesters/$($aRef)"
                $body = $account | ConvertTo-Json -Depth 10
                $response = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -Verbose:$false
            }

        $success = $True;
        $auditMessage = " successfully";
    }
    else
    {
        Write-Verbose -Verbose "Creating account."
        if(-Not($dryRun -eq $True)) {
            $body = $account | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -Verbose:$false
            $aRef = "$($response.requester.id)";

            $success = $True;
            $auditMessage = " successfully";
        }
    }
}catch{
    if(-Not($_.Exception.Response -eq $null)){
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $errResponse = $reader.ReadToEnd();
        $auditMessage = " : ${errResponse}";
    }else {
        $auditMessage = " : General error $($_)";
    } 
}
 
#build up result
$result = [PSCustomObject]@{
    Success = $success;
    AccountReference = $aRef;
    AuditDetails = $auditMessage;
    Account = $account;

    ExportData = [PSCustomObject]@{
        primary_email               = $p.Contact.Business.Email
    }
};

Write-Output $result | ConvertTo-Json -Depth 10
