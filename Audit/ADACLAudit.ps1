ipmo ActiveDirectory
$Root = "AD:\DC=domain,DC=com"
$Children = Get-ChildItem $Root -Recurse | Where {$_.objectclass -eq "organizationalunit"} | Select @{Name="DN";Expression={($_.PSPath -split "/RootDSE/")[1] } }

$ACLprops = @{}
$ExcludedIdentities = "forest\EXCHANGE TRUSTED SUBSYSTEM","forest\RTCUNIVERSALSERVERREADONLYGROUP","CORP\DOMAIN CONTROLLERS","NT AUTHORITY\SYSTEM","forest\EXCHANGE SERVERS","forest\EXCHANGE WINDOWS PERMISSIONS","NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS","NT AUTHORITY\SELF","BUILTIN\ADMINISTRATORS","CORP\DOMAIN ADMINS","forest\ENTERPRISE ADMINS","forest\EXCHANGE RECIPIENT ADMINISTRATORS","forest\DELEGATED SETUP","forest\RTCUNIVERSALUSERREADONLYGROUP","forest\ORGANIZATION MANAGEMENT","CORP\RTCHSUNIVERSALSERVICES","forest\RTCUNIVERSALUSERADMINS"

(Get-ACL $Root).Access | Foreach-Object {
    If ($_.IdentityReference -notin $ExcludedIdentities) {
        If (!($ACLprops.$($_.IdentityReference))) {
            $ACLProps += @{$($_.IdentityReference)=@()}
            }
        $ACLProps.$($_.IdentityReference) += New-Object PSCustomObject -Property @{"DN"=$(($Root -split "\\")[1]);"Rights"=$_.ActiveDirectoryRights;"ACLType"=$_.AccessControlType}
        }    
    }

$Children | Foreach-Object {
    $CurrentItem = $_
    (Get-ACL "AD:\$($CurrentItem.DN)" ).Access | Foreach-Object {
        If ($_.IdentityReference -notin $ExcludedIdentities) {
            If (!($ACLprops.$($_.IdentityReference))) {
                $ACLProps += @{$($_.IdentityReference)=@()}
                }
            $ACLProps.$($_.IdentityReference) += New-Object PSCustomObject -Property @{"DN"=$CurrentItem.DN;"Rights"=$_.ActiveDirectoryRights;"ACLType"=$_.AccessControlType}
            }
        }
    }

    $ACLObj = New-Object PSCustomObject -Property $ACLprops
    Return $ACLObj