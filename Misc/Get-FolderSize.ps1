<#

    .SYNOPSIS

    This script produces disk usage information for subfolders under a given path.

    .DESCRIPTION

    Disk usage is obtained from subfolders by iterating child items and summing the length property of each. Output can be to the terminal, a CSV file, or both. Written by Michael Brady.
    
    .PARAMETER SuppressOutput

    This parameter produces no terminal output. Implies -ExportCSV. A path to a CSV file must be given to proceed.

    .PARAMETER ExportCSV

    This parameter indicates to the script to output to a CSV file, a path to which must be given to proceed.
    
    .PARAMETER CSVFile

    This parameter specifies the CSV file to be written to. Required if -SuppressOutput or -ExportCSV are used. This CSV file will be overwritten if it exists, but user will be prompted to do so first.

    .EXAMPLE

    .\Get-FolderSize.ps1 C:\Users\Public

    Retrieve disk space information for folders directly underneath C:\Users\Public and output to the terminal.

    .EXAMPLE

    .\Get-FolderSize.ps1 C:\Users\Public -ExportCSV C:\Output.csv

    Retrieve disk space information for folders directly underneath C:\Users\Public and output to the terminal and CSV file C:\Output.csv.

    .EXAMPLE

    .\Get-FolderSize.ps1 C:\Users\Public -ExportCSV C:\Output.csv -SuppressOutput

    Retrieve disk space information for folders directly underneath C:\Users\Public and output only to the CSV file C:\Output.csv.

#>

[CmdletBinding(DefaultParameterSetName='NoCSV')]
    Param(
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='NoCSV')]
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='CSV')]
            [string]$Path,
        [Parameter(ParameterSetName='CSV')]
            [switch]$SuppressOutput,
         [Parameter(ParameterSetName = 'CSV')]
            [switch]$ExportCSV,
        [Parameter(Mandatory=$True,Position=1,ParameterSetName='CSV')]
            [string]$CSVFile

            )
        
# Powershell v3 and higher is required in order to utilize the Export-CSV -Append switch
If ((($PSVersionTable.PSVersion.Major) -lt 3)  -and (-Not($CSVFile -eq $null))) {
    Throw "You must have Powershell version 3 or higher installed to utilize this script properly."
    }
    
If (-Not(Test-Path $Path)) {
    Throw "You must enter a valid path. Please check your syntax and try again."
    }

$ChildPaths = (Get-ChildItem $Path -Directory -Force).FullName

If ($ChildPaths -eq $null) {
    Throw "This directory has no subdirectories. Please check the path given and try again."
    }

# Make sure the user knows the file will be overwritten with a loop
If (-Not($CSVFile -eq $null)) {
    If (-Not(Test-Path $CSVFile)) {
        Write-Verbose "CSV file does not exist, creating a new one."
        New-Item $CSVFile -ItemType File | Out-Null
        If (-Not(Test-Path $CSVFile)) {
            Throw "The CSV file could not be created, please check the permissions on the file specified."
            }
        }
        Else {
            do {
                $CSVAnswer = Read-Host "CSV file exists, please type y to overwrite or n to exit."
                If ($CSVAnswer -eq "n") {
                    Write-Verbose "Exiting script."
                    Exit 1
                    }
                    ElseIf ($CSVAnswer -eq "y") {
                        Write-Verbose "Continuing script."
                        Remove-Item $CSVFile -Force
                        New-Item $CSVFile -ItemType File | Out-Null
                            If ((Get-Content $CSVFile) -ne $null) {
                                Throw "There was a problem overwriting the existing CSV file, please check permissions and try again."
                                }
                        }
                    }
                until ($CSVAnswer -eq "y")
                }
}

Foreach ( $Folder in $ChildPaths ) {
    # Sum the childrens' length properties to reach a byte total for the folder
    $Size = (Get-ChildItem $Folder -Recurse -Force | Measure-object -Property length -sum).sum
    # Convert and round as appropriate
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
    If (-Not($SuppressOutput.IsPresent)) {
        $FolderSizeObject | Format-List -Property "Folder","Size","Raw Size (bytes)"
        }
    If (-Not($CSVFile -eq $null)) {
        $FolderSizeObject | Select-Object -Property "Folder","Size","Raw Size (bytes)" | Export-CSV $CSVFile -NoTypeInformation -Append
        }
    $FolderSizeObject = ""
    $Size = ""
    $ConvertedSize = ""
    }
$Folder = ""
$ChildPaths = ""