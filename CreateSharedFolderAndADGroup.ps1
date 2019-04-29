##############################################################################################################
    <#  .Description
    1. Create folder, inheritance disabled. 
    2. Create AD group
    3. Add users to the group (optional)

    After folder and group is creates, access rights are set for the group (read+write).                       
    #>   
##############################################################################################################


function setFolderAccessRights {

    #20 sec paus to avoid IdentityNotMappedException
    "Väntar 20 sekunder innan vi tilldelar gruppen skrivrättighet på mappen (annars hinner den inte hitta gruppen).."
    Start-Sleep -Seconds 20
    $readWrite = [System.Security.AccessControl.FileSystemRights]4,2,64,32,1,131209,131241,128,8,131072,1048576,278,256,16
    #Inheritance
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    #Propagation
    $propagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    #User
    $userRW = New-Object System.Security.Principal.NTAccount($groupName)
    #Type
    $type = [System.Security.AccessControl.AccessControlType]::Allow
    $accessControlEntry = New-Object System.Security.AccessControl.FileSystemAccessRule @($userRW, $readWrite, $inheritanceFlag, $propagationFlag, $type)
    $objACL = Get-ACL $newFolderFull
            
    #add rule on folder
    $objACL.AddAccessRule($accessControlEntry)
    Set-ACL $newFolderFull $objACL

    Write-Host -ForegroundColor White -BackgroundColor DarkGreen "Skapat mapp $newFolderFull och grupp $groupName samt tilldelat behörighet, kontrollera att mapp+grupp+behörigheter blivit korrekta. Avslutar."
    Start-Sleep -Seconds 7
}

    #Reminder to open powershell as admin before starting script
    Write-Host -ForegroundColor White -BackgroundColor Red "Öppna powershell som administratör innan du startar detta skript."
  
        #ask for path
        $path = Read-Host "Fyll i sökväg där mappen ska ligga t.ex. \\server\Shared\Folder"
        $newFolderName = Read-Host "Skriv mappens namn"
        $newFolderFull = $path + "\" + $newFolderName
        $folderExists = Test-Path $newFolderFull
        $userNameADM = "admin-"+$env:USERNAME.Split("-")[-1]
    
    #check if path exists
    if ($folderExists -eq $true)
        {"$newfolderFull verkar redan finnas, kontrollera sökvägen innan du kör skriptet igen, avslutar."; Start-Sleep -Seconds 10 ; break}
    
        #display new path, ask for confirmation
        else {"Den nya mappen kommer bli: $newFolderFull"; $confirm = Read-Host "Stämmer sökvägen, gå vidare? J/N"}

    if ($confirm -ne "J") 
        {'Kör skriptet igen när du är helt säker på sökväg/mappnamn, avslutar.'; Start-Sleep -Seconds 10 ; break}

    #confirmed, disable inheritance
    if ($confirm -eq "J" -and $folderExists -eq $false) 
        {"Skapar mapp.."; New-Item $newFolderFull -ItemType Directory
        "Inaktiverar ärvda behörigheter.."
        icacls $newFolderFull /inheritance:d
        
        #ask for group             
        $groupName = Read-Host "Fyll i vad behörighetsgruppen ska heta, när du trycker enter får du fylla i lösenord för adm-kontot och sen skapas gruppen"
        #login with admin account
        $cred = Get-Credential -Message "Logga in med adm-konto för att skapa AD-grupp" -UserName $userNameADM
        
        #create group and set description and info
        New-AdGroup -Server "DOMAIN.local" $groupName -samAccountName $groupName -GroupScope Global -path "OU=insertOUhere,OU=insertOUhere,OU=insertOUhere,DC=insertOUhere,DC=local" -Description $newFolderFull -OtherAttributes @{info="Skrivrättighet på $newFolderFull"} -Credential $cred}
    
    #if group creation failed, quit    
    if ($? -eq $false) 
        {'Misslyckades att skapa gruppen i AD, skapa grupp och sätt behörigheterna manuellt på mappen om det behövs, avslutar.'; break}
    
        else {$addMembers = Read-Host "Vill du lägga till medlemmar i $groupName (J/N)?"}
   
    #add members to group?
    if ($addMembers -eq "J") {try {'Fyll i användarnamn ett åt gången, när du är klar tryck enter en gång utan att fylla i användarnamn för att gå vidare'
        Add-ADGroupMember -Server "DOMAIN.local" -Identity $groupName -Credential $cred} catch {Write-Host -ForegroundColor White -BackgroundColor Red "Något blev fel när medlemmarna skulle läggas till i gruppen."}
        
        #set rights
        setFolderAccessRights; break}

        else {setFolderAccessRights; break}