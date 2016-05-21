$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

If (!$OutPath) {
    $Outpath = $ScriptPath
    }

$Serverlist = (& "$ScriptPath\Get-ActiveServers.ps1").Active | Select -ExpandProperty Name

$TaskObjs = Foreach ($Server in $Serverlist) {
    $TaskChildren = Get-ChildItem "\\$($Server)\C$\windows\system32\tasks"
    $Tasks = $TaskChildren | Where-Object {$_.PSIsContainer -eq $False}
    If ($TaskChildren | Where {(($_.PSIsContainer -eq $True) -and ($_.Name -like "*Intrado*"))} ) {
        $Tasks += $TaskChildren | Where {(($_.PSIsContainer -eq $True) -and ($_.Name -like "*Intrado*"))} | Foreach-Object { $_ | Get-ChildItem -File }
        }
    Foreach ($Task in $Tasks) {
        $TaskXML = [xml](Get-Content $Task.FullName)
        $TaskObj = New-Object PSCustomObject -Property @{"Server"=$Server;"Name"=$(If ((Split-Path $Task.FullName -Parent) -eq "\\$($Server)\C$\windows\system32\tasks") { $Task.Name } Else { (($Task.FullName) -split "\\" | Select -Last 2) -join "\" });"Author"=$TaskXML.Task.RegistrationInfo.Author;"Date"=$(If ($TaskXML.Task.RegistrationInfo.Date) {Get-Date ($TaskXML.Task.RegistrationInfo.Date) });"Command"=$TaskXML.Task.Actions.Exec.Command;"Arguments"=$TaskXML.Task.Actions.Exec.Arguments;"RunAs"=$TaskXML.Task.Principals.Principal.UserId;"Enabled"=$TaskXML.Task.Settings.Enabled}
        $TaskObj
        $Task = $null
        }
    $TaskXML = $null
    $TaskChildren = $null
    $Tasks = $null
    }

Return $TaskObjs