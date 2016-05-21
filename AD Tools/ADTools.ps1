#TODO : Only unlock/enable acct

Function Select-Zone {
    Do {
                        $script:Zones = @{Name="Domain";ServerName="dc.domain.com"}
                        Clear-Host
                        Foreach ($item in $editedlist) {
                            Write-Host $($item.Name) -ForegroundColor DarkGreen
                            }
                        $Message = "`nPlease select the zone you will be working in."
                        $Title = ""
                        $DefaultChoice = 0
                        [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $script:Zones | Foreach-Object {$_.Name}
                        Foreach ($Possible in $Poss) {            
		                    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as your choice." | Out-Null
	                        }       
	                     $script:ChosenZone = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                        }
                        Until ($script:ChosenZone -ne $null)
    }

Function Get-PhoneticSpelling {
    Param(
            [Parameter(Mandatory=$True,Position=1)]
                [string]$PW
        )
    
    $Numbers = 0 .. ($PW.Length -1)

    $PhoneticPass = ""

    Foreach ($Number in $Numbers) {
        Switch -CaseSensitive ($PW[$Number] ){
            "a" { $PhoneticPass = "$PhoneticPass Alpha " }
            "b" {$PhoneticPass = "$PhoneticPass Beta " }
            "c" {$PhoneticPass = "$PhoneticPass Charlie "}
            "d" { $PhoneticPass = "$PhoneticPass Delta "}
            "e" {$PhoneticPass = "$PhoneticPass Echo "}
            "f" {$PhoneticPass = "$PhoneticPass Foxtrot "}
            "g" {$PhoneticPass = "$PhoneticPass Golf "}
            "h" {$PhoneticPass = "$PhoneticPass Hotel "}
            "i" {$PhoneticPass = "$PhoneticPass India "}
            "j" {$PhoneticPass = "$PhoneticPass Juliett "}
            "k" {$PhoneticPass = "$PhoneticPass Kilo "}
            "l" {$PhoneticPass = "$PhoneticPass Lima "}
            "m" {$PhoneticPass = "$PhoneticPass Mike "}
            "n" {$PhoneticPass = "$PhoneticPass November "}
            "o" {$PhoneticPass = "$PhoneticPass Oscar "}
            "p" {$PhoneticPass = "$PhoneticPass Papa "}
            "q" {$PhoneticPass = "$PhoneticPass Quebec "}
            "r" {$PhoneticPass = "$PhoneticPass Romeo "}
            "s" {$PhoneticPass = "$PhoneticPass Sierra "}
            "t" {$PhoneticPass = "$PhoneticPass Tango "}
            "u" {$PhoneticPass = "$PhoneticPass Uniform "}
            "v" {$PhoneticPass = "$PhoneticPass Victor "}
            "w" {$PhoneticPass = "$PhoneticPass Whiskey "}
            "x" {$PhoneticPass = "$PhoneticPass Xray "}
            "y" {$PhoneticPass = "$PhoneticPass Yankee "}
            "z" {$PhoneticPass = "$PhoneticPass Zulu "}
             # Capitals
             "A" { $PhoneticPass = "$PhoneticPass CAPITAL ALPHA " }
            "B" {$PhoneticPass = "$PhoneticPass CAPITAL BETA " }
            "C" {$PhoneticPass = "$PhoneticPass CAPITAL CHARLIE "}
            "D" { $PhoneticPass = "$PhoneticPass CAPITAL DELTA "}
            "E" {$PhoneticPass = "$PhoneticPass CAPITAL ECHO "}
            "F" {$PhoneticPass = "$PhoneticPass CAPITAL FOXTROT "}
            "G" {$PhoneticPass = "$PhoneticPass CAPITAL GOLF "}
            "H" {$PhoneticPass = "$PhoneticPass CAPITAL HOTEL "}
            "I" {$PhoneticPass = "$PhoneticPass CAPITAL INDIA "}
            "J" {$PhoneticPass = "$PhoneticPass CAPITAL JULIETT "}
            "K" {$PhoneticPass = "$PhoneticPass CAPITAL KILO "}
            "L" {$PhoneticPass = "$PhoneticPass CAPITAL LIMA "}
            "M" {$PhoneticPass = "$PhoneticPass CAPITAL MIKE "}
            "N" {$PhoneticPass = "$PhoneticPass CAPITAL NOVEMBER "}
            "O" {$PhoneticPass = "$PhoneticPass CAPITAL OSCAR "}
            "P" { $PhoneticPass = "$PhoneticPass CAPITAL PAPA " }
             "Q" {$PhoneticPass = "$PhoneticPass CAPITAL QUEBEC "}
            "R" {$PhoneticPass = "$PhoneticPass CAPITAL ROMEO "}
            "S" {$PhoneticPass = "$PhoneticPass CAPITAL SIERRA "}
            "T" {$PhoneticPass = "$PhoneticPass CAPITAL TANGO "}
            "U" {$PhoneticPass = "$PhoneticPass CAPITAL UNIFORM "}
            "V" {$PhoneticPass = "$PhoneticPass CAPITAL VICTOR "}
            "W" {$PhoneticPass = "$PhoneticPass CAPITAL WHISKEY "}
            "X" {$PhoneticPass = "$PhoneticPass CAPITAL XRAY "}
            "Y" {$PhoneticPass = "$PhoneticPass CAPITAL YANKEE "}
            "Z" {$PhoneticPass = "$PhoneticPass CAPITAL ZULU "}
            # Numbers
             "1" {$PhoneticPass = "$PhoneticPass Number One "}
            "2" {$PhoneticPass = "$PhoneticPass Number Two "}
            "3" {$PhoneticPass = "$PhoneticPass Number Three "}
            "4" {$PhoneticPass = "$PhoneticPass Number Four "}
            "5" {$PhoneticPass = "$PhoneticPass Number Five "}
            "6" {$PhoneticPass = "$PhoneticPass Number Six "}
            "7" {$PhoneticPass = "$PhoneticPass Number Seven "}
            "8" {$PhoneticPass = "$PhoneticPass Number Eight "}
            "9" {$PhoneticPass = "$PhoneticPass Number Nine "}
            "0" {$PhoneticPass = "$PhoneticPass Number Zero "}
            # Else
            default { $PhoneticPass = "$PhoneticPass $($PW[$Number]) Symbol " }
            }
        }

    Write-Output $PhoneticPass

    $PW = $null
    $PhoneticPass = $null
    }
Function Reset-ADAccountUnlockAndEnable {
    Param(
        [Parameter(Mandatory=$True)][string]$Username
        )
    Select-Zone
    $Creds = Get-Credential -UserName "$($Script:zones[$Script:chosenzone].Name)\$($env:username)-admin" -Message "Please enter administrative credentials for $($Script:zones[$Script:chosenzone].Name)."
    Try {
        $ErrorActionPreference = "Stop"
        $ADUser = Invoke-Command -SessionOption $Option -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser "$($Username)" -Properties Title,Enabled,pwdlastset,LockedOut ; New-Object PSCustomObject -Property @{"Title"=$ADUser.Title;"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy -Server "localhost").MaxPasswordAge)}}
        }
        Catch {
            Do {
                Try {
                    Clear-Host
                    Write-Host "User $($Username) not found, please retype the username below or use Ctrl-C to exit." -ForegroundColor Red
                    $Username = Read-Host -Prompt "Username"
                    $ADUser = Invoke-Command -SessionOption $Option -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser "$($Username)" -Properties Title,Enabled,pwdlastset,LockedOut ; New-Object PSCustomObject -Property @{"Title"=$ADUser.Title;"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy -Server "localhost").MaxPasswordAge)}}
                    }
                    Catch {
                        $ADUser = $null
                        }
                }
                Until ($ADUser)
            }
        Finally {
            $ErrorActionPreference = "Continue"
            }
    Do {
        Clear-Host
            Write-Host -ForegroundColor Green "Account ID: $($ADUser.samaccountname)"
            Write-Host -ForegroundColor Green "Name: $($ADUser.Name)"
            Write-Host -ForegroundColor Green "Title: $($ADUser.Title)"
            If ($ADUser.pwdLastSet -eq 0) {
                Write-Host -ForegroundColor Red "This account is set to force a password change on next logon."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not set to force a password change."
                    }
            If ($ADUser.Enabled -eq $False) {
                Write-Host -ForegroundColor Red "This account is disabled."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not disabled."
                    }
            If ($ADUser.LockedOut -eq $False) {
                Write-Host -ForegroundColor Green "This account is not locked out."
                }
                Else {
                    Write-Host -ForegroundColor Red "This account is locked out."
                    }
            If (($ADUser.PwdLastSet + $ADUser.MaxPwdAge) -lt $(Get-Date)) {
                Write-Host -ForegroundColor Red "This account's password is expired and must be changed."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account's password expires in $((($ADUser.PwdLastSet + $ADUser.MaxPwdAge) - (Get-Date)).Days) days."
                    }
        $Message = "`nPlease confirm this is the user you wish to modify.`n"
        $Title = ""
        $DefaultChoice = 0
        [System.Management.Automation.Host.ChoiceDescription[]]$Poss = "Y","N" | Foreach-Object {$_}
        Foreach ($Possible in $Poss) {            
		    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as your choice." | Out-Null
	        }       
	    $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice )
        If ($Answer -eq 1) {
            "Exiting."
            Exit 1
            }
        }
        Until ($Answer -eq 0)
      
    Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { 
        Param( $Username ) 
        Import-Module ActiveDirectory
        If ($ADUser.Enabled) {
            Set-ADUser $Username -Enabled $True
            }
        Unlock-ADAccount $Username
        }
        Clear-Host
    }


Function Reset-ADAccountPassword {
    Param(
        [Parameter(Mandatory=$True)][string]$Username
        )
    Select-Zone
    $Creds = Get-Credential -UserName "$($Script:zones[$Script:chosenzone].Name)\$($env:username)-admin" -Message "Please enter administrative credentials for $($Script:zones[$Script:chosenzone].Name)."
    Try {
        $ErrorActionPreference = "Stop"
        $ADUser = Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser "$($Username)" -Properties Title,Enabled,pwdlastset,LockedOut ; New-Object PSCustomObject -Property @{"Title"=$ADUser.Title;"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy -Server "localhost").MaxPasswordAge)}}
        }
        Catch {
            Do {
                Try {
                    Clear-Host
                    Write-Host "User $($Username) not found, please retype the username below or use Ctrl-C to exit." -ForegroundColor Red
                    $Username = Read-Host -Prompt "Username"
                    $ADUser = Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser "$($Username)" -Properties Title,Enabled,pwdlastset,LockedOut ; New-Object PSCustomObject -Property @{"Title"=$ADUser.Title;"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy -Server "localhost").MaxPasswordAge)}}
                    }
                    Catch {
                        $ADUser = $null
                        }
                }
                Until ($ADUser)
            }
        Finally {
            $ErrorActionPreference = "Continue"
            }
    Do {
        Clear-Host
            Write-Host -ForegroundColor Green "Account ID: $($ADUser.samaccountname)"
            Write-Host -ForegroundColor Green "Name: $($ADUser.Name)"
            Write-Host -ForegroundColor Green "Title: $($ADUser.Title)"
            If ($ADUser.pwdLastSet -eq 0) {
                Write-Host -ForegroundColor Red "This account is set to force a password change on next logon."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not set to force a password change."
                    }
            If ($ADUser.Enabled -eq $False) {
                Write-Host -ForegroundColor Red "This account is disabled."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not disabled."
                    }
            If ($ADUser.LockedOut -eq $False) {
                Write-Host -ForegroundColor Green "This account is not locked out."
                }
                Else {
                    Write-Host -ForegroundColor Red "This account is locked out."
                    }
            If (($ADUser.PwdLastSet + $ADUser.MaxPwdAge) -lt $(Get-Date)) {
                Write-Host -ForegroundColor Red "This account's password is expired and must be changed."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account's password expires in $((($ADUser.PwdLastSet + $ADUser.MaxPwdAge) - (Get-Date)).Days) days."
                    }
        $Message = "`nPlease confirm this is the user you wish to modify.`n"
        $Title = ""
        $DefaultChoice = 0
        [System.Management.Automation.Host.ChoiceDescription[]]$Poss = "Y","N" | Foreach-Object {$_}
        Foreach ($Possible in $Poss) {            
		    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as your choice." | Out-Null
	        }       
	    $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice )
        If ($Answer -eq 1) {
            "Exiting."
            Exit 1
            }
        }
        Until ($Answer -eq 0)
      
    $Password = Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { 
        Param( $Username ) 
        Import-Module ActiveDirectory
        function Get-GeneratedPassword {
            [CmdletBinding(DefaultParameterSetName='FixedLength',ConfirmImpact='None')]
            [OutputType([String])]
            Param(
                [int]$PasswordLength = 9,
                [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '23456789', '!"#%&();:[]{}')
                )
            Begin {
                Function Get-Seed{
                    $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
                    $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
                    $Random.GetBytes($RandomBytes)
                    [BitConverter]::ToUInt32($RandomBytes, 0)
                }
            }
            Process {
                For($iteration = 1;$iteration -le 1; $iteration++){
                    $Password = @{}
                    [char[][]]$CharGroups = $InputStrings
                    $AllChars = $CharGroups | ForEach-Object {[Char[]]$_}
                    Foreach($Group in $CharGroups) {
                        if($Password.Count -lt $PasswordLength) {
                            $Index = Get-Seed
                            While ($Password.ContainsKey($Index)){
                                $Index = Get-Seed                        
                            }
                            $Password.Add($Index,$Group[((Get-Seed) % $Group.Count)])
                        }
                    }
                    for($i=$Password.Count;$i -lt $PasswordLength;$i++) {
                        $Index = Get-Seed
                        While ($Password.ContainsKey($Index)){
                            $Index = Get-Seed                        
                        }
                        $Password.Add($Index,$AllChars[((Get-Seed) % $AllChars.Count)])
                    }
                    $(-join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value)) | ConvertTo-SecureString -AsPlainText -Force
                }
            }
        }
    Set-ADAccountPassword $Username -Reset -NewPassword $($Password = Get-GeneratedPassword ; $Password)
    Set-ADUser $Username -Enabled $True 
    Return $Password
    }
    Clear-Host
    "`nThe new password is $([System.Runtime.InteropServices.Marshal]::PtrToStringUni([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($($Password))))"
    Get-PhoneticSpelling $([System.Runtime.InteropServices.Marshal]::PtrToStringUni([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($($Password))))
    $Password = $null
    }

Function Get-ADAccountInfo {
    Param(
        [Parameter(Mandatory=$True)][string]$Username
        )
    Select-Zone
    $Creds = Get-Credential -UserName "$($Script:zones[$Script:chosenzone].Name)\$($env:username)-admin" -Message "Please enter administrative credentials for $($Script:zones[$Script:chosenzone].Name)."
    Try {
        $ErrorActionPreference = "Stop"
        $ADUser = Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser $($Username) -Properties Title,Enabled,pwdlastset,LockedOut ; New-Object PSCustomObject -Property @{"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge)} }
        }
        Catch {
            Do {
                Try {
                    Clear-Host
                    Write-Host "User $($Username) not found, please retype the username below or use Ctrl-C to exit." -ForegroundColor Red
                    $Username = Read-Host -Prompt "Username"
                    $ADUser = Invoke-Command -UseSSL -ComputerName $($Script:zones[$Script:chosenzone].ServerName) -Credential $Creds -ArgumentList $Username -ScriptBlock { Param( $Username ) Import-Module ActiveDirectory ; $ADUser = Get-ADUser "$($Username)" -Properties Title,Enabled,pwdlastset,Lockedout ; New-Object PSCustomObject -Property @{"samaccountname"=$ADUser.samaccountname;"enabled"=$ADUser.Enabled;"LockedOut"=$ADUser.LockedOut;"PwdLastSet"=$([datetime]::FromFileTime($ADuser.pwdlastset));"MaxPwdAge"=$((Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge)}}
                    }
                    Catch {
                        $ADUser = $null
                        }
                }
                Until ($ADUser)
            }
        Finally {
            $ErrorActionPreference = "Continue"
            }

    Write-Host -ForegroundColor Green "Account ID: $($ADUser.samaccountname)"
            Write-Host -ForegroundColor Green "Name: $($ADUser.Name)"
            Write-Host -ForegroundColor Green "Title: $($ADUser.Title)"
            If ($ADUser.pwdLastSet -eq 0) {
                Write-Host -ForegroundColor Red "This account is set to force a password change on next logon."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not set to force a password change."
                    }
            If ($ADUser.Enabled -eq $False) {
                Write-Host -ForegroundColor Red "This account is disabled."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account is not disabled."
                    }
            If ($ADUser.LockedOut -eq $False) {
                Write-Host -ForegroundColor Green "This account is not locked out."
                }
                Else {
                    Write-Host -ForegroundColor Red "This account is locked out."
                    }
            If (($ADUser.PwdLastSet + $ADUser.MaxPwdAge) -lt $(Get-Date)) {
                Write-Host -ForegroundColor Red "This account's password is expired and must be changed."
                }
                Else {
                    Write-Host -ForegroundColor Green "This account's password expires in $((($ADUser.PwdLastSet + $ADUser.MaxPwdAge) - (Get-Date)).Days) days."
                    }
    }