[CmdletBinding()]
    Param(
            [Parameter(Mandatory=$True)][string]$DestPaths,
            [Parameter(Mandatory=$True)][array]$SrcPaths,
            [switch]$SrcIsTopLevel,
            [switch]$DestIsTopLevel,
            [Parameter(Mandatory=$True)][string]$OutPath
            )

$script:scriptpath = Split-Path $($MyInvocation.MyCommand.Path) -Parent
    
Foreach ($item in $SrcPaths) {
     If (!(Test-Path $item)) {
        Throw "You must enter a valid source path. Please check your syntax and try again."
        }
    }

Foreach ($item in $DestPaths) {
     If (!(Test-Path $item)) {
        Throw "You must enter a valid source path. Please check your syntax and try again."
        }
    }

Function Get-ChildPathStats($ChildPaths,$Source) {
    If ($Source -eq $False) {
        Foreach ($path in $ChildPaths) {
            Write-Progress -Activity "Scanning destination directories." -PercentComplete 100 -CurrentOperation $Path
            & $script:scriptpath\du.exe /c /l 1 /accepteula $Path | ConvertFrom-Csv
            }
        }
        Else {
            Foreach ($path in $ChildPaths) {
                Write-Progress -Activity "Scanning source directories." -PercentComplete 50 -CurrentOperation $Path
                & $script:scriptpath\du.exe /c /accepteula $Path | ConvertFrom-Csv
                }
            }
    }

If ($SrcIsTopLevel.IsPresent) {
    $ChildPaths = (Get-ChildItem $SrcPaths -Directory -Force).FullName
    }
    Else {
        $ChildPaths = $SrcPaths
        }

$SrcOutput = Get-ChildPathStats $ChildPaths $True

If ($DestsTopLevel.IsPresent) {
    $ChildPaths = (Get-ChildItem $DestPaths -Directory -Force).FullName
    }
    Else {
        $ChildPaths = $DestPaths
        }

$DestOutput = Get-ChildPathStats $ChildPaths $False

$Srcoutput | Select @{Name="Path";Expression={$_.Path -Split "\\" | Select -Last 1} },DirectoryCount,DirectorySize | Export-Csv -NoTypeInformation "$($OutPath)srcoutput.csv"
$destoutput | Select @{Name="Path";Expression={$_.Path -Split "\\" | Select -Last 1} },DirectoryCount,DirectorySize |  Export-Csv -NoTypeInformation "$($OutPath)destoutput.csv"

# Compare-object the paths, then use Path and SideIndicator to echo unique dirs
$SrcExcludes = @() ; $DestExcludes = @()
Compare-Object $(Import-CSV "$($OutPath)srcoutput.csv") $(Import-CSV "$($OutPath)destoutput.csv") -Property Path -PassThru | Foreach-Object { If ($_.SideIndicator -eq "=>") { $DestExcludes += $_.Path ; Write-Output "$($_.Path) is only in the destination." } ElseIf ($_.SideIndicator -eq "<=") { $SrcExcludes += $_.Path ; Write-Output "$($_.Path) is only in the source." } }

# Strip those dirs and do a compare-object line by line
$SrcCompare = Import-CSV "$($OutPath)srcoutput.csv" | Where {$SrcExcludes -notcontains $_.Path} | Sort-Object -Property Path
$DestCompare = Import-CSV "$($OutPath)destoutput.csv" | Where {$DestExcludes -notcontains $_.Path} | Sort-Object -Property Path

Compare-Object $SrcCompare $DestCompare -SyncWindow 0 -Property DirectorySize -PassThru | Foreach-Object { $_.Path.ToLower() } | Select -Unique | Foreach-Object { Write-Output "$($_) did not validate successfully!" }