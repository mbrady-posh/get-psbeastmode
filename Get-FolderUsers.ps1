## TODO: add -ExcludeDomainAdmins parameter, -ShowOnlyuninherited

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
            [string]$Path,
        [switch]$Recurse
        )
        

$ACLS = ""
$x = ""

$ACLS = Get-ACL -Path $Path | Select-Object -ExpandProperty Access
Write-Output "Root $Path"
Foreach ($x in $ACLS) {
    If (($x.IdentityReference  -notlike "NT AUTHORITY\SYSTEM") -and ($x.IdentityReference -notlike "*Computer*") ) {
       $GroupName =  Split-Path $x.IdentityReference -leaf
       $DomainName = Split-Path $x.IdentityReference
       If ($DomainName -eq "PUBLIC-HEALTH") {
            If ( (Get-Adobject -Filter {Name -eq $GroupName} -server ph-dc1.public-health.uiowa.edu).objectClass -eq "group" ) {
                    $Usernames = (Get-Adgroupmember $GroupName -server ph-dc1.public-health.uiowa.edu).Name
                    If ($x.IsInherited -eq "True")  {Write-Output "Inherited : $GroupName : $usernames" }
                    Else {Write-Output "$GroupName : $Usernames" }
                    $Usernames = ""
                }
                        Else { 
                            If ($x.IsInherited -eq "True") { Write-Output "Inherited : $xGroupName" }
                                Else {Write-Output "$GroupName"}
                        }
            }
            ElseIf ($DomainName -eq "IOWA") {
                If ((Get-Adobject -Filter {Name -eq $GroupName} -server iowadc1.iowa.uiowa.edu).objectClass -eq "group") {
                     $Usernames = (Get-Adgroupmember $GroupName -server iowadc1.iowa.uiowa.edu).Name
                     If ($x.IsInherited -eq "True") {Write-Output "Inherited : $GroupName : $usernames" }
                     Else {Write-Output  "$GroupName : $Usernames" }
                     $Usernames = ""
                    }
                        Else { 
                            If ($x.IsInherited -eq "True") { Write-Output "Inherited : $GroupName" }
                                Else {Write-Output "$GroupName"}
                        }
                }
    }

}
If ($Recurse.IsPresent) {
    $DIRLIST = (Get-ChildItem -Path $Path -Recurse -Directory).FullName
    Foreach ($y in $DIRLIST) {
        Write-Output "******************"
        $y
        $rACLS = Get-ACL -Path $y | Select-Object -ExpandProperty Access
        Foreach ($z in $rACLS) {
           If ( ($z.IdentityReference  -notlike "NT AUTHORITY\SYSTEM") -and ($z.IdentityReference -notlike "*Computer*")) {
          $rGroupName =  Split-Path $z.IdentityReference -leaf
          $rDomainName = Split-Path $z.IdentityReference
              If ($rDomainName -eq "PUBLIC-HEALTH") {
                 If ( (Get-Adobject -Filter {Name -eq $rGroupName} -server ph-dc1.public-health.uiowa.edu).objectClass -eq "group" ) {
                       $rUsername = (Get-Adgroupmember $rGroupName -server ph-dc1.public-health.uiowa.edu).Name
                       If ($z.IsInherited -eq "True") { Write-Output "Inherited : $rGroupName : $rUsername" }
                           Else {Write-Output "$rGroupName : $rUsername" }
                        $rUsername = ""
                     }
                         Else { 
                                If ($z.IsInherited -eq "True") { Write-Output "Inherited : $rGroupName" }
                                  Else {Write-Output "$rGroupName"}
                          }
                 }
                  ElseIf ($rDomainName -eq "IOWA") {
                      If ((Get-Adobject -Filter {Name -eq $rGroupName} -server iowadc1.iowa.uiowa.edu).objectClass -eq "group") {
                          $rUsername = (Get-Adgroupmember $rGroupName -server iowadc1.iowa.uiowa.edu).Name
                          If ($z.IsInherited -eq "True") { Write-Output "Inherited : $rGroupName : $rUsername" }
                            Else {Write-Output "$rGroupName : $rUsername" }
                            $rUsername = ""
                        }
                          Else { 
                               If ($z.IsInherited -eq "True") { Write-Output "Inherited : $rGroupName" }
                                   Else {Write-Output "$rGroupName"}
                           }
                  }
          }
    }
    }
}
$ACLS = ""
$Path = ""
$x = ""