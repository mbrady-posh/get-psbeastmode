$OutputDir = "C:\users\mbrady2\downloads\inventory"

Try {
    Try {
	    $UTILSQL = New-Object System.Data.SqlClient.SqlConnection
	    $UTILSQL.ConnectionString = ""
	    $UTILSQL.Open()
	    }
	    Catch {
		    Throw "Could not create connection to SQL server. Aborting."
		    }
    Foreach ($File in (Get-ChildItem -Path "$Outputdir\AppData*.csv")) {
        $AppData = Import-CSV $File.FullName
        Foreach ($App in $AppData) {
                            $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                            $SQLAdd.Connection = $UTILSQL
                            $SQLAdd.CommandText = @"
 UPDATE AppData SET FQDN='$($App.FQDN)',AppName='$($App.AppName)',AppVersion='$($App.AppVersion)',AppKeyPath='$($App.AppKeyPath)',AppNative='$($App.AppNative)',Updated='$($App.Updated)' WHERE AppKeyPath='$($App.AppKeyPath)' IF @@ROWCOUNT=0 INSERT INTO dbo.AppData (FQDN,AppName,AppVersion,AppKeyPath,AppNative,Updated) VALUES('$($App.FQDN)','$($App.AppName)','$($App.AppVersion)','$($App.AppKeyPath)','$($App.AppNative)','$($App.Updated)')
"@ 
                             $SQLAdd.ExecuteNonQuery() | Out-Null
                             $SQLAdd = $null
                }
            $AppData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\CertData*.csv")) {
            $CertData = Import-CSV $File.FullName
            Foreach ($Cert in $CertData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE CertData SET FQDN='$($Cert.FQDN)',Thumbprint='$($Cert.Thumbprint)',Expiration='$($Cert.Expiration)',Name='$($Cert.Name)',Updated='$($Cert.Updated)' WHERE Thumbprint='$($Cert.Thumbprint)' AND FQDN='$($Cert.FQDN)' IF @@ROWCOUNT=0 INSERT INTO dbo.CertData (FQDN,Thumbprint,Expiration,Name,Updated) VALUES('$($Cert.FQDN)','$($Cert.Thumbprint)','$($Cert.Expiration)','$($Cert.Name)','$($Cert.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $CertData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\CPUData*.csv")) {
            $CPUData = Import-CSV $File.FullName
            Foreach ($CPU in $CPUData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE CPUData SET FQDN='$($CPU.FQDN)',CPUName='$($CPU.Name)',NumCores='$($CPU.Cores)',CPUID='$($CPU.DeviceID)',Updated='$($CPU.Updated)' WHERE CPUID='$($CPU.DeviceID)' AND FQDN='$($CPU.FQDN)' IF @@ROWCOUNT=0 INSERT INTO dbo.CPUData (FQDN,CPUName,NumCores,CPUID,Updated) VALUES('$($CPU.FQDN)','$($CPU.Name)','$($CPU.Cores)','$($CPU.DeviceID)','$($CPU.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $CPUData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\DiskData*.csv")) {
            $DiskData = Import-CSV $File.FullName
            Foreach ($Disk in $DiskData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE DiskData SET FQDN='$($Disk.FQDN)',DiskID='$($Disk.DiskID)',DriveLetter='$($Disk."Drive Letter")',DriveSize='$($Disk."Drive Size")',DriveFree='$($Disk."Drive Space Free")',Updated='$($Disk.Updated)' WHERE DiskID='$($Disk.DiskID)' AND FQDN='$($Disk.FQDN)' IF @@ROWCOUNT=0 INSERT INTO dbo.DiskData (FQDN,DiskID,DriveLetter,DriveSize,DriveFree,Updated) VALUES('$($Disk.FQDN)','$($Disk.DiskID)','$($Disk."Drive Letter")','$($Disk."Drive Size")','$($Disk."Drive Space Free")','$($Disk.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $DiskData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\MainData*.csv")) {
            $MainData = Import-CSV $File.FullName
            Foreach ($Main in $MainData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE MainData SET FQDN='$($Main.FQDN)',Make='$($Main.Make)',Model='$($Main.Model)',TotalMemory='$($Main.TotalMemory)',SerialNumber='$($Main.SerialNumber)',OSName='$($Main.OS)',OSArch='$($Main.Architecture)',Zone='$($Main.Zone)',Updated='$($Main.Updated)' WHERE FQDN='$($Main.FQDN)' IF @@ROWCOUNT=0 INSERT INTO dbo.MainData (FQDN,Model,Make,TotalMemory,SerialNumber,OSName,OSArch,Zone,Updated) VALUES('$($Main.FQDN)','$($Main.Model)','$($Main.Make)','$($Main.TotalMemory)','$($Main.SerialNumber)','$($Main.OS)','$($Main.Architecture)','$($Main.Zone)','$($Main.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $MainData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\NetData*.csv")) {
            $NetData = Import-CSV $File.FullName
            Foreach ($Net in $NetData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE NetData SET FQDN='$($Net.FQDN)',AdapterName='$($Net.AdapterName)',AdapterDescription='$($Net.AdapterDescription)',MACAddress='$($Net.MACAddress)',IPAddress='$($Net.IPAddress)',Updated='$($Net.Updated)' WHERE MACAddress='$($Net.MACAddress)' IF @@ROWCOUNT=0 INSERT INTO dbo.NetData (FQDN,AdapterName,AdapterDescription,MACAddress,IPAddress,Updated) VALUES('$($Net.FQDN)','$($Net.AdapterName)','$($Net.AdapterDescription)','$($Net.MACAddress)','$($Net.IPAddress)','$($Net.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $NetData = $null
            }

        Foreach ($File in (Get-ChildItem -Path "$Outputdir\RoleData*.csv")) {
            $RoleData = Import-CSV $File.FullName
            Foreach ($Role in $RoleData) {
                                $SQLAdd = New-Object System.Data.SqlClient.SqlCommand
                                $SQLAdd.Connection = $UTILSQL
                                $SQLAdd.CommandText = @"
UPDATE RoleData SET FQDN='$($Role.FQDN)',RoleName='$($Role.Name)',Updated='$($Role.Updated)' WHERE FQDN='$($Role.FQDN)' AND RoleName='$($Role.Name)' IF @@ROWCOUNT=0 INSERT INTO dbo.RoleData (FQDN,RoleName,Updated) VALUES('$($Role.FQDN)','$($Role.Name)','$($Role.Updated)')
"@ 
                                 $SQLAdd.ExecuteNonQuery() | Out-Null
                                 $SQLAdd = $null
                    }
                $NetData = $null
            }
        }
        Catch {
            Write-Error $_
            }
         Finally {
            $UTILSQL.Close()
            }
