[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$Path,
        [Parameter(Mandatory=$True,Position=1,ParameterSetName='CSV')]
            [string]$CSVFile,
        [Parameter(ParameterSetName = 'CSV')]
            [switch]$ExportCSV
            )
        

If (($PSVersionTable.PSVersion.Major) -lt 3)  {
    Throw "You must have Powershell version 3 or higher installed to utilize this script properly."
    }
    
If (-Not(Test-Path $Path)) {
    Throw "You must enter a valid path. Please check your syntax and try again."
    }

$ChildPaths = (Get-ChildItem $Path -Directory -Force).FullName

If ($ChildPaths -eq $null) {
    Throw "This directory has no subdirectories. Please check the path given and try again."
    }

If ($ExportCSV.IsPresent) {
    If (-Not(Test-Path $CSVFile)) {
        Write-Verbose "CSV file does not exist, creating a new one."
        New-Item $CSVFile -ItemType File
        If (-Not(Test-Path $CSVFile)) {
            Throw "The CSV file could not be created, please check the permissions on the file specified."
            }
        }
        Else {
            do {
                $CSVAnswer = Read-Host "CSV file exists, please type y to continue or n to exit."
                If ($CSVAnswer -eq "n") {
                    Write-Verbose "Exiting script."
                    Exit 1
                    }
                    ElseIf ($CSVAnswer -eq "y") {
                        Write-Verbose "Continuing script."
                        Remove-Item $CSVFile -Force
                        New-Item $CSVFile -ItemType File
                            If ((Get-Content $CSVFile) -ne $null) {
                                Throw "There was a problem overwriting the existing CSV file, please check permissions and try again."
                                }
                        }
                    }
                until ($CSVAnswer -eq "y")
                }
}

Foreach ( $Folder in $ChildPaths ) {
    $Size = (Get-ChildItem $Folder -Recurse -Force | Measure-object -Property length -sum).sum
    If (($Size -gt 1048576) -and ($Size -lt 1073741824)) {
        $ConvertedSize = "{0:N0}" -f ($Size / 1MB) + " MB"
        }
        ElseIf ($Size -gt 1073741824) {
            $ConvertedSize = "{0:N0}" -f ($Size /1GB) + " GB"
            }
        Else {
            $ConvertedSize = "{0:N0}" -f ($Size /1KB) + " KB"
            }
    $FolderSizeObject = New-Object PSObject -Property @{ "Folder" = "$Folder" ; "Raw Size (bytes)" = "$Size" ; "Size" = "$ConvertedSize"}
    $FolderSizeObject | Format-List -Property "Folder","Size","Raw Size (bytes)"
    If ($ExportCSV.IsPresent) {
        $FolderSizeObject | Select-Object -Property "Folder","Size","Raw Size (bytes)" | Export-CSV $CSVFile -NoTypeInformation -Append
        }
    $FolderSizeObject = ""
    $Size = ""
    $ConvertedSize = ""
    }
$Folder = ""
$ChildPaths = ""