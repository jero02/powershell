############################################################################################################
    <#.Description
    
    Söker efter en eller flera datorer i SCCM+AD. 
    För att söka på flera datorer samtidigt: separera datornamnen med komma(,) eller semikolon(;)

    Resultatet visar senast inloggad användare, datum, nätverkssite, operativsystem, IP-adress m.m.
    #>
############################################################################################################

function ResultList{
  
      if ($resultCM) {
       $resultCM | Select-Object @{n="Dator";e={$_.Name}},
                @{n="Senast inloggad anv";e={$_.LastLogonUser}},
                @{n="Nuvarande anv";e={$_.CurrentLogonUser}},
                @{n="Senast inloggad tid";e={$_.ADLastLogonTime}},
                @{n="Senast tid aktiv";e={$_.LastActiveTime}},
                @{n="Nätverkssite";e={$_.ADSiteName}}                  
       $resultAD | Select-Object @{n="OU";e={$_.CanonicalName}},
                @{n="Operativsystem";e={$_.OperatingSystem}},
                @{n="IP-adress";e={$_.IPv4Address}},
                @{n="Senast inloggad tid";e={$_.LastLogonDate}}
     $resultUser | Select-Object @{n="Senast inloggad användares namn";e={"$($resultUser.split("-")[0])"}}
    $resultUser2 | Select-Object @{n="Nuvarande inloggad användares namn";e={"$($resultUser2.split("-")[0])"}}

    }        
    
    elseif (-not $resultCM -and $resultAD) {"Hittade ej dator $Computer i sccm, info från AD:"
       $resultAD | Select-Object @{n="OU";e={$_.CanonicalName}},
                @{n="Operativsystem";e={$_.OperatingSystem}},
                @{n="IP-adress";e={$_.IPv4Address}},
                @{n="Senast inloggad tid";e={$_.LastLogonDate}}

    }   

    else {"Hittade ej $Computer i sccm eller AD."}

}


    #Testa sökväg till sccm och importera modulen
    $sccmPath1 = Test-Path "C:\Program Files (x86)\ConfigurationManager\Console\bin"
    $sccmPath2 = Test-Path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin"
    
        if ($sccmPath1) {Set-Location "C:\Program Files (x86)\ConfigurationManager\Console\bin"}
        elseif ($sccmPath2) {Set-Location "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin"}
        else {Write-Host -ForegroundColor White -BackgroundColor Red 'Försökte importera sccm-modulen men misslyckades, är sccm installerat på datorn? Avslutar.';Start-Sleep -Seconds 10;break}    
    
        Import-Module .\ConfigurationManager.psd1
        New-PSDrive -Name [sccmSite] -PSProvider "AdminUI.PS.Provider\CMSite" -Root "server-sccm.domain.local" -Description "SCCM Site"
        Set-Location sccmSite:


    #starta loop
    $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&J","&N")
    while ( $true ) {

    Write-Host 'För att söka på flera datorer, separera datornamnen med , eller ; '
    $ComputerArray = (Read-Host 'Datornamn').Split(","";") -replace "\s"

        Foreach($Computer in $ComputerArray) {
    
        #Sök i sccm och AD efter datornanm
        $resultCM = try {Get-CMDevice -Name $Computer | Select-Object -Property Name, LastLogonUser, CurrentLogonUser, ADLastLogonTime, LastActiveTime, ADSiteName} catch {}
        $resultAD = try {Get-ADComputer "$($Computer)" -Properties *  -Server "domain.local" | Select-Object -Property CanonicalName, OperatingSystem, IPv4Address, LastLogonDate} catch {}

        #Sök efter senast inloggad användare, exkludera användarnamnet (visas redan i $resultCM)
        $resultUser = try {(Get-ADUser -Server "server.local" ($resultCM.LastLogonUser)).name} catch {'fick ej träff på lastlogonuser'}
        $resultUser2 = try {(Get-ADUser -Server "server.local" ($ResultCM.CurrentLogonUser.split("\")[-1])).name} catch {'fick ej träff på currentlogonuser'}

        #Visa resultat
        ResultList
    
        }
        
        Clear-Variable resultCM,resultAD,resultUser,resultUser2

    $choice = $Host.UI.PromptForChoice("Sök efter en till dator?","",$choices,0); if ( $choice -ne 0 ) 
    
    {Set-Location C:\; break}

}