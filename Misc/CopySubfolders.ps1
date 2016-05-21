    Param(
        [Parameter(Mandatory=$True)][string]$SourceFolder,
        [Parameter(Mandatory=$True)][string]$DestinationFolder,
        [Parameter(Mandatory=$True)][int]$FirstFolder,
        [Parameter(Mandatory=$True)][int]$LastFolder
        )

Try {
    $ErrorActionPreference = "Stop"
    Test-Path -Path $SourceFolder
    }
    Catch {
        Throw "Source folder doesn't exist. Exiting."
        }
    Finally {
        $ErrorActionPreference = "Continue"
        }

Try {
    $ErrorActionPreference = "Stop"
    Test-Path -Path $DestinationFolder
    }
    Catch {
        Throw "Destination folder doesn't exist. Exiting."
        }
    Finally {
        $ErrorActionPreference = "Continue"
        }

If (!(Test-Path "$($DestinationFolder)\Logs\")) {
    New-Item -ItemType Directory -Path "$($DestinationFolder)\Logs\"
    }

If ($FirstFolder -eq $LastFolder) {
    $FoldersToMove = ((Get-ChildItem -Path $SourceFolder) | Select Name)[($($Firstfolder) - 1)]
    }
    Else {
        $FoldersToMove = ((Get-ChildItem -Path $SourceFolder) | Select Name)[($($Firstfolder) - 1)..($($LastFolder) - 1)]
        }

$i = 0
Foreach ($Folder in $FoldersToMove) {
    $i++
    Write-Progress -Activity "Copying files" -PercentComplete ($i / $FoldersToMove.count * 100) -CurrentOperation "$($Folder.Name)" -status "Copying"
    Start-Process "robocopy" "`"$($SourceFolder)\$($Folder.Name)`" `"$($DestinationFolder)\$($Folder.Name)`" /mir /copyall /ZB /dcopy:t /XJ /TEE /log:`"$($DestinationFolder)\Logs\$($Folder.Name).log`"" -Wait
    }
