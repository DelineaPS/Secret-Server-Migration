$secretserverURL = "Https://XXXX.secretservercloud.com/"

$credential = Get-Credential 
Write-Host "** Creating new session: $secretServerURL`n" 
$tsssession = New-TssSession -SecretServer $secretserverURL -Credential $credential

# Basic info
Write-Host "** Searching Secrets`n"
$secrets = Search-TssSecret -TssSession $tsssession 
Write-Host "* Found $($secrets.count) Secrets`n`n"
$folders = Search-TssFolder -TssSession $tsssession 
Write-Host "* Found $($folders.count) Folders`n`n"

# Cleanup whitespace
$spaces = $secrets | Where-Object { $_.name -ne $_.name.trim() }
$folderSpaces = $folders | Where-Object { $_.Foldername -ne $_.foldername.trim() }

if ($Folderspaces.Count) {
    Write-Host "* Found $($Folderspaces.Count) Folders with whitespace`n"
    foreach ($Folder in $Folderspaces) {
        try {
            $newName = $Folder.FolderName.trim()
            Set-TssFolder -TssSession $tsssession -FolderName $newName -Id $Folder.FolderId    
           
            Write-Host "Renamed Folder: [$($Folder.FolderPath)] to [$newName]"
        }
        Catch {
            Write-Error $_
            Write-Host "FAILED to rename Folder: [$($Folder.FolderPath)]"
            Start-Sleep -Seconds 5
        }
    }

    # Refresh Folder list
    Write-Host "** Reloading Folder list`n"
    $folders = Search-TssFolder -TssSession $tsssession     
    $folderSpaces = $folders | Where-Object { $_.Foldername -ne $_.foldername.trim() }

    Write-Host "* Found $($Folderspaces.Count) Folders with whitespace`n"
}

if ($spaces.Count) {
    Write-Host "* Found $($spaces.Count) secrets with whitespace`n"
    foreach ($secret in $spaces) {
        try {
            $newName = $secret.Name.trim()
            Set-TssSecret -TssSession $tsssession -SecretName $newName -Id $secret.SecretId    
           
            Write-Host "Renamed Secret: [$($secret.FolderPath)\$($secret.Name)] to $newName"
        }
        Catch {
            Write-Error $_
            Write-Host "FAILED to rename Secret: $($secret.FolderPath)\$($secret.Name)"
            Start-Sleep -Seconds 5
        }
    }

    # Refresh Secret list
    Write-Host "** Reloading Secret list`n"
    
    $secrets = Search-TssSecret -TssSession $tsssession 
}

$duplicateNames = $secrets.Name | Sort-Object | Group-Object | Where-Object Count -GT 1 | Select-Object -ExpandProperty Name
$duplicateSecrets = $secrets | Where-Object { $_.name -in $duplicateNames } | Select-Object SecretName, SecretId, folderPath
Write-Host "* Found $($duplicatesecrets.count) duplicate secrets`n"
Write-Host "** Updating Personal Folder Secrets`n"
$duplicateSecrets | Where-Object { $_.folderpath -like "\Personal Folder*" } | ForEach-Object {
    try {
        Set-TssSecret -TssSession $tsssession -SecretName ($_.secretname + " (" + ($_.folderpath -split "\\")[2] + ")") -Id $_.SecretId
        Write-Host ("Secret: " + ($_.folderpath, $_.secretname -join "\\") + " [" + $_.SecretId + "] Renamed " + ($_.secretname + " (" + ($_.folderpath -split "\\")[2] + ")")) 
    }
    Catch {
        Write-Error $_
        Write-Host ("FAILED Secret: " + ($_.folderpath, $_.secretname -join "\\") + " [" + $_.SecretId + "]") 
        Start-Sleep -Seconds 5
    }
}
Write-Host "** Secondary processing`n"
$secrets = Search-TssSecret -TssSession $tsssession 
$duplicateNames = $secrets.Name | Sort-Object | Group-Object | Where-Object Count -GT 1 | Select-Object -ExpandProperty Name
$duplicateSecrets = $secrets | Where-Object { $_.name -in $duplicateNames } | Select-Object SecretName, SecretId, folderPath
Write-Host "* Found $($duplicatesecrets.count) duplicate secrets`n"
foreach ($secretname in $duplicateNames) {
    $index = 0..($duplicateSecrets.Count - 1) | Where-Object { $duplicateSecrets[$_].secretname -eq $secretname }
    $count = 0 
    foreach ($item in $index) {
        if ($count -eq 0 ) { 
            $newname = $duplicateSecrets[$item].secretname 
        }
        else { 
            $newname = $duplicateSecrets[$item].secretname + " ($count)" 
        }
        try {
            if ($count -ne 0 ) {
                Set-TssSecret -TssSession $tsssession -SecretName $newname -Id $duplicateSecrets[$item].secretid
                Write-Host ("Secret: " + ($duplicateSecrets[$item].folderpath, $duplicateSecrets[$item].secretname -join "\\") + " [" + $duplicateSecrets[$item].SecretId + "] Renamed $newname") 
            }
            else { Write-Host ("Secret: " + ($duplicateSecrets[$item].folderpath, $duplicateSecrets[$item].secretname -join "\\") + " [" + $duplicateSecrets[$item].SecretId + "] Not updated as 1st instance of name") }
        }
        Catch {
            Write-Error $_
            Write-Host ("FAILED Secret: " + ($duplicateSecrets[$item].folderpath, $duplicateSecrets[$item].secretname -join "\\") + " [" + $duplicateSecrets[$item].SecretId + "]") 
            Start-Sleep -Seconds 5
        }
        $count++
    }
}