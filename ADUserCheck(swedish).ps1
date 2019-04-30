#####################################################################################################
    <# .Description
    Söker efter användare i AD på användarnamn eller personnummer. Personnummer kan vara i format
    10, 12, 6-4 eller 8-4 siffror, om fel antal siffror får du en notis (försök igen)
    
    Kontrollerar om:

    - kontot är aktivt/inaktivt, eller om kontot är aktivt men slutdatum passerat (röd notis)
    
    - lösenordet är giltigt, gått ut (röd notis), tillfälligt, eller om 'lösenordet går aldrig ut'
      är aktiverat (notis 'warning').
    
    - target/smtp stämmer eller ej, om den är felaktig/saknas får du välja att korrigera eller ej
      (inloggningsruta för adm-konto vid val 'J'). Vid val 'J' ersätts target och en sekundär smtp
      läggs till i proxyaddresses. Den nya target/smtp baseras på användarens UPN.
    
    Resultatet visar:
    
    - lista med Användarnamn, OU, UPN, Telefon, kostnadsställe, förvaltning, chef, 
      msExchHideFromAddressLists, kontostatus, slutdatum, lösenord senast ändrat, lösenordets status. 

    - om targetaddress matchar med smtp, samt listar target och alla smtp i proxyaddresses
    #>
#####################################################################################################

Import-Module ActiveDirectory

function AccountStatus {                             
          
    #konto aktivt och accountexpires 0 (never) = aktivt
    if ($anv.Enabled -eq $true -and $anv.accountExpires -eq 0)        
        {$Script:accountStatus = "Aktivt"}

        #konto aktivt och accountexpires 9223372036854775807
        elseif  ($anv.Enabled -eq $true -and $anv.accountExpires -eq 9223372036854775807)
               {$Script:accountStatus = "Aktivt"}

        #konto aktivt och accountexpires ej 9223372036854775807
        elseif ($anv.Enabled -eq $true -and $anv.accountExpires -ne 9223372036854775807)
            
            {    
            #nästlad IF, kolla om slutdatum ej passerat, konto aktivt
            if ([datetime]::FromFileTime($anv.accountExpires) -gt (Get-Date)) 
            {$Script:accountStatus = "Aktivt"}
            
            #datum har gått ut = inaktivt         
            elseif ([datetime]::FromFileTime($anv.accountExpires) -lt (Get-Date))
            {$Script:accountStatus = "Inaktivt"}
            }
                                        
    #konto inaktivt
    else {$Script:accountStatus = "Inaktivt"}
            
 }

function NormaliseraSvar {
    
   
    #exakt 12
    if ($svar -match '^\d{12}$') {$Script:svarFixat = $svar}

    #exakt 10, första siffra 0
    elseif ($svar -match '^\d{10}$' -and $svar[0] -eq '0') {$Script:svarFixat = '20'+$svar}

    #exakt 10, första siffra >0
    elseif ($svar -match '^\d{10}$' -and $svar[0] -gt '0') {$Script:svarFixat = '19'+$svar}

    #8-4
    elseif ($svar -match '^\d{8}-\d{4}$') {$Script:svarFixat = $svar -Replace('-')}

    #6-4 första siffra 0
    elseif ($svar -match '^\d{6}-\d{4}$' -and $svar[0] -eq '0') {$Script:svarFixat = '20'+$svar -Replace('-')}

    #6-4 första siffra >0
    elseif ($svar -match '^\d{6}-\d{4}$' -and $svar[0] -gt '0') {$Script:svarFixat = '19'+$svar -Replace('-')}

}

function PasswordExpiredCheck { 

    if ($anv.PasswordLastSet.AddDays(91) -le (get-date) -and $anv.UserAccountControl -ne 66048)                        
        {Write-Host -ForegroundColor White -BackgroundColor Red "Användarens lösenord verkar ha gått ut $($anv.PasswordLastSet.AddDays(91).ToString("yyyy-MM-dd kl HH:mm")) "}

        elseif ($anv.UserAccountControl -eq 66048)                        
            {Write-Warning "Användaren har 'Lösenordet går aldrig ut' aktiverat."}
        
            else {"Kontots lösenord är giltigt till $($anv.PasswordLastSet.AddDays(91).ToString("dddd dd MMMM kl HH:mm"))"}
}

#kontrollera om target stämmer samt matchas med smtp, visa target och smtp:s      
function RoutingAddressCheck {

    if ($anv.ProxyAddresses -contains $anv.TargetAddress -and $anv.TargetAddress -like '*@domain.mail.onmicrosoft.com')
        {"`n"
            Write-Host -BackgroundColor DarkGreen -ForegroundColor White 'TargetAddress och smtp matchar:'
                
            'TargetAddress: '; $anv.TargetAddress
            
            'smtp-adresser: '; $anv.ProxyAddresses -like 'smtp*'
            "`n"}
                        
        else {"`n"
            Write-Host -BackgroundColor Red -ForegroundColor White 'TargetAddress och smtp ser inte ut att matcha: '
                
            'TargetAddress: '; $anv.TargetAddress
            "`n"
            'smtp-adresser: '; $anv.ProxyAddresses -like 'smtp*'
            "`n"

            #Kör RoutingAddressFix för att ev. korrigera target+smtp
            RoutingAddressFix}
}


function RoutingAddressFix {
    
    #fråga om target+smtp ska korrigeras
    $newRoutingAddress = $anv.UserPrincipalName.Split('@')[0]+'@domain.mail.onmicrosoft.com'
    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Ändra TargetAddress+sekundär smtp till $newRoutingAddress på användare $($anv.SamAccountName) ? J/N :" -NoNewline
    $fixOrNot = Read-Host
      
        if ($fixOrNot -eq "J") {
        
        #prompt för adm-konto, ersätt target, lägg till sekundär smtp
        $cred = Get-Credential -Message "Logga in med admin-konto för att ändra target+smtp" -UserName "admin-$($env:USERNAME.Split('-')[-1])"
        Set-ADUser -Server "domain.local" $anv.SamAccountName -Replace @{targetaddress="SMTP:"+$newRoutingAddress} -Credential $cred
        Set-ADUser -Server "domain.local" $anv.SamAccountName -Add @{ProxyAddresses="smtp:"+$newRoutingAddress} -Credential $cred
        
            #om set-aduser lyckades, skriv ut vilken target och smtp som sattes
            if ($?) 
            {Write-Host -ForegroundColor White -BackgroundColor DarkGreen "Target+sekundär smtp ändrad till $newRoutingAddress på $($anv.SamAccountName), sök på kontot igen om du vill dubbelkolla."}

                else {"Misslyckades ändra smtp+target, fel lösenord?"}
            }
        
        else {'Ingen åtgärd.'}
}

#skriv om resultatet för enklare läsning
function userInfoList {

    $anvInfo = $anv | select Name,UserPrincipalName,Enabled,PasswordLastSet,ExtensionAttribute15,msExchHideFromAddressLists,DistinguishedName,Manager,telephoneNumber,Department;
    $anvInfo |
     select @{n="Användare";e={$_.Name}},
            @{n="OU";e={$_.DistinguishedName.Split('=,')[3,5,7] -join ","}},
            @{n="UPN";e={$_.UserPrincipalName}},
            @{n="Telefon";e={$_.telephoneNumber}},
            @{n="Kostnadsställe";e={$_.ExtensionAttribute15}},
            @{n="Förvaltning";e={$_.Department}},
            @{n="Chef";e={$_.Manager.Split('-')[0] -replace 'CN='}},
            @{n="msExchHideFromAddressLists";e={$_.msExchHideFromAddressLists}},
            @{n="Kontostatus";e={$accountStatus}},
            @{n="Slutdatum";e={if($anv.accountExpires -eq 0) {'Aldrig'} elseif($anv.accountExpires  -eq 9223372036854775807) {'Aldrig'} else {[datetime]::FromFileTime($anv.accountExpires)}}},
            @{n="Lösenord senast ändrat";e={$_.PasswordLastSet}} | Format-List
}


    ######################################## start skript: ########################################
            
    $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&J","&N"); while ( $true ) 
{

    $svar = (Read-Host "Användarnamn eller personnummer") -replace "\s"
          
    #om svar ej är endast siffror eller siffror-siffror          
    if ($svar -notmatch "^[\d]+\-?[\d]+$")

    { 

    $anv = try {Get-ADUser -Server "domain.local" -Identity $svar -Properties ExtensionAttribute15,msExchHideFromAddressLists,PasswordLastSet,PwdLastSet,Manager,ProxyAddresses,TargetAddress,telephoneNumber,userAccountControl,accountExpires,Department}
            catch {'Fail'}
        
        if ($anv -eq {Fail})        
         {Write-Host "Ingen träff på $svar, kontrollera användarnamnet (och att du har kontakt med AD)"}
        
        else {
        #kontrollera kontostatus
        AccountStatus

        #resultat:       
        #inaktivt, visa info, skippa övriga                                         
        if ($accountStatus -eq "Inaktivt")         
        {userInfoList;  Write-Host -ForegroundColor White -BackgroundColor Red "Användarkontot ser ut att vara inaktivt, kontrollera slutdatum och kontostatus i AD."}
        
        #aktivt men har tillfälligt lösenord, skippa passwordcheck         
        elseif ($accountStatus -eq "Aktivt" -and $anv.PwdLastSet -eq 0)
            
        {userInfoList; Write-Host "Kontot är aktivt men har ett tillfälligt lösenord.";  RoutingAddressCheck}
            
        #aktivt och har ej tillfälligt lösenord
        elseif ($accountStatus -eq "Aktivt" -and $anv.PwdLastSet -ne 0)
            
        {userInfoList; PasswordExpiredCheck; RoutingAddressCheck}

        }
            
    }

        #om svar är siffror eller siffror-siffror                  
        else 
    
        {        

            if ($svar -notmatch '^(\d{10}|\d{12}|\d{8}-\d{4}|\d{6}-\d{4})$')
            {"Fel, $svar är $(($svar -Replace('-')).Length) tecken, personnummer måste skrivas: YYYYMMDDXXXX, YYMMDDXXXX, YYYYMMDD-XXXX, eller YYMMDD-XXXX."}
            
            
            #svar är exakt 10, 12, eller 8-4, 6-4
            elseif ($svar -match '^(\d{10}|\d{12}|\d{8}-\d{4}|\d{6}-\d{4})$')
            {
              NormaliseraSvar                      
              $anv = Get-ADUser -filter "serialnumber -eq $svarFixat" -Server "domain.local" -Properties ExtensionAttribute15,msExchHideFromAddressLists,PasswordLastSet,PwdLastSet,Manager,ProxyAddresses,TargetAddress,telephoneNumber,userAccountControl,accountExpires,Department -ErrorAction Stop
                    
                        
                if ($anv -eq $null) {"Ingen träff på personnummer $svarFixat";"`n"}
                        
                elseif ($anv -ne $null)
                {
                AccountStatus

                #resultat:                       
                #inaktivt, visa info, skippa övriga                                         
                if ($accountStatus -eq "Inaktivt")         
                {userInfoList; Write-Host -ForegroundColor White -BackgroundColor Red "Användarkontot ser ut att vara inaktiverat, kontrollera slutdatum och kontostatus i AD."}
        
                #aktivt men har tillfälligt lösenord, skippa passwordcheck         
                elseif ($accountStatus -eq "Aktivt" -and $anv.PwdLastSet -eq 0)
            
                {userInfoList; Write-Host "Kontot är aktivt men har ett tillfälligt lösenord."; RoutingAddressCheck}
            
                #aktivt och har ej tillfälligt lösenord
                elseif ($accountStatus -eq "Aktivt" -and $anv.PwdLastSet -ne 0)
            
                {userInfoList; PasswordExpiredCheck; RoutingAddressCheck}
                }
                                          
        }
    }

     $choice = $Host.UI.PromptForChoice("Sök en gång till?","",$choices,0); if ($choice -ne 0) {break}
}
