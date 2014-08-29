<#

    .SYNOPSIS

    This script obtains a log snippet and outputs to a GUI or opens the entire log in a utility for analysis.

    .DESCRIPTION

    This script was written to simplify the steps to analyze logs on remote machines. -Credential parameter is not allowed on FileSystem operations so a PSDrive must be created first. Logs can be read as snippets (3 lines before and after a match) or opened in their entirety with a chosen log reader. Written by Michael Brady.
    
    .PARAMETER Path

    This mandatory parameter specifies the path to the text file to be opened.

    .PARAMETER Credential

    This optional parameter allows the user to specify alternate credentials when accessing the file specified in the -Path parameter.
    
    .PARAMETER EntireLog

    This parameter instructs the script to open the whole log in a text editor which is specified in the script. Either this or -Pattern must be utilized for the script to run.

    .PARAMETER Pattern

    This parameter instructs the script to search the text file for a given string pattern; on match, the line plus 3 preceding and following lines are outputted. Either this or -EntireLog must be utilized for the script to run.
    
    .EXAMPLE

    .\Open-LogFile.ps1 -Path \\CONTOSO\C$\Windows\CCM\ccmexec.log -EntireLog -Credential $CONTOSOADMIN

    Open the ccmexec log from remote computer CONTOSO with specified credentials.

    .EXAMPLE

    .\Open-LogFile.ps1 -Path \\CONTOSO\C$\Windows\Logs\DISM\dism.log -Pattern "error"

    Open the dism.log file on remote computer CONTOSO and output "error" line matches with 3-line context.

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=2,ParameterSetName="Pattern")][Parameter(Mandatory=$False,Position=2,ParameterSetName="EntireLog")][System.Management.Automation.PSCredential][System.Management.Automation.Credential()]$Credential,
        [Parameter(Mandatory=$True,Position=0,ParameterSetName="Pattern")][Parameter(Mandatory=$False,Position=0,ParameterSetName="EntireLog")][string]$Path,
        [Parameter(Mandatory=$True,Position=1,ParameterSetName="EntireLog")][switch]$EntireLog,
        [Parameter(Mandatory=$True,Position=1,ParameterSetName="Pattern")][string]$Pattern
        )

$OriginalEAP = $ErrorActionPreference

If ($Credential) {
    $ErrorActionPreference = 'Stop'
    Try {
        New-PsDrive -Name LogDrive -PSProvider FileSystem -Root $(Split-Path $Path) -Credential $Credential | Out-Null
        }
        Catch {
            Write-Error $error[0]
            Write-Error "Unable to create PSDrive to $(Split-Path $Path). Please check the path, your credentials and permissions."
            }
          Finally {
            $ErrorActionPreference = $OriginalEAP           
            }
    }
    Else {
        Try {
                $ErrorActionPreference = 'Stop'
                New-PsDrive -Name LogDrive -PSProvider FileSystem -Root $(Split-Path $Path) | Out-Null
                }
        Catch {
            Write-Error $error[0]
            Write-Error "Unable to create PSDrive to $(Split-Path $Path). Please check the path, your credentials and permissions."
            }
          Finally {
            $ErrorActionPreference = $OriginalEAP           
            }
        }

If ($EntireLog.IsPresent) {
    $OriginalPath = Get-Location 
    Set-Location $env:SystemDrive
    If ($Path -like "*ccm*") {
        If ($Credential) {
            Try {
               $ErrorActionPreference = "Stop"
               Start-Process "${env:ProgramFiles(x86)}\ConfigMgr Console Extensions\cmtrace.exe" "$Path" -Credential $Credential
                }
            Catch {
                Write-Error $error[0]
                Write-Error "Unable to start log reader. Please check the program path, your credentials and permissions."
                }
            Finally {
                $ErrorActionPreference = $OriginalEAP           
                }
            }
            Else {
                Try {
                    $ErrorActionPreference = "Stop"
                    Start-Process "${env:ProgramFiles(x86)}\ConfigMgr Console Extensions\cmtrace.exe" "$Path"
                    }
                Catch {
                    Write-Error $error[0]
                    Write-Error "Unable to start log reader. Please check the program path, your credentials and permissions."
                    }
                Finally {
                    $ErrorActionPreference = $OriginalEAP           
                    }
                }
            }
         Else {
            If ($Credential) {
                Try {
                    $ErrorActionPreference = "Stop"
                    Start-Process "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe" "$Path" -Credential $Credential
                    }
                Catch {
                    Write-Error $error[0]
                    Write-Error "Unable to start log reader. Please check the program path, your credentials and permissions."
                    }
                Finally {
                    $ErrorActionPreference = $OriginalEAP           
                    }
                }
                Else {
                    Try {
                        $ErrorActionPreference = "Stop"
                        Start-Process "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe" "$Path"
                        }
                    Catch {
                        Write-Error $error[0]
                        Write-Error "Unable to start log reader. Please check the program path, your credentials and permissions."
                        }
                    Finally {
                        $ErrorActionPreference = $OriginalEAP           
                        }
                    }
                }
    Set-Location $OriginalPath
    }    
    Else {
        Try {
            $ErrorActionPreference = "Stop"
            Get-Content "LogDrive:\$(Split-Path $Path -Leaf)" | Select-String -SimpleMatch "$Pattern" -Context 3 | Out-String -Stream -Width 4096 | Out-GridView
            }
        Catch {
            Write-Error $error[0]
            Write-Error "Error opening $(Split-Path $Path -Leaf). Please check the file name and permissions."
            }
        Finally {
            $ErrorActionPreference = $OriginalEAP
            }
        }

Remove-PSDrive LogDrive