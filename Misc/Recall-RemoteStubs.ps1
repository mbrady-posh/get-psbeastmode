Param(
    [Parameter(Mandatory=$True)][string]$DFSPath
    )

Try {
    $SharePath = Invoke-Command -ComputerName "fileserver" -UseSSL -ArgumentList $DFSPath -ScriptBlock { Param( $DFSPath)
        (((dfsutil link $DFSPath | Select-String "Target=") -Split " ")[0] -Split "`"")[1]
        }

    $FileServer = "$(($SharePath -Split "\\")[2]).domain"
    $SharePathArray = $SharePath -Split "\\"
    $ShareRemainderPath = $SharePathArray[4..$($SharePathArray.Count+1)] -Join "\"

    $FilePath = Invoke-Command -ComputerName $FileServer -UseSSL -ArgumentList $SharePath,$ShareRemainderPath -ScriptBlock { Param($SharePath,$ShareRemainderPath)
        "$((net share | Select-String $(($SharePath -Split "\\")[3])) -Split " " | Select-String ":")\$($ShareRemainderPath)"
        }

        Invoke-Command -ComputerName $FileServer -UseSSL -ArgumentList $FilePath -ScriptBlock { Param($FilePath)
            Foreach ($File in $(Get-ChildItem $FilePath -Recurse).FullName) {
                $output = fsutil.exe usn readdata $File
               If (((($Output -split " : ")[20].Trim()) -eq "0x1600") -or ((($Output -split " : ")[20].Trim()) -eq "0x1200") -or ((($Output -split " : ")[20].Trim()) -eq "0x1400") -or ((($Output -split " : ")[20].Trim()) -eq "0x600")) {
                    Get-ItemProperty $File | Select *
                    }
                }
            }
    }
    Catch {
        $error[0] | Add-Content "$($Env:USERPROFILE)\desktop\Recallstubserror.log"
        }
