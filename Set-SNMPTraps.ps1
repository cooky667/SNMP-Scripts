Function Set-SNMPTraps($ComputerName="localhost", $CommunityString, $SNMPTrapDestination, $RestartService=$False, $AutoStart=$True) {

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
            Remove-Variable SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue
            continue

        }


        Write-Host "Processing $Computer..." -ForegroundColor Green
   
        $Hostname = (Get-CimInstance -CimSession $session win32_computersystem -Property name).name


        

        try {

            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Hostname)
            $regkey = $reg.CreateSubkey("SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\$CommunityString")
            $regkey.SetValue("1", $SNMPTrapDestination,"String")
            $regkey.Close()

        }

        catch {

            Write-Host "There was an error when setting the reg key on $computer, skipping this one" -ForegroundColor Red
            Remove-Variable SNMPCommunityString, SNMPTRAPServiceStatus, SNMPServiceStatus, Hostname, reg, regkey -ErrorAction SilentlyContinue
            continue

        }

        if ($RestartService) {

        
            Get-CimInstance -CimSession $session win32_service | where-object {$_.name -eq "SNMPTRAP"} | Invoke-CimMethod -MethodName StopService

            while ((Get-CimInstance -CimSession $session win32_service | where-object {$_.name -eq "SNMPTRAP"}).state -ne "stopped") {

                Start-Sleep -Seconds 1

            }

            Get-CimInstance -CimSession $session win32_service | where-object {$_.name -eq "SNMPTRAP"} | Invoke-CimMethod -MethodName StartService    

        }

        if ($AutoStart) {

            Get-CimInstance -CimSession $session win32_service | where-object {$_.name -eq "SNMPTRAP"} | Invoke-CimMethod -MethodName ChangeStartMode -Arguments @{startmode='automatic'}

        }

        Remove-CimSession -CimSession $session
    }

  
}