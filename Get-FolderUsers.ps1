## TODO: add -ExcludeDomainAdmins parameter, -ShowOnlyuninherited
## TODO: documentation
## TODO: get output ideally formatted
## TODO: input validation

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
            [string]$Path,
        [switch]$Recurse,
        [switch]$ExcludeDA,
        [switch]$OnlyUninherited
        )
        

$ACLS = ""
$Directories=""

$Directories = @($Path)
If ($Recurse.IsPresent ) {
    $RecurseDirList = (Get-ChildItem -Path $Path -Recurse -Directory).FullName
    $Directories = $Directories + $RecurseDirList
     }
Foreach ($Directory in $directories) {
    $ACLS = Get-ACL -Path $Directory | Select-Object -ExpandProperty Access
    Write-Output "*********************`n$Directory"
    Foreach ($ACL in $ACLS) {
        If (($ACL.IdentityReference  -notlike "NT AUTHORITY\SYSTEM") -and ($ACL.IdentityReference -notlike "*Computer*") ) {
        $GroupName =  Split-Path $ACL.IdentityReference -leaf
        $DomainName = Split-Path $ACL.IdentityReference
            If ( (Get-Adobject -Filter {Name -eq $GroupName} -server $DomainName).objectClass -eq "group" ) {
                If (( $OnlyUninherited.IsPresent) -and ($ACL.IsInherited = "True")) { break }
                If (( $ExcludeDA.IsPresent) -and ($ACL.IdentityReference -like "*Domain Admins")) { break }
                $Usernames = (Get-Adgroupmember $GroupName -server $DomainName).Name
                $ACLoProp = @{ 'Name' = $ACL.IdentityReference; 'Inherited' = $ACL.IsInherited; 'Rights' = $ACL.FileSystemRights; 'Members' = $Usernames}
                $CPHACLObject = New-Object -TypeName PSObject -Property $ACLoProp
                Write-Output $CPHACLObject | Format-Table
                $Usernames = ""
                $ACLoProp = ""
                $CPHACLObject = ""
            }
                Else { 
                    $ACLoProp = @{ 'Name' = $ACL.IdentityReference; 'Inherited' = $ACL.IsInherited; 'Rights' = $ACL.FileSystemRights; 'Members' = ''}
                    $CPHACLObject = New-Object -TypeName PSObject -Property $ACLoProp
                    Write-Output $CPHACLObject | Format-Table
                    $Usernames = ""
                    $ACLoProp = ""
                    $CPHACLObject = ""
                  }
        }
        $ACL = ""
        $ACLS = ""
        }
    $Directory = ""
    $Directories = ""
}
$Path = ""