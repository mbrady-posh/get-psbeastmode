Function New-SSHConnection {
    [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$True,Position=0)]
                [string]$Connectionstring,
            [Alias("P")][Parameter(Mandatory=$False,Position=1)]
                [int]$Port = 5985
            )

    If ($Connectionstring -like "*@*") {
        $Username = $Connectionstring.Split("@")[0]
        $Computername = $Connectionstring.Split("@")[1]
        $Variables = Get-Variable

        $ErrorActionPreference = 'SilentlyContinue'
        Foreach ($Variable in $Variables) {
            If (($Variable.Value.ToString()) -eq "System.Management.Automation.PSCredential") {
                If (($Variable.Value.Username) -eq $Username) {
                    $DesiredCredential = '$'+$($Variable.Name)
                    }
                }
            }
        $ErrorActionPreference = 'Continue'
        If ($DesiredCredential) {
            Enter-PSSession -Computername $Computername -Port $Port -Credential $(Get-Credential -Credential $(Invoke-Expression $DesiredCredential))
            }
            Else {
                Enter-PSSession -Computername $Computername -Port $Port -Credential $(Get-Credential -UserName $Username)
                }
        }
        Else {
            Enter-PSSession -Computername $Computername -Port $Port
            }
    }

Function New-GrepSession {
    [CmdletBinding()]
        Param(
            
            )

    }