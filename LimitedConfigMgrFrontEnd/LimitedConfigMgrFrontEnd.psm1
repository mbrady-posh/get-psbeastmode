# TODO : comment-based help



Function Add-CMDevicetoInstallCollection {
    [CmdletBinding()]
    Param( )

    $SiteCode = "" # Configuration Manager site code
    $SiteRoot = "" # Configuration Manager site server FQDN
    $LimitingCollection = "" # CollectionID of root or main limiting collection for device objects being manipulated

    # Begin boilerplate .Net code 
                    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
                    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

                    $PCNameForm = New-Object System.Windows.Forms.Form 
                    $PCNameForm.Text = "Computer Name"
                    $PCNameForm.Size = New-Object System.Drawing.Size(300,200) 
                    $PCNameForm.StartPosition = "CenterScreen"

                    $PCNameForm.KeyPreview = $True
                    $PCNameForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
                        {$script:ComputerName=$PCNameBox.Text;$PCNameForm.Close()}})
                    $PCNameForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
                        {$script:ComputerName=$null;$PCNameForm.Close()}})

                    $OKButton0 = New-Object System.Windows.Forms.Button
                    $OKButton0.Location = New-Object System.Drawing.Size(75,120)
                    $OKButton0.Size = New-Object System.Drawing.Size(75,23)
                    $OKButton0.Text = "OK"
                    $OKButton0.Add_Click({$script:ComputerName=$PCNameBox.Text;$PCNameForm.Close()})
                    $PCNameForm.Controls.Add($OKButton0)

                    $CancelButton0 = New-Object System.Windows.Forms.Button
                    $CancelButton0.Location = New-Object System.Drawing.Size(150,120)
                    $CancelButton0.Size = New-Object System.Drawing.Size(75,23)
                    $CancelButton0.Text = "Cancel"
                    $CancelButton0.Add_Click({$script:ComputerName=$null;$PCNameForm.Close()})
                    $PCNameForm.Controls.Add($CancelButton0)

                    $PCNameLabel = New-Object System.Windows.Forms.Label
                    $PCNameLabel.Location = New-Object System.Drawing.Size(10,20) 
                    $PCNameLabel.Size = New-Object System.Drawing.Size(280,20) 
                    $PCNameLabel.Text = "Please enter the computer name:"
                    $PCNameForm.Controls.Add($PCNameLabel) 

                    $PCNameBox = New-Object System.Windows.Forms.TextBox 
                    $PCNameBox.Location = New-Object System.Drawing.Size(10,40) 
                    $PCNameBox.Size = New-Object System.Drawing.Size(260,20) 
                    $PCNameForm.Controls.Add($PCNameBox) 
    # End Form 1

                    $objForm = New-Object System.Windows.Forms.Form 
                    $objForm.Text = "Software Install"
                    $objForm.Size = New-Object System.Drawing.Size(300,500) 
                    $objForm.StartPosition = "CenterScreen"

                    $objForm.KeyPreview = $True
                    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
                        {$x=$objListBox.SelectedItem;$objForm.Close()}})
                    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
                        {$script:SelectedSoftwareName=$null;$objForm.Close()}})

                    $OKButton = New-Object System.Windows.Forms.Button
                    $OKButton.Location = New-Object System.Drawing.Size(75,420)
                    $OKButton.Size = New-Object System.Drawing.Size(75,23)
                    $OKButton.Text = "OK"
                    $OKButton.Add_Click({$script:SelectedSoftwareName=$objListBox.SelectedItem;$objForm.Close()})
                    $objForm.Controls.Add($OKButton)

                    $CancelButton = New-Object System.Windows.Forms.Button
                    $CancelButton.Location = New-Object System.Drawing.Size(150,420)
                    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
                    $CancelButton.Text = "Cancel"
                    $CancelButton.Add_Click({$script:SelectedSoftwareName=$null;$objForm.Close()})
                    $objForm.Controls.Add($CancelButton)

                    $objLabel = New-Object System.Windows.Forms.Label
                    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
                    $objLabel.Size = New-Object System.Drawing.Size(280,20) 
                    $objLabel.Text = "Select the software to be installed"
                    $objForm.Controls.Add($objLabel) 

                    $objListBox = New-Object System.Windows.Forms.ListBox 
                    $objListBox.Location = New-Object System.Drawing.Size(10,40) 
                    $objListBox.Size = New-Object System.Drawing.Size(260,320) 
                    $objListBox.Height = 380
    # End boilerplate .Net code 

    # Make sure the relevant modules can be loaded: Configuration Manager
    If (-Not((Get-Module).Name.Contains("ConfigurationManager"))) {
        If (Test-Path $env:SMS_ADMIN_UI_PATH) {
            $SplitPathArray = $env:SMS_ADMIN_UI_PATH.Split("\")
            $ModulePath = $SplitPathArray[0] + "\" + $SplitPathArray[1] + "\" + $SplitPathArray[2] + "\" + $SplitPathArray[3] + "\" + "ConfigurationManager.psd1"
            $VerbosePreference = "SilentlyContinue" ; Import-Module $ModulePath ; $VerbosePreference = "Continue"
            Try {
                Write-Verbose "Creating PSDrive $($SiteCode):\"
                New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $SiteRoot | Out-Null
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

    $script:OriginalPath = (Get-Location).Path

    Set-Location "$($SiteCode):\"

    # Get and validate computer name
                   Do {
                        # Display form
                        $PCNameForm.Topmost = $True
                        $PCNameForm.Add_Shown({$PCNameForm.Activate()})
                        [void] $PCNameForm.ShowDialog()
                        If ($script:ComputerName -ne $null) {
                            $Deviceobject = Get-CMDevice -Name $ComputerName -CollectionId $LimitingCollection
                            }
                            Else {
                                Exit 1
                                }
                        }
                        Until (  $DeviceObject )

    # Get list of collections and display friendly names in select box
    Write-Output "Getting software list, please wait..."
    $SoftwareCollections = Get-CMDeviceCollection | Where-Object { $_.Name -like "*Limiting" } | Sort-Object -Property Name # If desired, edit the syntax used to search for appropriate collections
    Foreach ($Collection in $SoftwareCollections) {
        Add-Member -InputObject $Collection -MemberType NoteProperty -Name "ShortName" -Value ($Collection.Name).TrimEnd("Limiting").Substring(6)
        [void] $objListBox.Items.Add("$($Collection.ShortName)")
        }

    # Display form
                   $objForm.Controls.Add($objListBox) 
                    $objForm.Topmost = $True
                    $objForm.Add_Shown({$objForm.Activate()})
                    [void] $objForm.ShowDialog()
        If ($SelectedSoftwareName -ne $null) {
            $SelectedSoftwareCollection = $SoftwareCollections | Where-Object { $_.ShortName -eq "$SelectedSoftwareName" }
            }
            Else {
                Exit 1
                }
        
        Try {
            $OriginalEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            Add-CMDeviceCollectionDirectMembershipRule -CollectionId $($SelectedSoftwareCollection.CollectionID) -Resource $DeviceObject
            }
            Catch [System.ArgumentException] {
                    $ErrorActionPreference = $OriginalEAP
                    Write-Error "Machine has already been added to the collection."
                    Start-Sleep -Seconds 30
                    }
            Catch {
                $ErrorActionPreference = $OriginalEAP
                Write-Error $error[0]
                Write-Error "Adding device to the collection failed. Contact a technician for assistance."
                Start-Sleep -Seconds 30
                Exit 1
                }
            Finally {
                $ErrorActionPreference = $OriginalEAP
                }

            Try {
                $ErrorActionPreference = "Stop"
                Invoke-WmiMethod -Path root\ccm:sms_client -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}" -ComputerName $ComputerName -Credential (Get-Credential -Message "Enter administrative credentials.") | Out-Null
                }
                Catch {
                    $ErrorActionPreference = $OriginalEAP
                    Write-Error $error[0]
                    Write-Error "Machine policy refresh failed."
                    Start-Sleep -Seconds 30
                    }
                Finally {
                    $ErrorActionPreference = $OriginalEAP
                    }

    Set-Location $OriginalPath
}

Function Add-CMDevicetoImagingCollection {
    [CmdletBinding()]
        Param( )

    $SiteCode = "" # Configuration Manager site code
    $SiteRoot = "" # Configuration Manager site server FQDN
    $LimitingCollection = "" # CollectionID of root or main limiting collection for device objects being manipulated
    $ImagingCollection = "" # CollectionID of collection with Task Sequence(s) deployed to it

    # Begin boilerplate .Net code 
                    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
                    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

                    $PCNameForm = New-Object System.Windows.Forms.Form 
                    $PCNameForm.Text = "Computer Name"
                    $PCNameForm.Size = New-Object System.Drawing.Size(300,200) 
                    $PCNameForm.StartPosition = "CenterScreen"

                    $PCNameForm.KeyPreview = $True
                    $PCNameForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
                        {$script:ComputerName=$PCNameBox.Text;$PCNameForm.Close()}})
                    $PCNameForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
                        {$script:ComputerName=$null;$PCNameForm.Close()}})

                    $OKButton0 = New-Object System.Windows.Forms.Button
                    $OKButton0.Location = New-Object System.Drawing.Size(75,120)
                    $OKButton0.Size = New-Object System.Drawing.Size(75,23)
                    $OKButton0.Text = "OK"
                    $OKButton0.Add_Click({$script:ComputerName=$PCNameBox.Text;$PCNameForm.Close()})
                    $PCNameForm.Controls.Add($OKButton0)

                    $CancelButton0 = New-Object System.Windows.Forms.Button
                    $CancelButton0.Location = New-Object System.Drawing.Size(150,120)
                    $CancelButton0.Size = New-Object System.Drawing.Size(75,23)
                    $CancelButton0.Text = "Cancel"
                    $CancelButton0.Add_Click({$script:ComputerName=$null;$PCNameForm.Close()})
                    $PCNameForm.Controls.Add($CancelButton0)

                    $PCNameLabel = New-Object System.Windows.Forms.Label
                    $PCNameLabel.Location = New-Object System.Drawing.Size(10,20) 
                    $PCNameLabel.Size = New-Object System.Drawing.Size(280,20) 
                    $PCNameLabel.Text = "Please enter the computer name:"
                    $PCNameForm.Controls.Add($PCNameLabel) 

                    $PCNameBox = New-Object System.Windows.Forms.TextBox 
                    $PCNameBox.Location = New-Object System.Drawing.Size(10,40) 
                    $PCNameBox.Size = New-Object System.Drawing.Size(260,20) 
                    $PCNameForm.Controls.Add($PCNameBox) 
    # End Form 1

    # Make sure the relevant modules can be loaded: Configuration Manager
    If (-Not((Get-Module).Name.Contains("ConfigurationManager"))) {
        If (Test-Path $env:SMS_ADMIN_UI_PATH) {
            $SplitPathArray = $env:SMS_ADMIN_UI_PATH.Split("\")
            $ModulePath = $SplitPathArray[0] + "\" + $SplitPathArray[1] + "\" + $SplitPathArray[2] + "\" + $SplitPathArray[3] + "\" + "ConfigurationManager.psd1"
            $VerbosePreference = "SilentlyContinue" ; Import-Module $ModulePath ; $VerbosePreference = "Continue"
            Try {
                Write-Verbose "Creating PSDrive $($SiteCode):\"
                New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $SiteRoot | Out-Null
                }
                Catch {
                    $ErrorActionPreference = $OriginalEAP
                    Throw "PSDrive could not be created. Check permissions to your CM Site. Exiting Script."
                    }
            }
            Else {
                $ErrorActionPreference = $OriginalEAP
                Throw "Configuration Manager module could not be located or loaded. Exiting script."
                }
            }
        Else {
            Write-Verbose "Configuration Manager module already loaded."
            }

    $script:OriginalPath = (Get-Location).Path

    Set-Location "$($SiteCode):\"

    # Get and validate computer name
                   Do {
                        # Display form
                        $PCNameForm.Topmost = $True
                        $PCNameForm.Add_Shown({$PCNameForm.Activate()})
                        [void] $PCNameForm.ShowDialog()
                        If ($script:ComputerName -ne $null) {
                            $Deviceobject = Get-CMDevice -Name $ComputerName -CollectionId $LimitingCollection
                            }
                            Else {
                                Exit 1
                                }
                        $Deviceobject = Get-CMDevice -Name $ComputerName -CollectionId $LimitingCollection
                        }
                        Until (  $DeviceObject )
        Try {
            $OriginalEAP = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            Add-CMDeviceCollectionDirectMembershipRule -CollectionId $ImagingCollection -Resource $DeviceObject
            }
            Catch [System.ArgumentException] {
                   $ErrorActionPreference = $OriginalEAP
                    Write-Error "Machine has already been added to the collection."
                    Start-Sleep -Seconds 30
                    Exit 1
                    }                  
            Catch {
               $ErrorActionPreference = $OriginalEAP
                Write-Error $error[0]
                Write-Error "Adding device to the collection failed. Contact a technician for assistance."
                Start-Sleep -Seconds 30
                Exit 1
                }
            Finally {
                $ErrorActionPreference = $OriginalEAP
                }

    Set-Location $OriginalPath

    }