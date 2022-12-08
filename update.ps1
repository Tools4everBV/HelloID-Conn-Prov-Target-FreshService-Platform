$ServiceURL = "https://<customer>.freshservice.com"
$ApiKey = "<KEY>"
 
# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
 
#Initialize default properties
$success = $False;
$p = $person | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json;
$auditMessage = "Account for person " + $p.DisplayName + " not created successfully";

#Change mapping here
$account = @{
                first_name          = $p.Name.NickName;
                last_name          = $p.Name.FamilyName;
                primary_email      = $p.Contact.Business.Email
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
    $uri = "$($ServiceURL)api/v2/requesters/$($aRef)"
    
    if(-Not($dryRun -eq $True)) {
        $body = $account | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -Verbose:$false


        $success = $True;
        $auditMessage = " successfully";
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

    ExportData = [PSCustomObject]@{
        primary_email               = $p.Contact.Business.Email
    }
};
 
#send result back
Write-Output $result | ConvertTo-Json -Depth 10
