<#

    .SYNOPSIS

    This script processes new users in a domain. It retrieves metadata from an LDAP server, moves the user to appropriate groups, creates a home directory and share, and moves the user to the appropriate OU.

    .DESCRIPTION

    This script is generalized as-is but it should be customized alongside an XML file (which would be accessible only to Domain Admins, ideally). This script requires the ActiveDirectory module be available and Powershell remoting must be enabled on your storage server. Written by Michael Brady.
    
    .PARAMETER XMLpath

    This is an optional parameter in lieu of providing the XML path in the script.

    .EXAMPLE

    .\New-DomainUsers.ps1 \\CONTOSO\newusers.xml

    New users will be configured based on the xml specified.

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=1)]
            [string]$XMLpath
        )
    

If ((Get-Module).Name -notcontains "ActiveDirectory") {
    If ((Get-Module -ListAvailable).Name -contains "ActiveDirectory") { Import-Module ActiveDirectory }
        Else { Throw "You must have the Active Directory Powershell module loaded to proceed. You may need to install RSAT for your version of Windows." }
    }

$admincredentials = (Get-Credential -Message 'Type Domain Admin Credentials') 

[xml]$XMLpath = [xml](Get-Content -Path "")

# Import variables from XML
$ConnectionString = $XMLPath.NewUserInfo.metapeople.connectionstring
$SelectFields = $XMLPath.NewUserInfo.metapeople.selectfields
$LDAPServer = "`'" + $XMLPath.NewUserInfo.metapeople.ldapserver + "`'"
$Queryfield = $XMLPath.NewUserinfo.metapeople.queryfield

$ADserver = $XMLpath.NewUserInfo.ADoperations.adserver
$InboundOU = $XMLpath.NewUserInfo.ADoperations.inboundou
$universalgroups = $XMLpath.NewUserInfo.ADoperations.universalgroups
$Allstaffgroups = $XMLpath.NewUserInfo.ADoperations.allstaffgroups
$fgroup = $XMLpath.NewUserInfo.ADoperations.fgroup
$mgroup =  $XMLpath.NewUserInfo.ADoperations.mgroup
$pgroup =  $XMLpath.NewUserInfo.ADoperations.pgroup
$studentgroups = $XMLpath.NewUserInfo.ADoperations.studentgroups
$movedou = $XMLpath.NewUserInfo.ADoperations.movedou

$homelocation1 = $XMLpath.NewUserInfo.homeandlogon.homelocation1
$homelocation2 = $XMLpath.NewUserInfo.homeandlogon.homelocation2
$homedrive = $XMLpath.NewUserInfo.homeandlogon.homedrive
$homeshare = $XMLpath.NewUserInfo.homeandlogon.homeshare
$storageserver = $XMLpath.NewUserInfo.homeandlogon.storageserver
$sharegroups = $XMLpath.NewUserInfo.homeandlogon.sharegroups
$logonscript = $XMLpath.NewUserInfo.homeandlogon.logonscript
$useraccountcontrol =  $XMLpath.NewUserInfo.homeandlogon.useraccountcontrol

$UserIDs = (Get-Adobject -SearchBase  "$InboundOU" -Filter { objectClass -eq "user" } -server $ADserver ).Name

$ADConnection = New-Object -ComObject "ADODB.Connection"
$ADRecordSet = New-Object -ComObject "ADODB.Recordset"

Foreach ($UserID in $UserIDs) {
    # Connecting to the metapeople LDAP instance
    $ADConnection.Open($ConnectionString)
    $QueryString = "$Queryfield=`'$UserID`'"
    $ADRecordSet.Open("SELECT $Selectfields FROM $LDAPServer WHERE $QueryString", $ADConnection, 3, 3)

    If (-Not($AdRecordSet.RecordCount -eq 1)) {
        Throw "Retrieving records from metapeople server failed. Exiting script."
        }

    If (($ADRecordSet.Fields.Item(2).Value).EndsWith(1)) {
        $Placement = "Staff"
            If (($ADRecordSet.Fields.Item(1).Value).StartsWith("F")) {
                 $JobCode = "F"
                 }
                ElseIf (($ADRecordSet.Fields.Item(1).Value).StartsWith("P")) {
                    $JobCode = "P"
                    }
                ElseIf (($ADRecordSet.Fields.Item(1).Value).StartsWith("G")) {
                    $JobCode = "M"
                    }
        }
        ElseIf (($ADRecordSet.Fields.Item(2).Value).EndsWith(2)) {
            $Placement = "Student"
            }
     $ADRecordSet.Close()
     $ADConnection.Close()
     $Userobject = (Get-Aduser $userid -server $ADserver -properties scriptpath,homedirectory,homedrive,useraccountcontrol)
     Foreach ($group in ($universalgroups).value) {
         If (-Not(Get-Adgroupmember -Identity $group).Name -like "$UserId") {
              Add-ADGroupMember -Identity $group -Members $userobject -Credential $admincredentials
              }
        $group = ""
        }
      If ($Placement -eq "Staff") {
            Write-Verbose "$UserID is staff."
            Foreach ($group in ($Allstaffgroups).Value) {
                 If (-Not(Get-Adgroupmember -Identity $group).Name -like "$UserId") {
                    Add-ADGroupMember -Identity $group -Members $userobject -Credential $admincredentials
                    }
                $group = ""
              }
            Switch ($JobCode) {
                "F" { 
                    If (-Not(Get-Adgroupmember -Identity $fgroup).Name -like "$UserId") {
                        Add-ADGroupMember -Identity $fgroup -Members $userobject -Credential $admincredentials
                        }
                    break
                    }
                "M" { 
                    If (-Not(Get-Adgroupmember -Identity $mgroup).Name -like "$UserId") {
                        Add-ADGroupMember -Identity $mgroup -Members $userobject -Credential $admincredentials
                        }
                    break
                    }
                "P" { 
                    If (-Not(Get-Adgroupmember -Identity $pgroup).Name -like "$UserId") {
                        Add-ADGroupMember -Identity $pgroup -Members $userobject -Credential $admincredentials
                        }
                    break
                    }
                }
              # Editing AD user information
              Set-ADUser -Identity $userobject -scriptpath $logonscript -Server $ADserver -Credential $admincredentials
              Set-ADUser -Identity $userobject -HomeDirectory "$homeshare\$userid" -server $ADserver  -Credential $admincredentials
              Set-ADUser -Identity $userobject -Homedrive $homedrive -server $ADserver  -Credential $admincredentials
        }
        If ($Placement -eq "Student") {
            Write-Verbose "$UserID is a student."
            Foreach ($group in ($studentgroups).Value) {
                If (-Not(Get-Adgroupmember -Identity $group).Name -like "$UserId") {
                    Add-ADGroupMember -Identity $group -Members $userobject -Credential $admincredentials
                    }
                $group = ""
            }
        }
    
    # Creating and sharing home directories is difficult/impossible in pure Powershell, use other tools for now over a Remote PSSession. I recommend keeping a script on the storage server and use cacls and net share for simplicity.
    If ((-Not(Test-Path "$homelocation1\$UserId")) -and (-Not(Test-Path "$homelocation2\$UserId"))) {
        Write-Verbose "Home directory doesn't exist, creating and sharing it."
        If ($storageserver -like $env:COMPUTERNAME) {
                Start-Process "C:\Scripts\createnewshare.bat" "$UserId" | Wait-Process 200
                $Sharestatus = Get-WmiObject -Class Win32_Share | Where-Object {$_.Name -eq "$UserId" }
                    If (-Not($Sharestatus -eq $null)) {
                        Write-Verbose "Share Created."
                        }
                        Else {
                            Write-Error "Share doesn't seem to have been created. Please verify manually."
                            }
           }
           Else {
                $Storagesession = New-PSSession -ComputerName $storageserver -Credential $admincredentials
                Enter-PSSession -Session $Storagesession
                Start-Process "C:\Scripts\createnewshare.bat" "$UserId" | Wait-Process 200
                $Sharestatus = Get-WmiObject -Class Win32_Share | Where-Object {$_.Name -eq "$UserId" }
                If (-Not($Sharestatus -eq $null)) {
                    Write-Verbose "Share Created."
                    }
                    Else {
                        Write-Error "Share doesn't seem to have been created. Please verify manually."
                        }
                Exit-PSSession
                Remove-PSSession $Storagesession
                } 
            }
            Else {
                Write-Verbose "Home directory already exists."
                }
        #Finally, move the user to the OU it belongs in
        Move-ADObject -Identity $Userobject -TargetPath $movedou -server $adserver -Credential $admincredentials
        $UserId = ""
        
    }
$UserIDs = ""
