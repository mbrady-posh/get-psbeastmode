<#

    .SYNOPSIS

    This script sets a password for a given account across several systems listed either by OU or a plain text file.

    .DESCRIPTION

    This script was written with the need to change local administrator passwords in mind.  ADSI is used to initialize a user account object and then use the SetPassword method to change it programmatically. The ActiveDirectory module may be required. Written by Michael Brady.
    
    .PARAMETER ComputerList

    This optional parameter allows the user to specify a path to a plain text file containing the list of computer names to have the account password changed.

    .PARAMETER XMLPath

    This optional parameter allows the user to specify a path to an XML file to use for script input (instead of this being given in the script itself.)
    
    .PARAMETER OutputResult

    This optional parameter displays the results of the operations (Success/Failure) at the script's end.

    .EXAMPLE

    .\Edit-LocalUserPW.ps1 -ComputerList \\CONTOSO\computers.txt

    Change local user password on computers listed in the given text file.

    .EXAMPLE

    .\Edit-LocalUserPW.ps1 -XMLPath \\CONTOSO\passwordreset.xml

    Utilize a specified XML file to populate input values instead of one in the script itself.

    .EXAMPLE

    .\Edit-LocalUserPW.ps1 -OutputResult

    Change local password on computers based on an AD OU specified in an XML file, and output results when finished.

#>

[CmdletBinding()]
    Param(
       [Parameter(Mandatory=$False,Position=0)]
             [string]$ComputerList,
       [Parameter(Mandatory=$False,Position=1)]
            [string]$XMLpath,
        [Parameter(Mandatory=$False,Position=2)]
            [switch]$OutputResult
        )

# Load XML file and create variables
If (-Not($XMLpath)) {
    [xml]$XMLData = [xml](Get-Content -Path "")
    }
    Else {
        If (Test-Path ($XMLpath)) {
            [xml]$XMLData = [xml](Get-Content -Path $XMLpath)
            }
            Else {
                Throw "XML path given could not be found. Please check the value given for the parameter and try again."
                }
        }
    If (-Not($ComputerList)) {
        Write-Verbose "Computer List not specified, utilizing XML to grab AD objects from an OU."
        $BaseOU = $XMLData.ChangePW.AD.BaseOU
        }
        $ADServer = $XMLData.ChangePW.AD.Server
        $FQDN = $XMLData.ChangePW.AD.FQDN

    $AccountName = $XMLData.ChangePW.Account.AccountName

If ($ComputerList) {
    If (Test-Path $ComputerList) {
        $Computers = Get-Content $ComputerList
        }
        Else {
            Throw "Computer list file location not found. Please check the parameter input and try again."
            }
        }
    Else {
        If ((Get-Module -ListAvailable).Name -contains "ActiveDirectory") {
            $Computers = (Get-ADObject -SearchBase $BaseOU -Filter {Objectclass -eq "computer"} -Server $ADServer).Name
            }
            Else {
                Throw "If a list of computers in not specified, the ActiveDirectory module must be available to use. You may need RSAT installed for your system."
                }
        }

Do {
    # Just want to verify that a typo wasn't made
    $PW1 = Read-Host -AsSecureString -Prompt "Please enter the password you wish to change to"
    $PW2 = Read-Host -AsSecureString -Prompt "Please re-enter the password to verify"
    # Unfortunately have to convert the secure string to text to compare and also to use in the ADSI functions
    $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PW1); $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PW2);
    $PlainPass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1) ; $PlainPass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
    }
    # Compare plain text password values to determine it was typed correctly
    Until ($PlainPass1 -eq $PlainPass2)

# Kill other password variables
$BSTR1 = $null
$BSTR2 = $null
$PlainPass2 = $null

# Initialize variable as a hash table for output
$MachineStatus = @{}

Foreach ($Computer in $Computers) {
    # To use Try-Catch with non-terminating errors, need to set ErrorActionPreference like this
    $OriginalEAP = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    $AccountObject = [ADSI]("WinNT://$Computer.$FQDN/$AccountName,user")
    Try {
        $AccountObject.SetPassword($PlainPass1)
        $AccountObject.Setinfo()
        $MachineStatus.Add("$Computer","Succeeded")
         }
         Catch {
            $MachineStatus.Add("$Computer","Failed")
            }
    # Reset ErrorActionPreference
    $ErrorActionPreference = $OriginalEAP
    }

# If the switch is specified, output the hash table
If ($OutputResult.IsPresent) {
    $MachineStatus.GetEnumerator() | Sort-Object Value -Descending
    }