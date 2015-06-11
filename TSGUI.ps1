[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

Try {
    $TSProgressUI = New-Object -ComObject Microsoft.SMS.TSProgressUI
    $TSProgressUI.CloseProgressDialog()
    $TSProgressUI = $null
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $TSEnv.Value("SMSTSAssignUsersMode") = "Auto"
    If ($TSEnv.Value("_SMSTSMACHINENAME")) {
        $TSComputerName = $TSEnv.Value("_SMSTSMACHINENAME")
        }
        Else {
            $TSComputerName = ""
            }
    }
    Catch {
        Exit 1
        }

$PHUsernames = Import-Csv -Path "$PSScriptRoot\PHUsers.csv"

# Start form code

$form = New-Object System.Windows.Forms.Form 
$form.Text = "Task Sequence Form"
$form.Size = New-Object System.Drawing.Size(500,500) 
$form.StartPosition = "CenterScreen"

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(212,420)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$OKButton.Enabled = 0
$form.AcceptButton = $OKButton
$form.Controls.Add($OKButton)

$ComputerNameBox = New-Object System.Windows.Forms.TextBox 
$ComputerNameBox.Location = New-Object System.Drawing.Point(120,40) 
$ComputerNameBox.Size = New-Object System.Drawing.Size(260,20)
$ComputerNameBox.Text = $TSComputerName
$ComputerNameBox.TextAlign = "Center"
$handler_ComputerNameBox_KeyUp= {
    If (($TSTypeBox.Text -like "Onsite") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text)) {
            $OKButton.Enabled = 1
            }
        ElseIf (($TSTypeBox.Text -like "Offsite*") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text) -and ($LocalUserNameBox.Text)) {
            $OKButton.Enabled = 1
            }
        Else {
            $OKButton.Enabled = 0
            }
    }
$ComputerNameBox.add_KeyUp($handler_ComputerNameBox_KeyUp)
$form.Controls.Add($ComputerNameBox)

$ComputerNameBoxlabel = New-Object System.Windows.Forms.Label
$ComputerNameBoxlabel.Location = New-Object System.Drawing.Point(190,20) 
$ComputerNameBoxlabel.Size = New-Object System.Drawing.Size(120,20)
$ComputerNameBoxlabel.Text = "Computer Name"
$ComputerNameBoxlabel.TextAlign = "MiddleCenter"
$form.Controls.Add($ComputerNameBoxlabel)

$TSTypeBox = New-Object System.Windows.Forms.ComboBox
$TSTypeBox.Location = New-Object System.Drawing.Point(190,120)
$TSTypeBox.Size = New-Object System.Drawing.Size(120,20)
$TSTypeBox.DropDownStyle = "DropDownList"
$handler_TSTypeBox_SelectedIndexChanged= {
    If ($TSTypeBox.Text -eq "Onsite") {
        $LocalUserNameBox.Enabled = 0
        $LocalUserNameBox.Text = ""
        }
        ElseIf ($TSTypeBox.Text -like "Offsite*") {
            $LocalUserNameBox.Enabled = 1
            }
    If (($TSTypeBox.Text -like "Onsite") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text)) {
            $OKButton.Enabled = 1
            }
        ElseIf (($TSTypeBox.Text -like "Offsite*") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text) -and ($LocalUserNameBox.Text)) {
            $OKButton.Enabled = 1
            }
        Else {
            $OKButton.Enabled = 0
            }
    }
Foreach ($item in ("Onsite","Offsite","Offsite w/BL")) {
    $TSTypeBox.Items.Add($item) | Out-Null
    }
$TSTypeBox.add_SelectedIndexChanged($handler_TSTypeBox_SelectedIndexChanged)
$Laptopchassismatch = "9","10","14"
If ((Get-WmiObject -Class Win32_Battery) -or ($Laptopchassismatch -contains (Get-WmiObject -Class Win32_SystemEnclosure -Property Chassistypes).Chassistypes))  {
    $TSTypeBox.SelectedIndex = 2
    }
    Else {
        $TSTypeBox.SelectedIndex = 0
        }
$form.Controls.Add($TSTypeBox)

$TSTypeBoxlabel = New-Object System.Windows.Forms.Label
$TSTypeBoxlabel.Location = New-Object System.Drawing.Point(190,100)
$TSTypeBoxlabel.Size = New-Object System.Drawing.Size(120,20)
$TSTypeBoxlabel.Text = "Task sequence type"
$TSTypeBoxlabel.TextAlign = "MiddleCenter"
$form.Controls.Add($TSTypeBoxlabel)

$UserComboBox = New-Object System.Windows.Forms.ComboBox
$UserComboBox.Location = New-Object System.Drawing.Point(60,200)
$UserComboBox.Size = New-Object System.Drawing.Size(200,20)
$UserComboBox.AutoCompleteMode = "SuggestAppend"
$UserComboBox.AutoCompleteSource = "ListItems"
Foreach ($item in $PHUsernames) {
    $UserComboBox.Items.Add($item.samaccountname)
    }
$handler_UserComboBox_SelectedIndexChanged= {
    If ($TSTypeBox.Text -like "Offsite*") {
        $LocalUserNameBox.Text = ($PHUsernames | Foreach-Object {If ($_.samaccountname -like "$($UserComboBox.Text)") { $_.givenName } }).ToLower()
        }
    If (($TSTypeBox.Text -like "Onsite") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text)) {
            $OKButton.Enabled = 1
            }
        ElseIf (($TSTypeBox.Text -like "Offsite*") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text) -and ($LocalUserNameBox.Text)) {
            $OKButton.Enabled = 1
            }
        Else {
            $OKButton.Enabled = 0
            }
    }
$handler_UserComboBox_KeyUp= {
    If (($TSTypeBox.Text -like "Offsite*") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text) -and ($LocalUserNameBox.Text)) {
        $OKButton.Enabled = 1
        }
        ElseIf (($TSTypeBox.Text -like "Onsite") -and ($ComputerNameBox.Text) -and ($UserComboBox.Text)) {
            $OKButton.Enabled = 1
            }
        Else {
            $OKButton.Enabled = 0
            }
    }
$UserComboBox.add_SelectedIndexChanged($handler_UserComboBox_SelectedIndexChanged)
$UserComboBox.add_KeyUp($handler_UserComboBox_KeyUp)
$form.Controls.Add($UserComboBox)

$UserComboBoxlabel = New-Object System.Windows.Forms.Label
$UserComboBoxlabel.Location = New-Object System.Drawing.Point(60,180)
$UserComboBoxlabel.Size = New-Object System.Drawing.Size(200,20)
$UserComboBoxlabel.Text = "Assigned User"
$UserComboBoxlabel.TextAlign = "MiddleCenter"
$form.Controls.Add($UserComboBoxlabel)

$PrimarymachineCheck = New-Object System.Windows.Forms.CheckBox
$PrimarymachineCheck.Location = New-Object System.Drawing.Point(380,200)
$Laptopchassismatch = "9","10","14"
If ((Get-WmiObject -Class Win32_Battery) -or ($Laptopchassismatch -contains (Get-WmiObject -Class Win32_SystemEnclosure -Property Chassistypes).Chassistypes))  {
    $PrimarymachineCheck.CheckState = "Unchecked"
    }
    Else {
        $PrimarymachineCheck.CheckState = "Checked"
        }
$form.Controls.Add($PrimarymachineCheck)

$PrimarymachineChecklabel = New-Object System.Windows.Forms.Label
$PrimarymachineChecklabel.Location = New-Object System.Drawing.Point(320,180)
$PrimarymachineChecklabel.Size = New-Object System.Drawing.Size(120,20)
$PrimarymachineChecklabel.Text = "Primary System"
$PrimarymachineChecklabel.TextAlign = "MiddleCenter"
$form.Controls.Add($PrimarymachineChecklabel)

$MigrationCheck = New-Object System.Windows.Forms.CheckBox
$MigrationCheck.Location = New-Object System.Drawing.Point(380,255)
If ($TSEnv.Value("_SMSTSMACHINENAME") -like "PH-*") {
    $MigrationCheck.CheckState = "Checked"
    }
    Else {
        $MigrationCheck.CheckState = "Unchecked"
        }
$form.Controls.Add($MigrationCheck)

$MigrationChecklabel = New-Object System.Windows.Forms.Label
$MigrationChecklabel.Location = New-Object System.Drawing.Point(320,235)
$MigrationChecklabel.Size = New-Object System.Drawing.Size(120,20)
$MigrationChecklabel.Text = "Migrate User Data"
$MigrationChecklabel.TextAlign = "MiddleCenter"
$form.Controls.Add($MigrationChecklabel)

$LocalUserNameBox = New-Object System.Windows.Forms.TextBox
$LocalUserNameBox.Location = New-Object System.Drawing.Point(60,260)
$LocalUserNameBox.Size = New-Object System.Drawing.Size(200,20)
$LocalUserNameBox.TextAlign = "Center"
If ($TSTypeBox.Text -like "Onsite") {
    $LocalUserNameBox.Enabled = 0
    }
    Else {
        $LocalUserNameBox.Enabled = 1
        }
$handler_LocalUserNameBox_KeyUp= {
    If (($ComputerNameBox.Text) -and ($UserComboBox.Text) -and ($LocalUserNameBox.Text)) {
        $OKButton.Enabled = 1
        }
        Else {
            $OKButton.Enabled = 0
            }
    }
$LocalUserNameBox.add_KeyUp($handler_LocalUserNameBox_KeyUp)
$form.Controls.Add($LocalUserNameBox)

$LocalUserNameBoxlabel = New-Object System.Windows.Forms.Label
$LocalUserNameBoxlabel.Location = New-Object System.Drawing.Point(60,240)
$LocalUserNameBoxlabel.Size = New-Object System.Drawing.Size(200,20)
$LocalUserNameBoxlabel.TextAlign = "MiddleCenter"
$LocalUserNameBoxlabel.Text = "Local account username"
$form.Controls.Add($LocalUserNameBoxlabel)

$Formresult = $form.ShowDialog()

If ($Formresult -eq [System.Windows.Forms.DialogResult]::OK) {
    If ($TSEnv) {
        $TSEnv.Value("OSDComputerName") = $ComputerNameBox.Text
        If ($TSTypeBox.Text -eq "Onsite") {
            $TSEnv.Value("TSType") = 0
            }
            ElseIf ($TSTypeBox.Text -eq "Offsite") {
                $TSEnv.Value("TSType") = 1
                }
            ElseIf ($TSTypeBox.Text -eq "Offsite w/BL") {
                $TSEnv.Value("TSType") = 2
                }
        If ($MigrationCheck.CheckState -eq "Checked") {
            $TSEnv.Value("MigrateCPHSystem") = 1
            }
            Else {
                $TSEnv.Value("MigrateCPHSystem") = 0
                }
        $TSEnv.Value("BaseUserName") = $LocalUserNameBox.Text
        If ($PrimarymachineCheck.Checked -eq $True) {
            $TSEnv.Value("PrimarySystem") = 1
            $TSEnv.Value("SMSTSUdaUsers") = "iowa\$($UserComboBox.Text)"
            }
        }
        Else {
            $props = @{"Name"=$ComputerNameBox.Text;"TSType"=$TSTypeBox.Text;"User"=$UserComboBox.Text;"PrimarySystem"=$PrimarymachineCheck.CheckState;"LocalUser"=$LocalUserNameBox.Text;"Migration"=$MigrationCheck.CheckState;}
            New-Object PSCustomObject -Property $props | Select Name,TSType,User,PrimarySystem,LocalUser,Migration
            }
    }

If ($Form.DialogResult -eq "OK") {
    Exit 0
    }
    Else {
        Exit 1
        }