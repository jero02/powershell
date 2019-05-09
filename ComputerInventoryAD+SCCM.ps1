<# .Description

    Search for computers that hasn't logged in for x days.

    1. Import AD and SCCM
    2. Search in AD for computers
    3. Search in SCCM for computers
    4. Search in AD for last logged on users

    Result: pscustomobject containing computer info/lastlogontime etc and info about users
#>

Import-Module ActiveDirectory
    
$sccmPath1 = Test-Path "C:\Program Files (x86)\ConfigurationManager\Console\bin"
$sccmPath2 = Test-Path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin"
    
    if ($sccmPath1) {Set-Location "C:\Program Files (x86)\ConfigurationManager\Console\bin"
        
        } elseif ($sccmPath2) {Set-Location "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin"
        
        } else {Write-Host -ForegroundColor White -BackgroundColor Red 'Failed to import sccm module, quitting.';Start-Sleep -Seconds 10;break}    
    
Import-Module .\ConfigurationManager.psd1
New-PSDrive -Name [Site] -PSProvider "AdminUI.PS.Provider\CMSite" -Root "sccmserver.domain.local" -Description "SCCM Site"
Set-Location Site:
    
do {
[string]$ouInput = Read-Host "Which OU do you want to search?"[int]$daysInput = Read-Host "Days since the computers last logged in to AD"$dateResult = (Get-Date).AddDays("-"+$daysInput)
$date = (get-date).ToString("yyyy-MM-dd")
$computers = Get-ADComputer -Server "domain.local" -Filter 'LastLogonDate -lt $dateResult' -SearchBase "OU=Datorer,OU=$ouInput,OU=Adm,DC=domain,DC=local" -Properties CanonicalName,Enabled,LastLogonDate,WhenCreated

 
#to do: switch CM adlastlogontime for AD lastlogondate
$Data = $computers.name | foreach {
        
$Name = $_; $CMDevice = Get-CMDevice -Name $_

    if($cmdevice -and $CMDevice.LastLogonUser) {
        [pscustomobject]@{Name=$Name;LastLoggedIn=$CMDevice.ADLastLogonTime;LastActive=$CMDevice.LastActiveTime;ADSiteName=$CMDevice.AdSiteName;LastLogonUser=$CMDevice.LastLogonUser}            
            
        } elseif ($CMDevice -and !$CMDevice.LastLogonUser) {
            [pscustomobject]@{Name=$Name;LastLoggedIn=$CMDevice.ADLastLogonTime;LastActive=$CMDevice.LastActiveTime;ADSiteName=$CMDevice.ADSiteName;LastLogonUser=$CMDevice.LastLogonUser}       
            
        } else {
            [pscustomobject]@{Name=$Name;LastLoggedIn=$CMDevice.ADLastLogonTime;LastActive=$CMDevice.LastActiveTime;ADSiteName=$CMDevice.ADSiteName;LastLogonUser=$CMDevice.LastLogonUser}    
    }
}               
                                                                            
$DataResult = $Data | foreach {

$ADuser = try {Get-ADUser -Server "domain.local" -Identity $_.LastLogonUser -Properties * | Select-Object displayName,UserPrincipalName,MobilePhone,telephoneNumber,Title,Manager} 
            catch {}

        [pscustomobject]@{
        Computer=$_.name
        LastLoggedIn=$_.LastLoggedIn
        LastActive=$_.LastActive 
        NetworkSite=$_.AdSiteName
        User=$_.LastLogonUser
        Name=$ADuser.displayName
        Email=$ADuser.UserPrincipalName
        Phone=$ADuser.telephoneNumber
        Mobile=$ADuser.MobilePhone
        Title=$ADuser.Title
        Manager=try {$($ADuser.Manager.Split("="" - ")[1,2] -join " ")} catch {}
        }
}

Write-Host -ForegroundColor White -BackgroundColor DarkGreen "Found $(@($DataResult).count) computers, choose:"
Write-Host "1. Save result in a csv file ( $("$env:USERPROFILE\$ouInput$date.csv") )"
Write-Host "2. Show result in console (might not see all columns)"
$resultChoice = Read-Host
                
    switch ($resultChoice) {
    1 {$DataResult | sort "LastActive" | Export-Csv -Encoding UTF8 -Delimiter ";" -NoTypeInformation -NoClobber -Path $env:USERPROFILE\$ouInput$date.csv;
         Write-Host "Result saved in $env:USERPROFILE\$ouInput$date.csv"}
    2 {$DataResult | Format-Table *}                   
    }

$oneMore = Read-Host "Type Y to search one more time, N to quit" 

} while ($oneMore -eq 'J')