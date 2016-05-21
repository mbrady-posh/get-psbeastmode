Param(
    [Parameter(Mandatory=$True)][string]$Hostname,
    [Parameter(Mandatory=$True)][string]$FileName
    )

    #region set up host window
    $Host.UI.RawUI.WindowTitle = "$($HostName): Windows Update Log"
    $BufferSize = $Host.UI.RawUI.BufferSize
    $BufferSize.Width = 225
    $Host.UI.RawUI.BufferSize = $BufferSize
    $WindowSize = $Host.UI.RawUI.WindowSize
    $WindowSize.Width = 225
    $WindowSize.Height = 50
    $Host.UI.RawUI.WindowSize = $WindowSize
    #endregion

    $TimerJob = Start-Job -ScriptBlock { Param( $FileName ) $File = New-Object System.IO.FileInfo -ArgumentList $FileName ; Do {$File.LastWriteTime = Get-Date ; Start-Sleep 1} While ($True -eq $True) }
    Clear-Host
    Get-Content $FileName -Wait | Foreach-Object { Switch -Wildcard ($_) { *error* { $Color = "Red"; break } *fail* { $Color = "Red"; Break } *success* { $Color = "Green"; Break; } *warn* {$Color = "Yellow"; Break;} Default { $Color = "White" } } ; Write-Host $_ -ForegroundColor $Color }