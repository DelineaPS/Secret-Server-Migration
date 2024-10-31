
<# File Migration - No Module.ps1.ps1
	V1.0 - initial release
	
	This script will migrate all File attachments in a source instance to a target instance.
    This includes secrets with multiple file attachments


	
    * PREREQUISITES

    - All secrets must already exist in the target instance
    - All templates must Exist in the target, and  have matching fields in both Source and target templates  
    - Will Handle Duplicate Secrets as long as they exist in Seperate folders
    - Unlimited Admin Must be set on Both Instances
    - An existing file path must exist to Temporarily  hold Files, and to write.
    

    Fill out The information in the user configurations region
   
    

#>

#region User Configurations

$tempFilePath = "C:\temp\Migration Files\"
$logfileName = "ss-FileMigration.log"
#Set Parameters

$site = "https://ps01.thycotic.blue/SecretServer"
$api = "$site/api/v1" # Do Not Change
$tsite = "https://proservices.secretservercloud.com"
$tapi = "$tsite/api/v1"#Set Global Variables

# Srcipt Settings




$AuthToken = Get-Credential -Message "Enter Target Credentials Domain\username"
$creds = @{
    username   =  $AuthToken.UserName
    password   =  $AuthToken.GetNetworkCredential().Password
    grant_type = "password" 
}

$AuthToken = Get-Credential -Message "Enter Target Credentials Domain\username"
$tcreds = @{
    username   =  $AuthToken.UserName
    password   =  $AuthToken.GetNetworkCredential().Password
    grant_type = "password" 
}
#endregion

#region Script Functions
function get_token {

    param(
        $baseURL,
        $icreds
    )
    try {
       
        $isite = $baseURL
        $token = ""
        $uri = "$isite/oauth2/token"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $icreds
        $token = $response.access_token;

   
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $token")
  
    }
      
    catch {
        $message =  $Error[1]
        Write-Error "$isite Authentication failed    $message"

        exit 1
    }
    return $headers
}
function write-log ($dataitem) {(get-date).ToString("[yyyy-MM-dd hh:mm:ss.ffff zzz]`t"), $dataitem -join "" | Add-Content -Path($tempFilePath, $logfileName -join "\")}
#endregion

#Valudating folder for logs and temp files exists
if (!(test-path $tempFilePath)) { throw "File Path $tempFilePath does not exist" }

write-log "------------ Starting run ------------"
write-log ("Source " + $site)
write-log ("Destination " + $tsite)

#get auth Tokens
$header = get_token -baseURL $site -icreds $creds
$theader = get_token -baseURL $tsite -icreds $tcreds

function get-report{
    param (
        $iApi,
        $iHeader 
        
        )

    $sql = "
    SELECT s.secretid,
    s.SecretName,
    s.secretid as [SecretIDNumber],
    ISNULL(f.FolderPath, N'No folder assigned') as [Folder Path],
    st.secrettypename,
	a.FileName,
	cast(round((a.FileSize/1024.0),2) as decimal(10,2)) as [File Size Kb],
	a.LastModifiedDate
FROM tbSecret AS s
    INNER JOIN tbSecretItem AS i ON i.SecretID = s.SecretID
    INNER JOIN tbFileAttachment a ON i.FileAttachmentId = a.FileAttachmentId
    LEFT JOIN tbFolder f WITH (NOLOCK) ON s.FolderId = f.FolderId
    INNER JOIN tbSecretType st WITH (NOLOCK) ON s.SecretTypeId = st.SecretTypeId
WHERE i.FileAttachmentId IS NOT NULL
    AND s.Active = 1
    AND st.OrganizationId = 1
    AND a.IsDeleted = 0

     "

     
$body = @{
   
    previewSql = $sql
    encodeHtml = $false
  
    } | ConvertTo-Json

    
    $sourceData = Invoke-RestMethod -Uri "$iapi/reports/execute" -Method Post -Headers $iheader -Body $body -ContentType "application/json"
    $Groups = @()
    foreach ($target in $sourceData.rows) {
        $secretArray  = $target -Split "`r`n"
        $object = New-Object -TypeName PSObject 
        $object | Add-Member -MemberType NoteProperty -Name secretid -Value $secretArray[0]
        $object | Add-Member -MemberType NoteProperty -Name FolderPath -Value $secretArray[3]
        $object | Add-Member -MemberType NoteProperty -Name secretName -Value $secretArray[1]
        $object | Add-Member -MemberType NoteProperty -Name SecretIDNumber -Value $secretArray[2]
        $object | Add-Member -MemberType NoteProperty -Name secrettypename -Value $secretArray[4]
        $object | Add-Member -MemberType NoteProperty -Name FileName -Value $secretArray[5]
        $object | Add-Member -MemberType NoteProperty -Name File_Size_Kb -Value $secretArray[6]
        $object | Add-Member -MemberType NoteProperty -Name LastModifiedDate -Value $secretArray[7]
        $Groups += $object
    }

    return $Groups    


}
function get-Secrets {
param(
$iapi,
$iheader

)
    $sql = "
    SELECT s.SecretID 
    ,s.SecretName 
    ,f.FolderPath
	,st.SecretTypeName
    from tbsecret s
    INNER JOIN tbfolder f on f.FolderID = s.FolderId
	INNER JOIN tbSecretType st on st.SecretTypeID = s.SecretTypeID
    WHERE s.active = 1
"
$body = @{
   
    previewSql = $sql      
    encodeHtml = $false
  
    } | ConvertTo-Json

    $sourceData = Invoke-RestMethod -Uri "$iapi/reports/execute" -Method Post -Headers $iheader -Body $body -ContentType "application/json"
    $targets = @()
    foreach ($target in $sourceData.rows) {
        $secretArray  = $target -Split "`r`n"
        $object = New-Object -TypeName PSObject 
        $object | Add-Member -MemberType NoteProperty -Name secretId -Value $secretArray[0]
        $object | Add-Member -MemberType NoteProperty -Name secretName -Value $secretArray[1]
        $object | Add-Member -MemberType NoteProperty -Name folderPath -Value $secretArray[2]
        $object | Add-Member -MemberType NoteProperty -Name SecretTemplateName -Value $secretArray[3]
       
           $targets += $object
}

return  $targets

}
#Run report of current file attachments and enumerate reports records
$report = get-report -iApi $api -iHeader $header

$total = $report.Count
write-log "Report run $total entries found"
$loop = 1
#iterate through report items
# get Target Serets
$secrets = get-Secrets -iapi $api -iheader $header
$tsecrets = get-Secrets -iapi $tapi -iheader $theader
foreach ($item in $report) { 
    $targ = $null
   
   
    #write-log ($item | ConvertTo-Json -Compress)
    Write-host "-----------------------------------------------------"
    write-host "[" $loop.tostring("0000") "/" $total.tostring("0000") "] Processing Source Secret" $item.SecretIDNumber 
    Write-host "-----------------------------------------------------"
    write-host "Path`t`t:" ($item.'folder path', $item.secretname -join "\")
    write-host "FileName`t:" $item.FileName
    Write-host "-----------------------------------------------------"
    write-host ""

    #try to find the target secret using the exact path (should avoid duplicate confusion)
    if ($item.Folder_Path -eq 'No folder assigned') {
        $targ =  2
    }
    else {
        
        #
        $targId =  $($tsecrets | where-object { $_.secretName -eq  $item.secretName -and $_.folderpath -eq $item.folderPath}).secretid
        if($null -ne $targId){
        $targ = Invoke-RestMethod -uri "$tapi/secrets/$targId" -Method Get -Headers $theader
        }
    }
    if ($null -eq $targ) {

        #if the target secret can't be located, ask the user for the target secret ID

        Write-Error ("Cannot find Secret " + ($item.'folder path', $item.secretname -join "\") + " - source secret ID " + $item.SecretIDNumber) 
        
        $ManualTargetID = -1
        write-log ("Cannot find Secret " + ($item.'folder path', $item.secretname -join "\") + " - source secret ID " + $item.SecretIDNumber) 
        if ($ManualTargetID -eq -1) { $targ = $null }else { $targ = Get-TssSecret -TssSession $DestinationSession -id $ManualTargetID }
    }
    #if the target is found, start the fun
    if ($null -ne $targ) {
        write-log ("Target" + ($targ | select-object Name, Id, FolderId, SecretTemplateName | convertto-json -Compress) + ($targ.Items | select-object slug, filename | convertto-json -Compress))

        #grab source secret
        $srce = Invoke-RestMethod -uri "$api/secrets/$($item.secretid)" -Method Get -Headers $header
        write-log ("Source" + ($srce | select-object Name, Id, FolderId, SecretTemplateName | convertto-json -Compress) + ($srce.Items | select-object slug, filename | convertto-json -Compress))

        #validate that all templates match
        if ($targ.SecretTemplateName -eq $item.secrettypename -and $targ.SecretTemplateName -eq $srce.SecretTemplateName) {
            
            #get "slug" value for template field containing file
            $SrceSlug = ($srce.Items | Where-Object -property Filename -eq $item.fileName).slug
            $OutputPath =  ($tempFilePath + $srce.id + $SrceSlug)
            $FileName = $item.FileName
            
            #File download
            try {
                write-host "Downloading $filename to $outputpath"
                Invoke-WebRequest -Uri ($api + "/secrets/" + $srce.id + "/fields/" + $SrceSlug + "?args.includeInactive=true") -Headers $header -OutFile $OutputPath    
             
                write-log ("File > $filename < downloaded: " + $OutputPath)
            }
            catch {
                Write-log "Error downloading attachment: $_"
                Write-Error "Error downloading attachment: $_" 
            }
            #package download to be sent to the target system
            $sendSecretFieldParams = @{
                fileName       = $FileName
                fileAttachment = ([IO.File]::ReadAllBytes($OutputPath))
            }
            $body = ConvertTo-Json $sendSecretFieldParams

            #upload data to the secret field
            try {
                write-host "Uploading file"
                $ProgressPreference = "SilentlyContinue"
                Invoke-WebRequest -Uri ($tapi + "/secrets/" + $targ.id + "/fields/" + $SrceSlug) -Headers $theader -Body $Body -Method put -ContentType 'application/json'  | Out-Null
                write-log ("Uploaded $outputpath to SecretID: " + $targ.id + " - Slug: $SrceSlug - Filename: $filename")
            }
            catch {
                Write-Log "Error Uploading attachment: $_" 
                Write-Error "Error Uploading attachment: $_" 
            }
            write-host "Removing downloaded file $outputPath"
            Remove-Item $OutputPath
            if (Test-Path $OutputPath) {
                write-log "error removing $outputpath" 
                write-error "error removing $outputpath" 
            }
            else {
                write-log "cleanup successful"  
                write-host "cleanup successful" 
            }
        }
        else {
            write-error "template mismatch" 
            write-log "template mismatch" 
        }
    }
    write-host "" 
    $loop++

    #added to keep SSC WAF happy
    Start-Sleep -Milliseconds 250
}
write-log "------------ Run Completed ------------"
