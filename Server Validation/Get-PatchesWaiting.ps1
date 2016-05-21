$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition
$SMTPserver = Get-Content "$($script:scriptpath)\smtpserver.txt"
$Hostname = $(Get-wmiobject win32_computersystem) | Foreach-Object {$("$($_.name).$($_.domain)").ToUpper()}

Do {
    $i = 0
    Try {
        $ErrorActionPreference = "Stop"
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $UpdateResults = $UpdateSearcher.Search(" IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'")
        If ($UpdateResults.Updates.Count -eq 0) {
                    $UpdateCount = 0
                    }
                    Else {
                        $UpdatestoInstall = New-Object -ComObject Microsoft.Update.Updatecoll
                        Foreach ($Update in $UpdateResults.Updates) {
                            $UpdatestoInstall.Add($Update) | Out-Null
                            $UpdateCount = $UpdatestoInstall.Count
                            }
                        }
            $UpdateSuccess = $True
            }
            Catch {
                $i++
                If ($i -gt 4) {
                    Exit 1
                    }
                Start-Sleep 20
                }
            Finally {
                $ErrorActionPreference = "Continue"
                }
        }
        Until ( ($UpdateSuccess -eq $True) -or ( $i -gt 4) )

$PatchCountHTML = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml">
<head>
'@
$PatchCountHTML = "$($PatchCountHTML)<title>$($Hostname)</title></head><body><h2>Patches Awaiting Install</h2>"
If ($UpdatestoInstall.Count -gt 0) {
    Foreach ($Update in $UpdatestoInstall) {
        $PatchCountHTML = "$($PatchCountHTML)<p>$($Update.Title)</p>"
        }
    }
    Else {
        $PatchCountHTML = "$($PatchCountHTML)<p>No further updates are available at this time.</p>"
        }
$PatchCountHTML = "$($PatchCountHTML)</body></html>"
$OutFile = "$($env:TEMP)\PW\$($Hostname).html"
New-Item -ItemType File -Path $OutFile -Force | Out-Null
$PatchCountHTML | Out-File $OutFile -Force

        $i = 0
        $MailSuccess = $False
        Do {
            Try {
                $ErrorActionPreference = "Stop"
                $i++
                Send-MailMessage -To "doclibrary@sharepoint" -From "$($env:COMPUTERNAME)@domain.com" -Attachments $OutFile -Subject $($UpdateCount) -SmtpServer $SMTPserver
                $MailSuccess = $True
                }
                Catch {
                    Start-Sleep 20
                    }
                Finally {
                    $ErrorActionPreference = "Continue"
                    }
            }
            Until ( $MailSuccess -eq $True -or $i -gt 4 )