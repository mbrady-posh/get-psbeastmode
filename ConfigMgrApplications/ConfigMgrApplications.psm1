


<#

    .SYNOPSIS

    This function creates a Configuration Manager application and deploys it to a test collection.

    .DESCRIPTION

    See readme for setup details. This script creates an application and deploys it to a test collection. Configuration Manager module is required. Written by Michael Brady
    
    .PARAMETER SoftwareName

    This mandatory parameter specifies the software name to be processed. The use of quotes is advised.

    .PARAMETER SoftwareVersion

    This mandatory parameter specifies the software version to be processed. The use of quotes is advised.

    .PARAMETER XMLPath

    This optional parameter allows the user to specify a path to an XML file to use for script input (instead of this being given in the script itself.)

    .EXAMPLE

    Process-CMApplication -SoftwareName "Test Software" -SoftwareVersion "1" -XMLPath "\\CONTOSO\deploy.xml"

    Create a Test version 1 application in configuration manager and deploy to a test collection based on the XML specified.

    .EXAMPLE

    Process-CMApplication -SoftwareName "Stats" -SoftwareVersion "8.5"

    Create a Stats version 8.5 application in configuration manager and deploy to a test collection. All variables must be specified in the script.

#>

function Test-CMApplication {
    [CmdletBinding()]
        Param(
            [Parameter (Mandatory=$True,Position=0)]
                [string]$SoftwareName,
             [Parameter (Mandatory=$True,Position=1)]
                [string]$SoftwareVersion,
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
    $SoftwareRepo = $XMLData.AppDeploy.SoftwareRepo
    $ApplicationNamePrefix = $XMLData.AppDeploy.AppPrefix
    $TestCollectionName = $XMLData.AppDeploy.TestCollName
    $CMSite = $XMLData.AppDeploy.CMSite
    $CMSiteServer = $XMLData.AppDeploy.CMSiteServer
    $CMDPName = $XMLData.AppDeply.CMDPName

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


    $ScriptDeploymentDetection = Get-Content "$SoftwareRepo\$SoftwareName\$SoftwareVersion\$($SoftwareName)_detection.ps1"

    Switch ($SoftwareName) {
        "Test" { $EstInstallTime = 30 ; $MaxInstallTime = 120 ; $InstallBehaviorType = "InstallForSystem" }
        }

    $Deploymenttypeparams = @{ ApplicationName  = $ApplicationName
                                                            DeploymentTypeName = "$SoftwareName $SoftwareVersion"
                                                            ManualSpecifyDeploymentType = $True
                                                            DetectDeploymentTypeByCustomScript = $True
                                                            ScriptContent = $ScriptDeploymentDetection
                                                            ScriptInstaller = $True
                                                            ScriptType = 'Powershell'
                                                            AllowClientsToShareContentOnSameSubnet = $False
                                                            ContentLocation = "$SoftwareRepo\$SoftwareName\$SoftwareVersion"
                                                            InstallationProgram = "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -File $($SoftwareName)_autoinstall.ps1"
                                                            InstallationBehaviorType = $InstallBehaviorType
                                                            LogonRequirementType = 'OnlyWhenNoUserLoggedOn'
                                                            EstimatedInstallationTimeMinutes = $EstInstallTime
                                                            MaximumAllowedRunTimeMinutes = $MaxInstallTime
                                                            InstallationProgramVisibility = 'Hidden'
                                                            }

    $ApplicationDeploymentparams = @{ CollectionName = $TestCollectionName
                                                                               Name = $ApplicationName
                                                                               AppRequiresApproval = $False
                                                                               AvaliableDate = (Get-Date)
                                                                               AvaliableTime = (Get-Date)
                                                                               DeadlineDate = (Get-Date)
                                                                               DeadlineTime = (Get-Date)
                                                                               DeployAction = 'Install'
                                                                               DeployPurpose = 'Required'
                                                                               OverrideServiceWindow = $True
                                                                               PreDeploy = $False
                                                                               RebootOutsideServiceWindow = $False
                                                                               UserNotification = 'HideAll'
                                                                               }

    Try {
        Write-Verbose "Creating application $ApplicationNamePrefix - $SoftwareName - $SoftwareVersion"
        Set-Location "$($CMSite):\"
        New-CMApplication -Name $ApplicationName -Autoinstall $True -LocalizedApplicationName $SoftwareName | Out-Null
        }
        Catch {
            Write-Error $error[0]
            Throw "Application could not be created. Exiting script."
            }

    Try {
        Write-Verbose "Creating deployment type for $SoftwareName"
        Set-Location "$($CMSite):\"
        Add-CMDeploymentType @Deploymenttypeparams
        }
        Catch {
            Write-Error $error[0]
            Throw "Deployment Type could not be created. Exiting script."
            }

    Try {
        Write-Verbose "Distributing application content to DP."
        Set-Location "$($CMSite):\"
        Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointName $CMDPName
        }
        Catch {
            Write-Error $error[0]
            Throw "Application content distribution failed. Exiting script."
            }

    Try {
        Write-Verbose "Initiating deployment to test collection."
        Set-Location "$($CMSite):\"
        Start-CMApplicationDeployment @ApplicationDeploymentparams
        }
        Catch {
            Write-Error $error[0]
            Throw "Application Deployment failed. Exiting script."
            }    

    Set-Location $OriginalPath
}

<#

    .SYNOPSIS

    This function handles the replacement of one Configuration Manager application with a new version and deploys to the collection set up in production.

    .DESCRIPTION

    See readme for setup details. This function will remove old deployments, including a test deployment, mark the old application as deprecated, edit production collections to keep query rules up to date, and deploy the new application to its assigned collection. Configuration Manager module is required. Written by Michael Brady.
    
    .PARAMETER SoftwareName

    This mandatory parameter specifies the software name to be processed. The use of quotes is advised.

    .PARAMETER SoftwareVersion

    This mandatory parameter specifies the software version to be processed. The use of quotes is advised.

    .PARAMETER XMLPath

    This optional parameter allows the user to specify a path to an XML file to use for script input (instead of this being given in the script itself.)

    .EXAMPLE

    Start-CMProductionDeployment -SoftwareName "Test Software" -SoftwareVersion "2" -XMLPath "\\CONTOSO\deploy.xml"

    Deprecate previous versions of Test Software and issue a new production deployment based on the XML specified.

    .EXAMPLE

    Start-CMProductionDeployment-SoftwareName "Stats" -SoftwareVersion "8.5"

    Deprecate previous versions of Stats and issue a new production deployment. All variables must be specified in the script.

#>

function Start-CMProductionDeployment {
    [CmdletBinding()]
        Param(
            [Parameter (Mandatory=$True,Position=0)]
                [string]$SoftwareName,
            [Parameter (Mandatory=$True,Position=1)]
                [string]$SoftwareVersion,
            [Parameter(Mandatory=$False,Position=2)]
                [string]$XMLpath
            )

    # Import XML file and assign variables
    If (-Not($XMLpath)) {
        [xml]$XMLData = [xml](Get-Content -Path "")
        Write-Verbose "Proceeding with XML path in script."
        }
        Else {
            If (Test-Path ($XMLpath)) {
                Write-Verbose "Using given path to XML: $XMLpath"
                [xml]$XMLData = [xml](Get-Content -Path $XMLpath)
                }
                Else {
                    Throw "XML path given could not be found. Please check the value given for the parameter and try again."
                    }
            }

    $OriginalPath = (Get-Location).Path

    # Assign variables from XML
    $SoftwareRepo = $XMLData.AppDeploy.SoftwareRepo
    $ApplicationNamePrefix = $XMLData.AppDeploy.AppPrefix
    $TestCollectionName = $XMLData.AppDeploy.TestCollName
    $CMSite = $XMLData.AppDeploy.CMSite
    $CMSiteServer = $XMLData.AppDeploy.CMSiteServer
    $CMDPName = $XMLData.AppDeply.CMDPName

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

    # Delete test deployment and rename old application for archive
    Set-Location "$($CMSite):\"
    $OldApplications = (Get-CMApplication | Where-Object LocalizedDisplayName -like "$($ApplicationNamePrefix) - $($SoftwareName)*")
    Foreach ($OldApplication in $OldApplications) {
        Try {
            Set-Location "$($CMSite):\"
            Write-Verbose "Removing the production deployment for $($OldApplication.LocalizedDisplayName) if it exists."
            Remove-CMDeployment -ApplicationName $OldApplication.LocalizedDisplayName -CollectionName "$($ApplicationNamePrefix) - $SoftwareName Install" -Force
            Write-Verbose "Removing the testing deployment for $($OldApplication.LocalizedDisplayName) if it exists."
            Remove-CMDeployment -ApplicationName $OldApplication.LocalizedDisplayName -CollectionName $TestCollectionName -Force
            }
            Catch {
                Write-Error $error[0]
                Throw "Removing old deployments failed. Exiting Script."
                }
        If ($($OldApplication.LocalizedDisplayName) -notlike $ApplicationName) {
            Write-Verbose "$($OldApplication.LocalizedDisplayName) must be deprecated, renaming."
            $SplitAppName = ($OldApplication.LocalizedDisplayName).Split("-")
            Try {
                Set-CMApplication -InputObject $OldApplication -NewName "$($SplitAppName[0])- `#$($SplitAppName[1])"
                }
                Catch {
                    Write-Error $error[0]
                    Throw "Setting new application name failed. Exiting Script."
                    }
            }
        }

    # Rename "installed" collection
    $InstalledCollection = Get-CMDeviceCollection | Where-Object Name -like "$ApplicationNamePrefix - $SoftwareName * Installed"
    If ($InstalledCollection.Count -eq 1) {
        Try {
            Write-Verbose "InstalledCollection variable is valid, proceeding."
            Set-Location "$($CMSite):\"
            Set-CMDeviceCollection -InputObject $InstalledCollection -NewName "$ApplicationNamePrefix - $SoftwareName $SoftwareVersion Installed" -LimitingCollectionName "$ApplicationNamePrefix - $SoftwareName Limiting"
            }
            Catch {
                Write-Error $error[0]
                Throw "Setting new Collection name failed. Exiting Script."                
                }
        }
        Else {
            Write-Warning "More than one collection matches ""$ApplicationNamePrefix - $SoftwareName * Installed"". Collection not renamed, but script will continue."
            $InstalledCollection = $null
            }
           
    # Refresh $InstalledCollection object
    $InstalledCollection = Get-CMDeviceCollection | Where-Object Name -like "$ApplicationNamePrefix - $SoftwareName * Installed"
    
    # Delete old query rule
    If ($InstalledCollection -ne $null) {
        Try {
            Write-Verbose "Deleting outdated query rule."
            Remove-CMDeviceCollectionQueryMembershipRule -Collection $InstalledCollection -RuleName $($InstalledCollection.CollectionRules.RuleName) -Force
            }
            Catch {
                Write-Error $error[0]
                Throw "Removing query membership rule failed. Exiting Script."
                }
        }
        Else {
            Write-Warning "InstalledCollection variable is null; continuing script without removing existing query rule."
            }

    # Add new query rule
    If ($InstalledCollection -ne $null) {
        Try {
            Write-Verbose "Creating updated query membership rule."
            Set-Location $env:SystemDrive ; $WQLdetection = Get-Content -Path "$SoftwareRepo\$SoftwareName\$SoftwareVersion\$($SoftwareName)_wqldetection.txt" ; Set-Location "$($CMSite):\"
            Add-CMDeviceCollectionQueryMembershipRule -Collection $InstalledCollection -RuleName "$SoftwareName $softwareVersion" -QueryExpression $WQLdetection
            }
            Catch {
                Write-Error $error[0]
                Throw "Adding query membership rule failed. Exiting script."
                }
        }
        Else {
            Write-Warning "InstalledCollection variable is null; continuing script without adding new query rule."
            }

    # Deploy application to collection
    # Refresh "Installed collection" variable to check query rule
    $InstalledCollection = Get-CMDeviceCollection | Where-Object Name -like "$ApplicationNamePrefix - $SoftwareName * Installed"
    If ($InstalledCollection.CollectionRules.RuleName -eq "$SoftwareName $SoftwareVersion") {

        # Splatting application deployment parameters
        $ApplicationDeploymentparams = @{ CollectionName = "$($ApplicationNamePrefix) - $SoftwareName Install"
                                                                                   Name = $ApplicationName
                                                                                   AppRequiresApproval = $False
                                                                                   AvaliableDate = (Get-Date)
                                                                                   AvaliableTime = (Get-Date)
                                                                                   DeadlineDate = (Get-Date)
                                                                                   DeadlineTime = (Get-Date)
                                                                                   DeployAction = 'Install'
                                                                                   DeployPurpose = 'Required'
                                                                                   OverrideServiceWindow = $True
                                                                                   PreDeploy = $False
                                                                                   RebootOutsideServiceWindow = $False
                                                                                   UserNotification = 'HideAll'
                                                                                   }
        Try {
            Write-Verbose "Deploying application to production collection."
            Start-CMApplicationDeployment @ApplicationDeploymentparams
            }
            Catch {
                Write-Error $error[0]
                 Throw "Application Deployment failed. Exiting script."
                 }

    # Refresh "needed" collection
    Try {
        Write-Verbose "Refreshing production collection membership."
        $TargetCollection = Get-CMDeviceCollection -Name "$ApplicationNamePrefix - $SoftwareName Install"
        Set-Location "$($env:SystemDrive)\"
        Invoke-WmiMethod -Path "ROOT\SMS\Site_$($CMSite):SMS_Collection.CollectionId='$($TargetCollection.CollectionID)'" -Name RequestRefresh -ComputerName $CMSiteServer | Out-Null
        Set-Location "$($CMSite):\"
        }
        Catch {
            Write-Error $error[0]
            Write-Warning "Unable to refresh collection membership. Continuing script."
            }
        }
        Else {
            Throw "Query rule was not updated, so not deploying to collection. Exiting script."
            }

    Set-Location $OriginalPath               
}