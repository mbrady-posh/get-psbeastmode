$CSV = Import-CSV C:\users\mbrady2\downloads\DNS.csv

Invoke-Command -ComputerName dns.domain.com -UseSSL -ScriptBlock {
    $IPList = $using:CSV | Foreach-Object { $_.IPAddress }
    $OldRecords = Get-WmiObject MicrosoftDNS_AType -Namespace Root\MicrosoftDNS | Where {$IPList -contains $_.RecordData} 
    $OldRecords | Select OwnerName,RecordData
    #$OldRecords | Foreach-Object {$_.Delete()}
    Foreach ($Item in $using:CSV) {
        $Hostname = ($Item.Name).Split(".")[0]
        $Zone = $Item.Name -replace "$($Hostname).",""
        $RevIPAddress = ($Item.IPAddress).Split(".") | Write-Output "$($_[3]).$($_[2]).$($_[1]).$($_[0])"
        #Write-Output "Creating record: Zone: $Zone Host: $Hostname IP: $($Item.IPAddress)"
        #([wmiclass]"\\dns.domain.com\root\MicrosoftDNS:MicrosoftDNS_AType").CreateInstanceFromPropertyData("dns.domain.com",$($Zone),$($Hostname),1,"900",$($Item.IPAddress))
        ([wmiclass]"\\dns.domain.com\root\MicrosoftDNS:MicrosoftDNS_AType").CreateInstanceFromPropertyData("dns.domain.com",$($Zone),$($Hostname),1,"900",$($RevIPAddress))
        $Hostname = $null; $Zone = $null
        }
    }