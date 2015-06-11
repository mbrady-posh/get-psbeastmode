#TODO: Help and comments

Function Get-BEScheduledBackupJobInfo {
    [CmdletBinding()]
        Param(
            [string]$ComputerName
            )

        #region Get job names and basic info
        $BEJobNames = @()
        $BEJobList = @()

        &"$env:ProgramFiles\Symantec\Backup Exec\bemcmd.exe" "-o23 -q1 -j -s18 -i" | Select-String -Pattern "JOB NAME" | %{Foreach ($JobName in $_) { $BEJobNames += ($JobName.ToString().Split(":")[1].Trim())} }

        Foreach ($JobName in $BEJobNames) {
            $BEJobList += (&"$env:ProgramFiles\Symantec\Backup Exec\bemcmd.exe" "-o506 -d1 -j`"$($JobName)`"")
            }
        $JobName = $null

        $BEJobobjects = (($BEJobList -Join "`n" -Split "\-+\s+JOB INFORMATION\s+\-+"))
        $BEJobObjects = $BEJobObjects -ne $BEJobobjects[0]
        $VariableNames = @{}
        $i = 0

        Foreach ($job in $BEJobobjects) {
            $i = $i + 1
            $job = $job -Split "`n"
            $props = @{}
            foreach ($item in $job) {
                If (($item.Split(": +")) -ne $null) { 
                    $props.Add(($item -Split ": +")[0].Trim(),($item -Split ": +")[1].Trim())
                    }
                } 
            New-Variable -Name "BackupExecJob$i" -Value (New-Object -TypeName "PSObject" -Property $props)
            $VariableNames.Add("$i","BackupExecJob$i")
            }
        #endregion

        #region Get Selection Lists
        Foreach ($BEJob in ($VariableNames.Values)) {
            $BEJobVariable = '$'+$($BEJob) ; $BEJobVariable = Invoke-Expression $BEJobVariable
            $BEJobName = $null
            $BEJobName = ((($BEJobVariable."JOB ID") -Split "} ")[1] -replace "[(|)]","")
            $BESelectionList = &"$env:ProgramFiles\Symantec\Backup Exec\bemcmd.exe" "-o506 -d2 -j`"$($BEJobName)`""
            $Selectionarray = $BESelectionList -Join "`n" -Split "DETAIL ID:\s+{.*}"
            $Selectionarray = $($selectionarray -ne $selectionarray[0])
            $i1 = 0
            Foreach ($item in $Selectionarray) {
                $item = $item -split "`n"
                $i1 = $i1 + 1
                $selectionprops = @{}
                foreach ($line in $item) {
                    If (($line -Split ": +") -ne $null) {
                        $selectionprops.Add(($line -Split ": +")[0].Trim(),($line -Split ": +")[1].Trim())
                        }
                    }
                    $BEJobVariable | Add-Member -MemberType NoteProperty -Name "Selection$i1" -Value (New-Object -TypeName "PSObject" -Property $selectionprops)
                }
            }
            $BEJob = $null
        #endregion

        #region Get Schedules
        Foreach ($BEJob in ($VariableNames.Values)) {
            $BEJobVariable = '$'+$($BEJob) ; $BEJobVariable = Invoke-Expression $BEJobVariable
            $BEJobName = $null
            $BEJobName = ((($BEJobVariable."JOB ID") -Split "} ")[1] -replace "[(|)]","")
            $BESchedule = &"$env:ProgramFiles\Symantec\Backup Exec\bemcmd.exe" "-o506 -d3 -j`"$($BEJobName)`""
            $BESchedule = $BESchedule | Select-Object -Skip 4 ; $BESchedule = $BESchedule -ne $BESchedule[(($BESchedule.Count)-1)-($BESchedule.Count)]
            $Scheduleprops = @{}
            foreach ($line in $BESchedule) {
                If (($line -Split ": +") -ne $null) {
                    $scheduleprops.Add(($line -Split ": +")[0].Trim(),($line -Split ": +")[1].Trim())
                    }
                }
                $BEJobVariable | Add-Member -MemberType NoteProperty -Name "Schedule" -Value (New-Object -TypeName "PSObject" -Property $scheduleprops)
                $BEJobVariable
            }
        #endregion
    }