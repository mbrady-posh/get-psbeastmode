$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$Serverlist = (& "$ScriptPath\Get-ActiveServers.ps1").Active | Select -ExpandProperty Name | Where {$_ -notlike "*DC*"}

$Props = @{}
$Failures = @()
$i = 0

Function AddServertoAdminList($Name,$Server) {
    If ($script:props.$($name)) {
        $script:props.$($name) += $Server
        }
        Else {
            $script:props += @{"$Name"=@()}
            $script:props.$Name += $Server
            }        
    }

Foreach ($Server in $Serverlist) {
    $i++
    Write-Progress -PercentComplete ($i / $serverlist.Count * 100) -CurrentOperation $Server -Activity "Getting local admins membership"
    $ErrorActionPreference = "Stop"
    Try {
        $ADSIServerObject = [ADSI]"WinNT://$($Server)"

        $groups = $ADSIServerObject.psbase.Children | Where-Object {($_.psbase.schemaClassName -eq "group") -and ($_.name -eq "Administrators")}

        Foreach ($Group in $groups) {
            $members = @($Group.psbase.Invoke("Members"))

            Foreach ($member in $members) {
                $Class = $Member.GetType().InvokeMember("Class", 'GetProperty', $Null, $Member, $Null)
                $Name = $Member.GetType().InvokeMember("Name", 'GetProperty', $Null, $Member, $Null)
                $Domain = $member.GetType().InvokeMember("ADsPath", 'GetProperty',$null,$member,$null)
                If ($Domain -like "*$Server*") {
                    $Domain = "Local"
                    }
                    Else {
                        $Domain = ($Domain.Split("/"))[2]
                        }
                    AddServertoAdminList "$($Domain)\$($Name)" $Server
                }
            }
        }
        Catch {
            Write-Error $_
            }
        Finally {
            $ErrorActionPreference = "Continue"
            }
    }
Return $props