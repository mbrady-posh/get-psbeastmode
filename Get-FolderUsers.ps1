[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
            [string]$Path
        )

$ACLS = ""
$x = ""

$ACLS = Get-ACL -Path $Path | Select-Object -ExpandProperty Access
Write-Output "Root $Path"
Foreach ($x in $ACLS) {
    If (($x.IdentityReference  -notlike "NT AUTHORITY\SYSTEM") -and ($x.IdentityReference -notlike "*Computer*") -and ($x.IdentityReference -notlike "*Domain Admins*")) {
       $GroupName =  Split-Path $x.IdentityReference -leaf
       $DomainName = Split-Path $x.IdentityReference
       If ($DomainName -eq "PUBLIC-HEALTH") {
            If ( (Get-Adobject -Filter {Name -eq $GroupName} -server ph-dc1.public-health.uiowa.edu).objectClass -eq "group" ) {
                (Get-Adgroupmember $GroupName -server ph-dc1.public-health.uiowa.edu).Name
                }
                Else { $GroupName }
            }
            ElseIf ($DomainName -eq "IOWA") {
                If ((Get-Adobject -Filter {Name -eq $GroupName} -server iowadc1.iowa.uiowa.edu).objectClass -eq "group") {
                     (Get-Adgroupmember $GroupName -server iowadc1.iowa.uiowa.edu).Name
                    }
                     Else { $GroupName }
                }
    }
}
$DIRLIST = (Get-ChildItem -Path $Path -Recurse -Directory).FullName
Foreach ($y in $DIRLIST) {
     $y
     $rACLS = Get-ACL -Path $y | Select-Object -ExpandProperty Access
     Foreach ($z in $rACLS) {
        If ($rACLS.IsInherited -eq "False") {
        $rGroupName =  Split-Path $z.IdentityReference -leaf
        $rDomainName = Split-Path $z.IdentityReference
        If ($rDomainName -eq "PUBLIC-HEALTH") {
            If ( (Get-Adobject -Filter {Name -eq $rGroupName} -server ph-dc1.public-health.uiowa.edu).objectClass -eq "group" ) {
                (Get-Adgroupmember $rGroupName -server ph-dc1.public-health.uiowa.edu).Name
                }
                Else { $rGroupName }
            }
            ElseIf ($rDomainName -eq "IOWA") {
                If ((Get-Adobject -Filter {Name -eq $rGroupName} -server iowadc1.iowa.uiowa.edu).objectClass -eq "group") {
                     (Get-Adgroupmember $rGroupName -server iowadc1.iowa.uiowa.edu).Name
                    }
                     Else { $rGroupName }
            }
       }
  }
  }
$ACLS = ""
$Path = ""
$x = ""