Function Get-SNMPTraps($ComputerName="localhost", $CommunityString="B00m3r!") {

$results = @()
$SessionOption = New-CimSessionOption -Protocol Dcom

    ForEach($Computer in $ComputerName) {

        if (!(Test-Connection -count 1 $Computer -ErrorAction SilentlyContinue)) {

            Write-Host "$Computer is not available" -ForegroundColor Red
            continue

        }
    
    try {

        $session = New-CimSession -ComputerName $Computer -SessionOption $SessionOption -ErrorAction Stop

        }

    catch {

        Write-Host "There was an unknown error connecting to WMI on $computer, skipping this one" -ForegroundColor Red
        Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue
        continue

        }


    Write-Host "Processing $Computer..." -ForegroundColor Green
   
    if ((Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMP"}) -or (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMPTRAP"})) {
        
       $Hostname = (Get-CimInstance -CimSession $session win32_computersystem -Property name).name
       $SNMPServiceStatus = (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMP"}).state
       $SNMPTRAPServiceStatus = (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMPTRAP"}).state

    }

    else {

        $SNMPServiceStatus = "not installed"
        $SNMPTRAPServiceStatus = "not installed"

    }

    Remove-CimSession -CimSession $session

        try {

            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Hostname)
            $regKey= $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\$CommunityString")

        }

    catch {

        Write-Host "There was an unknown error connecting to the registry on $computer, skipping this one" -ForegroundColor Red
        Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue
        continue

        }


    if ($regKey -eq $null){
    
    $SNMPCommunityString = "not valid"
    
    }
    
    else{
    
    $SNMPCommunityString = $CommunityString
    $SNMPTrapDestination = $regkey.getvalue($regkey.getvaluenames()[0])
    } 

    $Parameters = @{

    ComputerName = $Computer
    SNMPSvcStatus = $SNMPServiceStatus
    SNMPTrapSvcStatus = $SNMPTRAPServiceStatus
    SNMPTrapDestination = $SNMPTrapDestination
    SNMPTrapCommunityString = $SNMPCommunityString
    
    }

    $results += New-Object -TypeName psobject -Property $Parameters

    Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue

    }

    return $results

}