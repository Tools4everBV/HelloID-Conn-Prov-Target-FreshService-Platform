Add-Type -AssemblyName System.Web;

$ServiceURL = "https://<customer>.freshservice.com"
$ApiKey = "<KEY>"
 
# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
 
#Initialize default properties
$success = $False;
$p = $person | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json;
$auditMessage = " not enabled successfully";

try{
    # Create authorization headers with HelloID API key
    $pair = "${ApiKey}:${ApiKey}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"

    $headers = @{"authorization" = $Key}

    # Check if already active (reactivate only works when account disabled)
    $queryUri = "$($ServiceURL)/api/v2/requesters/$($aRef)"
    
    $existingResponse = Invoke-RestMethod -Method GET -Uri $queryUri -Headers $headers -ContentType "application/json" -Verbose:$false

    if($existingResponse.requester.active)
    {
        Write-Verbose -Verbose "Account already activated"  

        $success = $True;
        $auditMessage = " enabled successfully";     
    }
    else
    {
        if(-Not($dryRun -eq $True)) {
            # Define specific endpoint URI
            if($ServiceUrl.EndsWith("/") -eq $false){ $ServiceUrl = $ServiceUrl + "/" }
            $uri = "$($ServiceURL)api/v2/requesters/$($aRef)/reactivate"
            
            $response = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false

            $success = $True;
            $auditMessage = " enabled successfully";
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
        $auditMessage = " : General error";
    } 
}
 
#build up result
$result = [PSCustomObject]@{
    Success = $success;
    AccountReference = $aRef;
    AuditDetails = $auditMessage;
    Account = $account;
};
 
#send result back
Write-Output $result | ConvertTo-Json -Depth 10
