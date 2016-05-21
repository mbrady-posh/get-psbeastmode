Param(
    [boolean][Parameter(Mandatory=$True)]$OuttoSQL=$True,
    [string]$UserID,
    [string]$Password,
    [string]$Outpath
    )
$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

If (!$OutPath) {
    $Outpath = $ScriptPath
    }

$Serverlist = (& "$ScriptPath\Get-ActiveServers.ps1").Active | Select -ExpandProperty Name

Function AppendtoCSV($ObjecttoAppend,$FileName) {
    If (Test-Path "$($OutPath)\$($FileName).csv") {
        $ObjecttoAppend | ConvertTo-Csv -NoTypeInformation | Select -Skip 1 | Add-Content "$($OutPath)\$($FileName).csv"
        }
        Else {
            $ObjecttoAppend | ConvertTo-Csv -NoTypeInformation | Add-Content "$($OutPath)\$($FileName).csv"
            }
        }

If ($OuttoSQL -eq $True) {
    Try {
	    $UTILSQL = New-Object System.Data.SqlClient.SqlConnection
	    $UTILSQL.ConnectionString = ""
	    $UTILSQL.Open()
	    }
	    Catch {
		    Throw "Could not create connection to SQL server. Aborting."
		    }
    }

$Failures = @()
$ErrorActionPreference = "Stop"
Foreach ($Server in $Serverlist) {
    Try {
        If ((Test-Connection -Count 1 -ComputerName $Server -Quiet) -eq $True) {
            # Continue
            }
            Else {
               If ($OuttoSQL -eq $True) {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $ADObject = Get-ADComputer $Server -Properties Name, dnshostname, operatingsystem
                        $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                        $SQLAdd.Connection = $UTILSQL
                        $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$(($ADObject.dnshostname).ToUpper())',OSName='$($ADObject.operatingsystem)',Zone='$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$(($ADObject.dnshostname).ToUpper())' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,OSName,Zone,Updated) VALUES('$(($ADObject.dnshostname).ToUpper())','$($ADObject.operatingsystem)','$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                        $SQLAdd.ExecuteNonQuery() | Out-Null
                        $SQLAdd = $null
                        }
                        Catch {
                            $LDAPFilter = "(cn=$Server)"
                                    $Domain = New-Object System.DirectoryServices.DirectoryEntry
                                    $DirSearcher = New-Object System.DirectoryServices.DirectorySearcher
                                    $DirSearcher.SearchRoot = $Domain
                                    $DirSearcher.PageSize = 1000
                                    $DirSearcher.Filter = $LDAPFilter
                                    $DirSearcher.SearchScope = "Subtree"
                                    $proplist = "dnsHostName","operatingSystem"
                                    foreach ($prop in $proplist) { $DirSearcher.PropertiesToLoad.Add($prop) | Out-Null }
                                    $DirSearcher.FindAll() | Foreach-Object {$ADObject = $_.properties}

                                    $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                    $SQLAdd.Connection = $UTILSQL
                                    $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$(($ADObject.dnshostname[0]).ToUpper())',OSName='$($ADObject.operatingsystem[0])',Zone='$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$(($ADObject.dnshostname[0]).ToUpper())' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,OSName,Zone,Updated) VALUES('$(($ADObject.dnshostname[0]).ToUpper())','$($ADObject.operatingsystem[0])','$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                                    $SQLAdd.ExecuteNonQuery() | Out-Null
                                    $SQLAdd = $null
                                    }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    
                    }
                    Else {
                        Try {
                            $ErrorActionPreference = "Stop"
                            $ADObject = Get-ADComputer $Server -Properties Name, dnshostname, operatingsystem
                            $props = @{"FQDN"=$(($ADObject.dnshostname).ToUpper());"Model"="";"Make"="";"TotalMemory"="";"Zone"=$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".");"OS"=$($ADObject.operatingsystem);"Architecture"="";"SerialNumber"="";"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                            $MainDataObj = New-Object -TypeName PSCustomObject -Property $props
                            AppendtoCSV $MainDataObj "MainData-$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")"
                            }
                            Catch {
                                    $LDAPFilter = "(cn=$Server)"
                                    $Domain = New-Object System.DirectoryServices.DirectoryEntry
                                    $DirSearcher = New-Object System.DirectoryServices.DirectorySearcher
                                    $DirSearcher.SearchRoot = $Domain
                                    $DirSearcher.PageSize = 1000
                                    $DirSearcher.Filter = $LDAPFilter
                                    $DirSearcher.SearchScope = "Subtree"
                                    $proplist = "dnsHostName","operatingSystem"
                                    foreach ($prop in $proplist) { $DirSearcher.PropertiesToLoad.Add($prop) | Out-Null }
                                    $DirSearcher.FindAll() | Foreach-Object {$ADObject = $_.properties}

                                    $props = @{"FQDN"=$(($ADObject.dnshostname[0]).ToUpper());"Model"="";"Make"="";"TotalMemory"="";"Zone"=$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".");"OS"=$($ADObject.operatingsystem[0]);"Architecture"="";"SerialNumber"="";"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                                    $MainDataObj = New-Object -TypeName PSCustomObject -Property $props
                                    AppendtoCSV $MainDataObj "MainData-$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")"
                                    }
                            Finally {
                                $ErrorActionPreference = "Continue"
                                }
                        }
                Throw "Could not connect to $Server"
                }
        Try {
            $RRegService = Get-WmiObject -Class Win32_Service -ComputerName $Server | Where {$_.Name -eq "RemoteRegistry"}
                    If ($RRegService.StartMode -eq "Disabled") {
                        $RRegDisabled = $True
                        $RRegService.ChangeStartMode("Manual") | Out-Null
                        $RRegService = Get-WmiObject -Class Win32_Service -ComputerName $Server | Where {$_.Name -eq "RemoteRegistry"}
                        }
                    If ($RRegService.State -eq "Stopped") {
                        $RRegService.StartService() | Out-Null
                        $RRegService = $null
                        }
                }
                Catch {
                    Write-Output "Connecting to $Server services WMI object failed."
                    }
        Try {
            $CS = Get-wmiobject -class Win32_ComputerSystem -ComputerName $Server
            $FQDN = ("$($CS.Name).$($CS.Domain)").ToUpper()
            $Zone = $CS.Domain
            $Model = $CS.Model
            $Make = $CS.Manufacturer
            $TotalMemory = "$([Math]::Round($($CS.TotalPhysicalMemory / 1GB))) GB"
            $CSProps = @{"FQDN"=$FQDN;"Model"=$Model;"Make"=$Make;"TotalMemory"=$TotalMemory;"Zone"=$Zone}
            $CSObj = New-Object -TypeName PSCustomObject -Property $CSProps
            }
            Catch {
                If ($OuttoSQL -eq $True) {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $ADObject = Get-ADComputer $Server -Properties Name, dnshostname, operatingsystem
                        $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                        $SQLAdd.Connection = $UTILSQL
                        $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$(($ADObject.dnshostname).ToUpper())',OSName='$($ADObject.operatingsystem)',Zone='$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$(($ADObject.dnshostname).ToUpper())' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,OSName,Zone,Updated) VALUES('$(($ADObject.dnshostname).ToUpper())','$($ADObject.operatingsystem)','$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                        $SQLAdd.ExecuteNonQuery() | Out-Null
                        $SQLAdd = $null
                        }
                        Catch {
                            $LDAPFilter = "(cn=$Server)"
                                    $Domain = New-Object System.DirectoryServices.DirectoryEntry
                                    $DirSearcher = New-Object System.DirectoryServices.DirectorySearcher
                                    $DirSearcher.SearchRoot = $Domain
                                    $DirSearcher.PageSize = 1000
                                    $DirSearcher.Filter = $LDAPFilter
                                    $DirSearcher.SearchScope = "Subtree"
                                    $proplist = "dnsHostName","operatingSystem"
                                    foreach ($prop in $proplist) { $DirSearcher.PropertiesToLoad.Add($prop) }
                                    $DirSearcher.FindAll() | Foreach-Object {$ADObject = $_.properties}

                                    $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                    $SQLAdd.Connection = $UTILSQL
                                    $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$(($ADObject.dnshostname[0]).ToUpper())',OSName='$($ADObject.operatingsystem[0])',Zone='$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$(($ADObject.dnshostname[0]).ToUpper())' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,OSName,Zone,Updated) VALUES('$(($ADObject.dnshostname[0]).ToUpper())','$($ADObject.operatingsystem[0])','$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                                    $SQLAdd.ExecuteNonQuery() | Out-Null
                                    $SQLAdd = $null
                                    }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    
                    }
                    Else {
                        Try {
                            $ErrorActionPreference = "Stop"
                            $ADObject = Get-ADComputer $Server -Properties Name, dnshostname, operatingsystem
                            $props = @{"FQDN"=$(($ADObject.dnshostname).ToUpper());"Model"="";"Make"="";"TotalMemory"="";"Zone"=$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".");"OS"=$($ADObject.operatingsystem);"Architecture"="";"SerialNumber"="";"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                            $MainDataObj = New-Object -TypeName PSCustomObject -Property $props
                            AppendtoCSV $MainDataObj "MainData-$((($ADObject.dnshostname).Split(".") | Select -Skip 1) -Join ".")"
                            }
                            Catch {
                                    $LDAPFilter = "(cn=$Server)"
                                    $Domain = New-Object System.DirectoryServices.DirectoryEntry
                                    $DirSearcher = New-Object System.DirectoryServices.DirectorySearcher
                                    $DirSearcher.SearchRoot = $Domain
                                    $DirSearcher.PageSize = 1000
                                    $DirSearcher.Filter = $LDAPFilter
                                    $DirSearcher.SearchScope = "Subtree"
                                    $proplist = "dnsHostName","operatingSystem"
                                    foreach ($prop in $proplist) { $DirSearcher.PropertiesToLoad.Add($prop) }
                                   $DirSearcher.FindAll() | Foreach-Object {$ADObject = $_.properties}

                                    $props = @{"FQDN"=$(($ADObject.dnshostname[0]).ToUpper());"Model"="";"Make"="";"TotalMemory"="";"Zone"=$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".");"OS"=$($ADObject.operatingsystem[0]);"Architecture"="";"SerialNumber"="";"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                                    $MainDataObj = New-Object -TypeName PSCustomObject -Property $props
                                    AppendtoCSV $MainDataObj "MainData-$((($ADObject.dnshostname[0]).Split(".") | Select -Skip 1) -Join ".")"
                                    }
                            Finally {
                                $ErrorActionPreference = "Continue"
                                }
                        }
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                Throw "$_"
                }

        Try {
            $OS = Get-WmiObject -Class Win32_operatingsystem -ComputerName $Server -Property Name
            $OSName = ($OS.Name).Split('|')[0]
            $OSArch = If ($OSName -notlike "*2003*") {
                Write-Output (Get-WmiObject -Class Win32_operatingsystem -ComputerName $Server -Property OSArchitecture).OSArchitecture
                }
                Else {
                    Write-Output "32-bit"
                    }
            $OSProps = @{"OS"=$OSName;"Architecture"=$OSArch}
            $OSObj = New-Object -TypeName PSCustomObject -Property $OSProps
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
            $BIOS = Get-WmiObject -ComputerName $Server -Class Win32_BIOS
            $SerialNumber = $BIOS.SerialNumber
            $BIOSProps = @{"SerialNumber"=$SerialNumber}
            $BIOSObj = New-Object -TypeName PSCustomObject -Property $BIOSProps

            If ($OuttoSQL -eq $True) {
                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                $SQLAdd.Connection = $UTILSQL
                $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$FQDN',Make='$Make',Model='$Model',TotalMemory='$TotalMemory',SerialNumber='$SerialNumber',OSName='$OSName',OSArch='$OSArch',Zone='$Zone',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$FQDN' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,Model,Make,TotalMemory,SerialNumber,OSName,OSArch,Zone,Updated) VALUES('$FQDN','$Model','$Make','$TotalMemory','$SerialNumber','$OSName','$OSArch','$Zone','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                $SQLAdd.ExecuteNonQuery() | Out-Null
                $SQLAdd = $null
                }
                Else {
                    $props = @{"FQDN"=$FQDN;"Model"=$Model;"Make"=$Make;"TotalMemory"=$TotalMemory;"Zone"=$Zone;"OS"=$OSName;"Architecture"=$OSArch;"SerialNumber"=$SerialNumber;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                    $MainDataObj = New-Object -TypeName PSCustomObject -Property $props
                    AppendtoCSV $MainDataObj "MainData-$Zone"
                    }
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
             $CPUquery = Get-WmiObject -Class Win32_Processor -ComputerName $Server
             $CPUs = Foreach ($CPU in $CPUquery) {
                $CPUProps = @{'CPU Name' = $CPU.Name ; 'Cores' = $CPU.NumberofCores ; 'DeviceID'= $CPU.DeviceID; "FQDN"=$FQDN; "Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss") ;}
                New-Object -TypeName "PSObject" -Property $CPUprops
                }
            If ($OuttoSQL -eq $True) {
                Foreach ($CPU in $CPUquery) {
                    $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                    $SQLAdd.Connection = $UTILSQL
                    $SQLAdd.CommandText = @"
UPDATE CPUData SET FQDN='$FQDN',CPUName='$($CPU.Name)',NumCores='$($CPU.NumberofCores)',CPUID='$($CPU.DeviceID)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE CPUID='$($CPU.DeviceID)' AND FQDN='$FQDN' IF @@ROWCOUNT=0 INSERT INTO dbo.CPUData (FQDN,CPUName,NumCores,CPUID,Updated) VALUES('$FQDN','$($CPU.Name)','$($CPU.NumberofCores)','$($CPU.DeviceID)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                    $SQLAdd.ExecuteNonQuery() | Out-Null
                    $SQLAdd = $null
                    }
                }
                Else {
                    AppendtoCSV $CPUs "CPUData-$Zone"
                    }
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
            $Diskquery = Get-Wmiobject -Class Win32_LogicalDisk -ComputerName $Server | Where {$_.DriveType -eq 3}
            $Disks = Foreach ($Disk in $Diskquery) {
                $DiskProps = @{'DiskID'=$Disk.VolumeSerialNumber;'Drive Letter' = $Disk.DeviceID ; 'Drive Size' = $Disk.Size;'Drive Space Free'=$Disk.FreeSpace;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss");"FQDN"=$FQDN}
                New-Object "PSObject" -Property $DiskProps
                }
            If ($OuttoSQL -eq $True) {
                Foreach ($Disk in $Diskquery) {
                    $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                    $SQLAdd.Connection = $UTILSQL
                    $SQLAdd.CommandText = @"
UPDATE DiskData SET FQDN='$FQDN',DiskID='$($Disk.VolumeSerialNumber)',DriveLetter='$($Disk.DeviceID)',DriveSize='$($Disk.Size)',DriveFree='$($Disk.FreeSpace)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE DiskID='$($Disk.VolumeSerialNumber)' AND FQDN='$FQDN' IF @@ROWCOUNT=0 INSERT INTO dbo.DiskData (FQDN,DiskID,DriveLetter,DriveSize,DriveFree,Updated) VALUES('$FQDN','$($Disk.VolumeSerialNumber)','$($Disk.DeviceID)','$($Disk.Size)','$($Disk.FreeSpace)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                    $SQLAdd.ExecuteNonQuery() | Out-Null
                    $SQLAdd = $null
                    }
                }
                Else {
                    AppendtoCSV $Disks "DiskData-$Zone"
                    }
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$server\My","LocalMachine")
                $store.Open("ReadOnly")
                $Certquery = $store.Certificates | Select SubjectName,NotAfter,Thumbprint
                $Certs = Foreach ($Cert in $Certquery) {
                    $CertExpire = $null
                    If ($Cert.NotAfter.Year -gt "2079") {
                        $CertExpire = Get-Date -Date 06/06/2079
                        }
                        Else {
                            $CertExpire = $Cert.NotAfter
                            }
                    If (($store.Certificates | Select -First 1) -eq $null) {
                        Break
                        }
                    $Certprops = @{"Name"=$Cert.SubjectName.Name;"Expiration"=$CertExpire;"Thumbprint"=$Cert.Thumbprint;"FQDN"=$FQDN;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                    New-Object -TypeName PSCustomObject -Property $Certprops
                    If ($OuttoSQL -eq $True) {
                        $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                        $SQLAdd.Connection = $UTILSQL
                        $SQLAdd.CommandText = @"
UPDATE CertData SET FQDN='$FQDN',Thumbprint='$($Cert.Thumbprint)',Expiration='$($CertExpire)',Name='$($Cert.SubjectName.Name)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE Thumbprint='$($Cert.Thumbprint)' AND FQDN='$FQDN' IF @@ROWCOUNT=0 INSERT INTO dbo.CertData (FQDN,Thumbprint,Expiration,Name,Updated) VALUES('$FQDN','$($Cert.Thumbprint)','$($CertExpire)','$($Cert.SubjectName.Name)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                        $SQLAdd.ExecuteNonQuery() | Out-Null
                        $SQLAdd = $null
                    }
                    Else {
                        If ($Certs) {
                            AppendtoCSV $Certs "CertData-$Zone"
                            }
                        }
                    }
                }
                Catch {
                    $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                    }

        Try {
            $Networking = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Server | Where {$_.IPAddress -ne $null}
            $NetAdapters = Foreach ($NetworkAdapter in $Networking) {
                $props = @{"AdapterName"=$NetworkAdapter.ServiceName;"AdapterDescription"=$NetworkAdapter.Description;"MACAddress"=$NetworkAdapter.MACAddress;"IPAddress"=$(($NetworkAdapter | Where {$_.IPAddress -like "*.*"} | Select-Object -Expand IPAddress) -Join " ");"FQDN"=$FQDN;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                New-Object -TypeName PSCustomObject -Property $props
                }
            If ($OuttoSQL -eq $True) {
                Foreach ($NetworkAdapter in $Networking) {
                    $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                    $SQLAdd.Connection = $UTILSQL
                    $SQLAdd.CommandText = @"
UPDATE NetData SET FQDN='$FQDN',AdapterName='$($NetworkAdapter.ServiceName)',AdapterDescription='$($NetworkAdapter.Description)',MACAddress='$($NetworkAdapter.MACAddress)',IPAddress='$(($NetworkAdapter| Where {$_.IPAddress -like "*.*"} | Select-Object -Expand IPAddress) -Join " ")',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE MACAddress='$($NetworkAdapter.MACAddress)' IF @@ROWCOUNT=0 INSERT INTO dbo.NetData (FQDN,AdapterName,AdapterDescription,MACAddress,IPAddress,Updated) VALUES('$FQDN','$($NetworkAdapter.ServiceName)','$($NetworkAdapter.Description)','$($NetworkAdapter.MACAddress)','$(($NetworkAdapter| Where {$_.IPAddress -like "*.*"} | Select-Object -Expand IPAddress) -Join " ")','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                    $SQLAdd.ExecuteNonQuery() | Out-Null
                    $SQLAdd = $null
                    }
                }
                Else {                        
                    If ($NetAdapters) {
                        AppendtoCSV $NetAdapters "NetData-$Zone"
                        }
                    }
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
            Try {
                $NativeDNs = @()
                $NonNativeDNs = @()
                $NativeApps = @()
                $NonNativeApps = @()
                $registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Server)
                $softwarekey= $registry.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Uninstall")
                $Nativekeylist = $softwareKey.GetSubKeyNames()
                Foreach ($Nativekey in $nativekeylist) {
                    If (!($Nativekey -like "*KB*")) {
                        $DNValue = ($Softwarekey.OpenSubKey("$nativekey",$False)).GetValue("DisplayName")
                        If (!($DNValue -eq $null)) {
                            $AppVersion = $(($Softwarekey.OpenSubKey("$Nativekey",$False)).GetValue("DisplayVersion"))
                            $props = @{"AppName"=$DNValue;"AppVersion"=$AppVersion;"AppKeyPath"="$($FQDN)\HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($NativeKey)";"AppNative"="TRUE";"FQDN"=$FQDN;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                            $NativeApps += New-Object -TypeName PSCustomObject -Property $props
                            }
                        }
                    }
                If ($OuttoSQL -eq $True) {
                    Foreach ($App in $NativeApps) {
                        $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                        $SQLAdd.Connection = $UTILSQL
                        $SQLAdd.CommandText = @"
UPDATE AppData SET FQDN='$FQDN',AppName='$($App.AppName)',AppVersion='$($App.AppVersion)',AppKeyPath='$($App.AppKeyPath)',AppNative='$($App.AppNative)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE AppKeyPath='$($App.AppKeyPath)' IF @@ROWCOUNT=0 INSERT INTO dbo.AppData (FQDN,AppName,AppVersion,AppKeyPath,AppNative,Updated) VALUES('$FQDN','$($App.AppName)','$($App.AppVersion)','$($App.AppKeyPath)','$($App.AppNative)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                         $SQLAdd.ExecuteNonQuery() | Out-Null
                         $SQLAdd = $null
                         }
                    }
                    Else {
                        If ($NativeApps) {
                            AppendtoCSV $NativeApps "AppData-$Zone"
                            }
                        }
                $Softwarekey = $null
                If ($OSArch -eq "64-bit") {
                    $softwarekey= $registry.OpenSubKey("Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
                    $NonNativekeylist = $softwareKey.GetSubKeyNames()
                    Foreach ($NonNativekey in $NonNativekeylist) {
                        If (!($NonNativekey -like "*KB*")) {
                            $DNValue = ($Softwarekey.OpenSubKey("$NonNativekey",$False)).GetValue("DisplayName")
                            If (!($DNValue -eq $null)) {
                                $AppVersion = $(($Softwarekey.OpenSubKey("$NonNativekey",$False)).GetValue("DisplayVersion"))
                                $props = @{"AppName"=$DNValue;"AppVersion"=$AppVersion;"AppKeyPath"="$($FQDN)\HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$($NonNativeKey)";"AppNative"="FALSE";"FQDN"=$FQDN;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                                $NonNativeApps += New-Object -TypeName PSCustomObject -Property $props
                                }
                            }
                        }
                    If ($OuttoSQL -eq $True) {
                        Foreach ($App in $NonNativeApps) {
                            $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                            $SQLAdd.Connection = $UTILSQL
                            $SQLAdd.CommandText = @"
UPDATE AppData SET FQDN='$FQDN',AppName='$($App.AppName)',AppVersion='$($App.AppVersion)',AppKeyPath='$($App.AppKeyPath)',AppNative='$($App.AppNative)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE AppKeyPath='$($App.AppKeyPath)' IF @@ROWCOUNT=0 INSERT INTO dbo.AppData (FQDN,AppName,AppVersion,AppKeyPath,AppNative,Updated) VALUES('$FQDN','$($App.AppName)','$($App.AppVersion)','$($App.AppKeyPath)','$($App.AppNative)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                             $SQLAdd.ExecuteNonQuery() | Out-Null
                             $SQLAdd = $null
                             }
                        }
                        Else {
                            If ($NonNativeApps) {
                                AppendtoCSV $NonNativeApps "AppData-$Zone"
                                }
                            }
                    }
                    $Registry = $null
                }
                Catch {
                    $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                    }
            }
            Catch {
                $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                }

        Try {
            If ($OSName -like "*2003*") {
                # Do nothing, deprecated OS and no good way to retrieve full role names
                $InstalledRoles = $null
                }
                ElseIf ($OSName -like "*2008*") {
                    $InstalledRoles = Get-WmiObject -ComputerName $Server -class Win32_ServerFeature | Select Name
                    }
                Else {
                    Try {
                        $Serversession = New-PSSession -ComputerName $server
                        If (-not($Serversession)) {
                            Throw "Session not active"
                            }
                        $Installedroles = Get-WindowsFeature | Where {$_."InstallState" -eq "Installed"} | Select "DisplayName"
                        }
                        Catch {
                            $InstalledRoles = Get-WmiObject -ComputerName $Server -class Win32_ServerFeature | Select Name
                            }
                        }
                $RoleObj = Foreach ($Role in $InstalledRoles) {
                    $props = @{"Name"=$Role.Name;"FQDN"=$FQDN;"Updated"=$(Get-Date -format "yyyy-MM-dd hh:mm:ss")}
                    New-Object -TypeName PSCustomObject -Property $props
                    }
 
                 If ($OuttoSQL -eq $True) {
                    Foreach ($RoleName in $InstalledRoles) {
                        $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                        $SQLAdd.Connection = $UTILSQL
                        $SQLAdd.CommandText = @"
UPDATE RoleData SET FQDN='$FQDN',RoleName='$($RoleName.Name)',Updated='$(Get-Date -format "yyyy-MM-dd hh:mm:ss")' WHERE FQDN='$FQDN' AND RoleName='$($RoleName.Name)' IF @@ROWCOUNT=0 INSERT INTO dbo.RoleData (FQDN,RoleName,Updated) VALUES('$FQDN','$($RoleName.Name)','$(Get-Date -format "yyyy-MM-dd hh:mm:ss")')
"@ 
                         $SQLAdd.ExecuteNonQuery() | Out-Null
                         $SQLAdd = $null
                         }
                    }
                    Else {
                        If ($RoleObj) {
                            AppendtoCSV $RoleObj "RoleData-$Zone"
                            }
                        }
                }
                Catch {
                    $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
                    }                       
    
        }
        Catch {
            $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
            }
        Finally {
                    $ErrorActionPreference = "Continue"
                    $RRegService = Get-WmiObject -Class Win32_Service -ComputerName $Server | Where {$_.Name -eq "RemoteRegistry"}
                    If ($RRegService.StartMode -eq "Manual") {
                        $RRegService.StopService() | Out-Null
                        }
                    If ($RRegDisabled -eq $True) {
                        $RRegService.ChangeStartMode("Disabled") | Out-Null
                        }
                    $RRegService = $null
                    $ErrorActionPreference = "Stop"
                    }
    }

If ($OuttoSQL -eq $true) {
    $UTILSQL.Close()
    }

$Failures