### Script created April 2017 by Richard Cooke ###
### Purpose is to query local or remote computers for SNMP trap parameters ###


Function Get-SNMPTraps($ComputerName="localhost", $CommunityString="public") { ### Declare the function here ###

$results = @() ### Create variable for use later ###
$SessionOption = New-CimSessionOption -Protocol Dcom ### Create variable for use later ###

    ForEach($Computer in $ComputerName) { ### Loop to cycle through multiple computers if neccesary ###

        if (!(Test-Connection -count 1 $Computer -ErrorAction SilentlyContinue)) { ### Check if the target is alive ###

            Write-Host "$Computer is not available" -ForegroundColor Red
            continue

        }
    
    try {

        $session = New-CimSession -ComputerName $Computer -SessionOption $SessionOption -ErrorAction Stop ### Create the CIM session for the WMI query ###

        }

    catch {

        Write-Host "There was an unknown error connecting to WMI on $computer, skipping this one" -ForegroundColor Red ### Friendly(ish error message ###
        Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue ### Tidy up ###
        continue

        }


    Write-Host "Processing $Computer..." -ForegroundColor Green ### Show the user we are still working ###
   
    if ((Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMP"}) -or (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMPTRAP"})) { ### Only get data if SNMP is installed ###
        
       $Hostname = (Get-CimInstance -CimSession $session win32_computersystem -Property name).name
       $SNMPServiceStatus = (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMP"}).state
       $SNMPTRAPServiceStatus = (Get-CimInstance -CimSession $session win32_service | Where-Object {$_.Name -eq "SNMPTRAP"}).state

    }

    else {
    
        $SNMPServiceStatus = "not installed"
        $SNMPTRAPServiceStatus = "not installed"

    }

    Remove-CimSession -CimSession $session ### Close the CIM Session

        try {

            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Hostname) ### Query the registry ###
            $regKey= $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\$CommunityString")

        }

    catch {

        Write-Host "There was an unknown error connecting to the registry on $computer, skipping this one" -ForegroundColor Red ### Friendly(ish) error message ###
        Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue ### Tidy up ###
        continue

        }


    ### Gather the results together ###

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

    ### Create a new object for each computer and splat the results into the object ###

    $results += New-Object -TypeName psobject -Property $Parameters

    ### Tidying up ###

    Remove-Variable SNMPTrapDestination, SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue

    }

    return $results

}
