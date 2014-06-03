<#

    .SYNOPSIS

    This script retrieves a custom object containing the groups, members of the groups, and standalone users that are specified in the ACLs of a folder as well as inheritance information and access level.

    .DESCRIPTION

    The script uses Get-ACL and Get-AD* cmdlets to retrieve and bring together information regarding who exactly has access to a folder. It can also be used recursively or exclude inherited permissions as well as Domain Admins which are expected to have access to everything. This script is dependent upon the ActiveDirectory module. Written by Michael Brady.

    .PARAMETER Recurse

    This parameter sets the script to iterate through all child folders and also report the access information on those.

    .PARAMETER ExcludeDA

    This parameter excludes Domain Admins groups from output.

    .PARAMETER OnlyUninherited

    This parameter excludes all permission sets that are deemed to be inherited from a parent. 

    .EXAMPLE

    .\Get-FolderUsers.ps1 C:\windows\system32 -Recurse -OnlyUninherited

    Retrieves only uninherited permissions from all folders in the C:\windows\system32 tree.

    .EXAMPLE

    .\Get-FolderUsers.ps1 C:\Users\Public\Documents

    Retrieve all permissions information from the C:\Users\Public\Documents

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
            [string]$Path,
        [switch]$Recurse,
        [switch]$ExcludeDA,
        [switch]$OnlyUninherited
        )
        
If (-Not (Test-Path $Path)) {
    Throw "You must enter a valid path. Please check the input and try again."
    }

If ((Get-Module).Name -notcontains "ActiveDirectory") {
    If ((Get-Module -ListAvailable).Name -contains "ActiveDirectory") { Import-Module ActiveDirectory }
        Else { Throw "You must have the Active Directory Powershell module loaded to proceed. You may need to install RSAT for your version of Windows." }
    }

#By default, Powershell does not display enough output for property values in an array. This sets that number higher.    
$global:FormatEnumerationLimit = 50

$ACLS = ""
$Directories=""

$Directories = @($Path)
If ($Recurse.IsPresent ) {
    $RecurseDirList = (Get-ChildItem -Path $Path -Recurse -Directory).FullName
    $Directories = $Directories + $RecurseDirList
     }
Foreach ($Directory in $directories) {
    $ACLS = Get-ACL -Path $Directory | Select-Object -ExpandProperty Access
    Write-Output "********************************`n$Directory"
    Foreach ($ACL in $ACLS) {
        # Exclude obvious local accounts and groups from AD lookup
        If (($ACL.IdentityReference  -notlike "NT AUTHORITY*") -and ($ACL.IdentityReference -notlike "BUILTIN*") -and ($ACL.IdentityReference -notlike "CREATOR OWNER") ) {
        $GroupName =  Split-Path $ACL.IdentityReference -leaf
        $DomainName = Split-Path $ACL.IdentityReference
            # Determine if the specified object is a group or not by querying AD
            If ( (Get-Adobject -Filter {Name -eq $GroupName} -server $DomainName).objectClass -eq "group" ) {
                Do {
                    # Here the parameters change the behavior, breaking out of the do loop if present
                    If (( $OnlyUninherited.IsPresent) -and ($ACL.IsInherited -eq "True")) { break }
                    If (( $ExcludeDA.IsPresent) -and ($ACL.IdentityReference -like "*Domain Admins")) { break }
                    $Usernames = (Get-Adgroupmember $GroupName -server $DomainName).Name
                    $ACLoProp = @{ 'Name' = $ACL.IdentityReference; 'Inherited' = $ACL.IsInherited; 'Rights' = $ACL.FileSystemRights; 'Members' = $Usernames}
                    $CPHACLObject = New-Object -TypeName PSObject -Property $ACLoProp
                    Write-Output $CPHACLObject | Format-List -Property Name,Members,Rights,Inherited
                    $Usernames = ""
                    $ACLoProp = ""
                    $CPHACLObject = ""
                    $ACL = ""
                 }
                Until ( $ACL -eq "" )
            }
                # If the account is not an AD group, give up and just report its name and members as an empty set
                Else { 
                    Do {
                        If (( $OnlyUninherited.IsPresent) -and ($ACL.IsInherited -eq "True")) { break }
                        If (( $ExcludeDA.IsPresent) -and ($ACL.IdentityReference -like "*Domain Admins")) { break }
                        $ACLoProp = @{ 'Name' = $ACL.IdentityReference; 'Inherited' = $ACL.IsInherited; 'Rights' = $ACL.FileSystemRights; 'Members' = ''}
                        $CPHACLObject = New-Object -TypeName PSObject -Property $ACLoProp
                        Write-Output $CPHACLObject | Format-List -Property Name,Members,Rights,Inherited
                        $Usernames = ""
                        $ACLoProp = ""
                        $CPHACLObject = ""
                        $ACL = ""
                      }
                        Until ( $ACL -eq "" )
                  }
        }
        # If it's a local account of some kind, just give the information without querying AD
        Else {
            $ACLoProp = @{ 'Name' = $ACL.IdentityReference; 'Inherited' = $ACL.IsInherited; 'Rights' = $ACL.FileSystemRights; 'Members' = ''}
            $CPHACLObject = New-Object -TypeName PSObject -Property $ACLoProp
            Write-Output $CPHACLObject | Format-List -Property Name,Members,Rights,Inherited
            $Usernames = ""
            $ACLoProp = ""
            $CPHACLObject = ""
            $ACL = ""
         }
        $ACLS = ""
        }
    $Directory = ""
    $Directories = ""
}
$Path = ""
# Reset default display value to the default
$global:FormatEnumerationLimit = 4
