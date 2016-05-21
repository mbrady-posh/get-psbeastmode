Param(
    [bool]$ForceLDAP
    )

Try {
    $ErrorActionPreference = "Stop"
    If ($ForceLDAP -eq $True) {
        Throw "Switching to LDAP"
        }
    Import-Module ActiveDirectory

    $Idle = @()
    $Active = @()

    Foreach ($Server in $(Get-ADComputer -Filter {operatingSystem -like "*Windows Server*"} -properties lastlogontimestamp)) {
        If (([DateTime]::FromFileTime(($($Server.lastlogontimestamp)))) -le ((Get-Date).AddDays(-15))) {
            $Idle += $Server
            }
            Else {
                $Active += $Server
                }
        }
    $props = @{"Active"=$Active;"Idle"=$Idle}
    Return (New-Object -TypeName PSCustomObject -Property $props)
    }
    Catch {
        $LastLogonTime = ((Get-Date).AddDays(-15)).ToFileTime()
        $Active = @()
        $LDAPFilter = "(&(lastlogontimestamp>=$LastLogonTime)(operatingSystem=*Server*))"
        $Domain = New-Object System.DirectoryServices.DirectoryEntry
        $DirSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $DirSearcher.SearchRoot = $Domain
        $DirSearcher.PageSize = 2000
        $DirSearcher.Filter = $LDAPFilter
        $DirSearcher.SearchScope = "Subtree"
        $proplist = "cn"

        foreach ($prop in $proplist){$DirSearcher.PropertiesToLoad.Add($prop) | Out-Null}
        $DirSearcher.FindAll() | Foreach-Object {$Active += $(New-Object -TypeName PSCustomObject -Property @{"Name"=$_.properties.cn[0]})}
        $props = @{"Active"=$Active}
        Return (New-Object -TypeName PSCustomObject -Property $props)
        }
    Finally {
        $ErrorActionPreference = "Continue"
        }
