Function Update-CMClientPolicy {
    [CmdletBinding()]
        Param(
            [Parameter(ParameterSetName='byName',Mandatory=$True,Position=0)]
                [string]$ComputerName,
            [Parameter(ParameterSetName='byCollID',Mandatory=$True,Position=0)]
                [string]$CollectionID,
            [Parameter(ParameterSetName='byCollName',Mandatory=$True,Position=0)]
                [string]$CollectionName,
            [Parameter(Mandatory=$False,Position=1)]
                [string]$XMLpath
            )
    
    $OriginalPath = (Get-Location).Path

    # Import XML file and assign variables
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
    
    # Assign variables from XML
    $CMSite = $XMLData.CMUtils.CMSite
    $CMSiteServer = $XMLData.CMUtils.CMSiteServer

    $ApplicationName = "$ApplicationNamePrefix - $SoftwareName $SoftwareVersion"

    # Make sure the relevant modules can be loaded: Configuration Manager
    If (-Not((Get-Module).Name.Contains("ConfigurationManager"))) {
        If (Test-Path $env:SMS_ADMIN_UI_PATH) {
            $SplitPathArray = $env:SMS_ADMIN_UI_PATH.Split("\")
            $ModulePath = $SplitPathArray[0] + "\" + $SplitPathArray[1] + "\" + $SplitPathArray[2] + "\" + $SplitPathArray[3] + "\" + "ConfigurationManager.psd1"
            $VerbosePreference = "SilentlyContinue" ; Import-Module $ModulePath ; $VerbosePreference = "Continue"
            Try {
                Write-Verbose "Creating PSDrive $($CMSite):\"
                New-PSDrive -PSProvider CMSite -Name $CMSite -Root $CMSiteServer
                }
                Catch {
                    Throw "PSDrive could not be created. Check permissions to your CM Site. Exiting Script."
                    }
            }
            Else {
                Throw "Configuration Manager module could not be located or loaded. Exiting script."
                }
            }
        Else {
            Write-Verbose "Configuration Manager module already loaded."
            }
    
    $OriginalEAP = $ErrorActionPreference
    Set-Location "$($CMSite):\"
    If ($CollectionName) {
        Foreach ($Computer in $(((Get-CMDevice -CollectionName "$CollectionName").Name))) {
            If (Test-Connection -ComputerName $Computer -Quiet -Count 1) {
                Try {
                    $ErrorActionPreference = 'Stop'
                    $SMSClient = [wmiclass] "\\$computer\root\ccm:SMS_Client"
                    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
                    Write-Output "$Computer policy refresh succeeded."
                    }
                    Catch {
                        Write-Output "$Computer policy refresh failed."
                        }
                    Finally {
                        $ErrorActionPreference = $OriginalEAP
                        }
                }
                Else {
                    Write-Output "$Computer could not be contacted."
                    }
            }
        }
        ElseIf ($CollectionID) {
            Foreach ($Computer in $(((Get-CMDevice -CollectionId "$CollectionID").Name))) {
                If (Test-Connection -ComputerName $Computer -Quiet -Count 1) {
                    Try {
                        $ErrorActionPreference = 'Stop'
                        $SMSClient = [wmiclass] "\\$computer\root\ccm:SMS_Client"
                        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
                        Write-Output "$Computer policy refresh succeeded."
                        }
                        Catch {
                            Write-Output "$Computer policy refresh failed."
                            }
                        Finally {
                            $ErrorActionPreference = $OriginalEAP
                            }
                    }
                    Else {
                        Write-Output "$Computer could not be contacted"
                        }
                }
            }
        ElseIf ($ComputerName) {
            If (Test-Connection -ComputerName $ComputerName -Quiet -Count 1) {
                    Try {
                        $ErrorActionPreference = 'Stop'
                        $SMSClient = [wmiclass] "\\$ComputerName\root\ccm:SMS_Client"
                        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
                        Write-Output "$ComputerName policy refresh succeeded."
                        }
                        Catch {
                            Write-Output "$ComputerName policy refresh failed."
                            }
                        Finally {
                            $ErrorActionPreference = $OriginalEAP
                            }
                    }
                    Else {
                        Write-Output "$ComputerName could not be contacted"
                        }
            }
    Set-Location $OriginalPath
    }

Function Update-CMClientCache {
    [CmdletBinding()]
        Param(
            [Parameter(ParameterSetName='byName',Mandatory=$True,Position=0)]
                [string]$ComputerName,
            [Parameter(ParameterSetName='byCollID',Mandatory=$True,Position=0)]
                [string]$CollectionID,
            [Parameter(ParameterSetName='byCollName',Mandatory=$True,Position=0)]
                [string]$CollectionName,
            [Parameter(Mandatory=$True,Position=1)]
                [long]$Size,
            [Parameter(Mandatory=$False,Position=2)]
                [string]$XMLpath
            )
        $OriginalPath = (Get-Location).Path

    # Import XML file and assign variables
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
    
    # Assign variables from XML
    $CMSite = $XMLData.CMUtils.CMSite
    $CMSiteServer = $XMLData.CMUtils.CMSiteServer

    $ApplicationName = "$ApplicationNamePrefix - $SoftwareName $SoftwareVersion"

    # Make sure the relevant modules can be loaded: Configuration Manager
    If (-Not((Get-Module).Name.Contains("ConfigurationManager"))) {
        If (Test-Path $env:SMS_ADMIN_UI_PATH) {
            $SplitPathArray = $env:SMS_ADMIN_UI_PATH.Split("\")
            $ModulePath = $SplitPathArray[0] + "\" + $SplitPathArray[1] + "\" + $SplitPathArray[2] + "\" + $SplitPathArray[3] + "\" + "ConfigurationManager.psd1"
            $VerbosePreference = "SilentlyContinue" ; Import-Module $ModulePath ; $VerbosePreference = "Continue"
            Try {
                Write-Verbose "Creating PSDrive $($CMSite):\"
                New-PSDrive -PSProvider CMSite -Name $CMSite -Root $CMSiteServer
                }
                Catch {
                    Throw "PSDrive could not be created. Check permissions to your CM Site. Exiting Script."
                    }
            }
            Else {
                Throw "Configuration Manager module could not be located or loaded. Exiting script."
                }
            }
        Else {
            Write-Verbose "Configuration Manager module already loaded."
            }

    If ($Size -ge 1073741824) {
        $Suffix = "MB"
        $Size = [math]::truncate($Size/1MB)
        }
        Else {
            Throw "Size specified may be in a bad format. Please use MB or GB to indicate desired size with 1GB being the minimum."
            }
            
    $OriginalEAP = $ErrorActionPreference
    Set-Location "$($CMSite):\"
    If ($CollectionName) {
        Foreach ($Computer in $(((Get-CMDevice -CollectionName "$CollectionName").Name))) {
            If (Test-Connection -ComputerName $Computer -Quiet -Count 1) {
                Try {
                    $ErrorActionPreference = 'Stop'
                    $SMSClient = Get-WmiObject -ComputerName $Computer -Namespace root\ccm\softmgmtagent -Class CacheConfig
                    $SMSClient.Size = $Size ; $SMSClient.Put() | Out-Null
                    Write-Output "$Computer CCM cache size now $Size $Suffix."
                    }
                    Catch {
                        Write-Output "$Computer cache size change failed."
                        }
                    Finally {
                        $ErrorActionPreference = $OriginalEAP
                        }
                }
                Else {
                    Write-Output "$Computer could not be contacted."
                    }
            }
        }
        ElseIf ($CollectionID) {
            Foreach ($Computer in $(((Get-CMDevice -CollectionId "$CollectionID").Name))) {
                If (Test-Connection -ComputerName $Computer -Quiet -Count 1) {
                    Try {
                        $ErrorActionPreference = 'Stop'
                        $SMSClient = Get-WmiObject -ComputerName $Computer -Namespace root\ccm\softmgmtagent -Class CacheConfig
                        $SMSClient.Size = $Size ; $SMSClient.Put() | Out-Null
                        Write-Output "$Computer CCM cache size now $Size $Suffix."
                        }
                        Catch {
                            Write-Output "$Computer cache size change failed."
                            }
                        Finally {
                            $ErrorActionPreference = $OriginalEAP
                            }
                    }
                    Else {
                        Write-Output "$Computer could not be contacted."
                        }
                }
            }
        ElseIf ($ComputerName) {
            If (Test-Connection -ComputerName $ComputerName -Quiet -Count 1) {
                    Try {
                        $ErrorActionPreference = 'Stop'
                        $SMSClient = Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\softmgmtagent -Class CacheConfig
                        $SMSClient.Size = $Size ; $SMSClient.Put() | Out-Null
                        Write-Output "$Computername CCM cache size now $Size $Suffix."
                        }
                        Catch {
                            Write-Output "$Computername cache size change failed."
                            }
                        Finally {
                            $ErrorActionPreference = $OriginalEAP
                            }
                    }
                    Else {
                        Write-Output "$ComputerName could not be contacted"
                        }
            }
    Set-Location $OriginalPath
    }
