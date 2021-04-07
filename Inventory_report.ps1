#Created by https://github.com/VladimirKosyuk

#Foreach of domain PCs, which OS is Windows 10, collects array to csv. Array: Computername, OS, Architecture, CPU, RAM, Disk, User, Powershell_version, Execution_policy, Last_update_date, Soft_list. Examples shown via comments

# Build date: 07.04.2021

$Output = #'\\MySRV\report'

$Date = Get-Date -Format "MM.dd.yyyy"
$Unic = Get-WmiObject -Class Win32_ComputerSystem |Select-Object -ExpandProperty "Domain"
$list = Get-ADComputer -Filter * -properties *|
            Where-Object {$_.enabled -eq $true} |
                Where-Object {($_.OperatingSystem -like "*Windows 10*")} | Select-Object -ExpandProperty name

foreach ($pc in $list) {
    $Report = Invoke-Command -ComputerName $pc -ErrorAction SilentlyContinue -ScriptBlock {
            $IsInstalled = @(
            (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | ?{($_.DisplayName -notlike "*Update for*") -and ($_.DisplayName -notlike "*Service Pack*")}).DisplayName
            (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |?{($_.DisplayName -notlike "*Update for*") -and ($_.DisplayName -notlike "*Service Pack*")}).DisplayName
            )
                New-Object PSObject -Property @{
                Computername = $env:COMPUTERNAME
                OS = (Get-WmiObject -class Win32_OperatingSystem).Version
                Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
                CPU = (Get-WmiObject -Class Win32_Processor).Name
                RAM = Get-WMIObject -class Win32_PhysicalMemory | Select-Object Manufacturer, @{label='TotalSize_GB';expression={$_.Capacity/1gb -as [int]}} 
                Disk = Get-PhysicalDisk |Select-Object SerialNumber, @{label='TotalSize_GB';expression={$_.Size/1gb -as [int]}} 
                User = (Get-WMIObject -class Win32_ComputerSystem).username
                Powershell_version = ($PSVersionTable.PSVersion).Major
                Execution_policy = get-executionpolicy
                Last_update_date =  (gwmi win32_quickfixengineering |sort installedon -desc |  Select-Object  -First 1).InstalledOn
                Soft_list = $IsInstalled 
                } | select Computername, OS, Architecture, CPU, RAM, Disk, User, Powershell_version, Execution_policy, Last_update_date, Soft_list
    } -asjob
    Wait-Job $Report -Timeout 300
        if ($Report.State -eq 'Completed') {
        $Report |select State, Location, PSBeginTime, PSEndTime| Out-File $Output\$Unic"_"$Date"_"inventory_success.log -Append
        } 
            else {
          $Report |select State, Location, PSBeginTime, PSEndTime|  Out-File $Output\$Unic"_"$Date"_"inventory_failed.log -Append
          Stop-Job -Id $Report.Id
          } 
    Receive-Job $Report 4>&1| Select-Object -Property * -ExcludeProperty PSComputerName,RunspaceID, PSShowComputerName |Export-Csv -Append -Delimiter ';' -Path $Output\$Unic"_"$Date"_"inventory.csv -Encoding UTF8 -NoTypeInformation
}

Remove-Variable -Name * -Force -ErrorAction SilentlyContinue