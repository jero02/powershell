########################################################################################
    <#  .Description
    Change OU path and -server to match your environment. 

    1. Create folder, inheritance disabled. 
    2. Create AD group
    3. Add users to the group (optional)

    After folder and group is created, access rights are set for the group (read+write).                       
    #>   
########################################################################################

function setFolderAccessRights {

    #20 sec paus to avoid IdentityNotMappedException
    "Wait 20 seconds before applying access rights to avoid problems.."
    Start-Sleep -Seconds 20

    #for info about FileSystemRights Enum go to https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=netframework-4.8 

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

    Write-Host -ForegroundColor White -BackgroundColor DarkGreen "Folder $newFolderFull and group $groupName created with read-write access, always double check folder/group/rights has been created as expected. Quit in 10 sec.."
    Start-Sleep -Seconds 15
}

    #Reminder to open powershell as admin before starting script
    Write-Host -ForegroundColor White -BackgroundColor Red "Open powershell as Administrator before running this script."
  
        #ask for path
        $path = Read-Host "Path where the new folder will be created, example: \\server\Shared\Folder"
        $newFolderName = Read-Host "New folder name"
        $newFolderFull = $path + "\" + $newFolderName
        $folderExists = Test-Path $newFolderFull
        $userNameADM = "admin-"+$env:USERNAME.Split("-")[-1]
    
    #check if path exists
    if ($folderExists -eq $true)
        {"$newfolderFull already exists, verify the path/new folder name before running script, quitting.."; Start-Sleep -Seconds 10 ; break}
    
        #display new path, ask for confirmation
        else {"New folder will be: $newFolderFull"; $confirm = Read-Host "Is the new path correct, continue? Y/N"}

    if ($confirm -ne "Y") 
        {'Quitting script..'; Start-Sleep -Seconds 10 ; break}

    #confirmed, disable inheritance
    if ($confirm -eq "Y" -and $folderExists -eq $false) 
        {"Creating folder.."; New-Item $newFolderFull -ItemType Directory
        "Disabling inheritance.."
        icacls $newFolderFull /inheritance:d
        
        #ask for group             
        $groupName = Read-Host "Enter new group name and press enter, then log in with admin account to create the group"
        #login with admin account
        $cred = Get-Credential -Message "Log in with admin account to create group" -UserName $userNameADM
        
        #create group and set description and info
        New-AdGroup -Server "DOMAIN?.local" $groupName -samAccountName $groupName -GroupScope Global -path "OU=insertOUhere,OU=insertOUhere,DC=insertDomain,DC=local" -Description $newFolderFull -OtherAttributes @{info="Read+Write access on folder $newFolderFull"} -Credential $cred}
    
    #if group creation failed, quit    
    if ($? -eq $false) 
        {'Failed to create AD group, handle access rights manually, quitting..'; Start-Sleep -Seconds 10 ; break}
    
        else {$addMembers = Read-Host "Add members to $groupName (Y/N)?"}
   
    #add members to group?
    if ($addMembers -eq "Y") {try {'Enter username one at a time, when finished press enter without entering username'
        Add-ADGroupMember -Server "DOMAIN?.local" -Identity $groupName -Credential $cred} catch {Write-Host -ForegroundColor White -BackgroundColor Red "Something went wrong when adding users to the group."}
        
        #set rights
        setFolderAccessRights; break}

        else {setFolderAccessRights; break}
