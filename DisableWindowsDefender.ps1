<#
Author: Arris Huijgen - @bitsadmin
Website: https://github.com/bitsadmin/lofl
License: BSD 3-Clause

Partially automates steps described at:
- Mandiant's Commando VM GitHub repository
  https://github.com/mandiant/commando-vm#pre-install-procedures
- Ruud Mens' (@LazyAdmin) blog
  https://lazyadmin.nl/win-11/turn-off-windows-defender-windows-11-permanently/
#>

# Relaunch current script elevated if currently not running elevated
$script = $MyInvocation.MyCommand.Definition
$ps = Join-Path $PSHome 'powershell.exe'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
	Start-Process $ps -Verb RunAs -ArgumentList "Set-ExecutionPolicy -Scope Process Bypass -Force; `"& '$script'`"" 
	exit
}

# Register/unregister current script as startup script
function Set-AutostartScript
{
	param (
		[string]$ScriptPath,
		[switch]$Register=$true
	)

	$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
	$property = 'DisableWindowsDefenderScript'

	# Register
	if($Register)
	{
		$ps = Join-Path $PSHome 'powershell.exe'
		Set-ItemProperty -Path $path -Name $property -Value "$ps -Command `"Set-ExecutionPolicy -Scope Process Bypass -Force; & '$script'`""
	}
	# Unregister
	else
	{
		Remove-ItemProperty -Path $path -Name $property -ea 0
	}
}

# Enable/disable User Account Control (UAC) functionality
function Set-UAC
{
	param (
		[switch]$Enabled=$true
	)

	if($Enabled)
		{ $v=4 }
	else
		{ $v=0 }

	Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value $v
}


# Banner
Write-Host	-ForegroundColor Red `
			-BackgroundColor White `
			-Object @'
                                       
 -=[ Windows Defender Disable v1.1 ]=- 
                                       
'@
@'

Fully disables Windows Defender in three reboots
by @bitsadmin - https://github.com/bitsadmin/lofl

'@

$osversion = [System.Environment]::OSVersion.Version
if($osversion.Build -LT 18362)
{
	Write-Warning 'Script currently works for Windows build 1909 and later'
	Read-Host -Prompt 'Press Enter to exit...'
	Exit
}

$policies = @(
	#[PSCustomObject]@{Title='Tamper Protection'; Path='HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'; Property='TamperProtection'; Value=4; RebootRequired=$true; },
	[PSCustomObject]@{Title='Real-Time Protection'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Property='DisableRealtimeMonitoring'; DesiredValue=1; RebootRequired=$true; },
	[PSCustomObject]@{Title='Microsoft Defender Antivirus'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Property='DisableAntiSpyware'; DesiredValue=1; },
	[PSCustomObject]@{Title='Cloud-Delivered Protection'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Property='SpyNetReporting'; DesiredValue=0; },
	[PSCustomObject]@{Title='Automatic Sample Submission'; Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Property='SubmitSamplesConsent'; DesiredValue=0; },
	[PSCustomObject]@{Title='Systray Security Health icon'; Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Property='SecurityHealth'; DesiredValue=$null; OriginalValue='%windir%\system32\SecurityHealthSystray.exe' }
)


# Re-enable Windows Defender in case it is currently disabled
$defenderpolicy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -ea 0
$disabled = $defenderpolicy.DisableAntiSpyware
if($disabled -EQ 1)
{
	Write-Host  -ForegroundColor DarkBlue `
				-BackgroundColor Green `
				-Object @'
Windows Defender is currently disabled. Press Enter to re-enable it.

'@
	Read-Host -Prompt 'Press Enter to continue...'

	foreach($policy in $policies)
	{
		if(-not $policy.OriginalValue)
		{			
			Remove-ItemProperty -Path $policy.Path -Name $policy.Property -Force

			if($?)
			{
				"[+] Removed policy for $($policy.Title)"
			}
			else
			{
				"[-] Error removing policy for $($policy.Title)"
			}
		}
		# Systray Security Health icon
		else
		{
			New-ItemProperty -Path $policy.Path -Name $policy.Property -Value $policy.OriginalValue | Out-Null
			Start-Process -FilePath "$env:windir\system32\SecurityHealthSystray.exe"
			"[+] Re-enabled $($policy.Title)"
		}
	}

	# Re-enabling Windows Defender scheduled tasks
	Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' | Enable-ScheduledTask | % { "[+] Re-enabled task `"$($_.TaskName)`"" }
	'[+] Re-enabled Windows Defender scheduled tasks'
	
	# Re-enable services/drivers
	$services = [ordered]@{Sense = 3; WdBoot = 0; WdFilter = 0; WdNisDrv = 3; WdNisSvc = 3; WinDefend = 2}
	$services.Keys | Foreach-Object {
		$targetvalue = $services[$_]
		Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\$_ -Name Start -Value $targetvalue -ea 0

		# Workaround for error caused by above Set-ItemProperty: 'Attempted to perform an unauthorized operation.'
		# Value is properly set though, so hiding the error and validating the Start value with the code below
		$currentvalue = Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Services\$_ -Name Start
		if($currentvalue -EQ $targetvalue)
		{
			"[+] Re-enabled service/driver `"$_`""
		}
		else
		{
			"[-] Failed renabling service/driver `"$_`""
		}
	}
	'[+] Re-enabled Windows Defender services/drivers'
	
	# Finish
	'[+] Finished! Reboot the machine to have Windows Defender fully functional again.'
	'    Optionally, Tamper Protection can also be enabled again.'
	Read-Host -Prompt 'Press Enter to continue...'
	Exit
}

# Tamper protection
$path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
$property = 'TamperProtection'
$tamper = (Get-ItemPropertyValue -Path $path -Name $property -ea 0)
if($tamper -NE 4)
{
	# Provide instructions and launch the Windows Defender Settings UI
	Write-Host  -ForegroundColor DarkBlue `
				-BackgroundColor Green `
				-Object @'

The first step in killing Windows Defender is to disable Tamper Protection.

After pressing Enter the Windows Defender settings UI will be opened. Perform the following steps:
1. Virus & threat protection
2. Virus & threat protection settings
3. Disable: Tamper Protection

The computer will automatically reboot twice as soon as Tamper Protection has been turned off.

'@

	Read-Host -Prompt 'Press Enter to continue...'
	Start-Process 'windowsdefender:'
	
	# Wait for tamper protection to be disabled
	$policyed = $false
	while(-not $policyed)
	{
		Start-Sleep -Milliseconds 500
		$policyed = (Get-ItemPropertyValue -Path $path -Name $property -ea 0) -EQ 4
	}
	'[+] Disabled Tamper Protection'
	
	# Automatic startup
	'[+] Registering script as automatic startup'
	Set-AutostartScript -Register:$true -ScriptPath $script
	
	# Disable UAC
	'[+] Disabling UAC to allow unattended reboots'
	Set-UAC -Enabled:$false

	# Reboot
	#Read-Host -Prompt 'Debug'
	shutdown /r /t 5 /c 'Tamper Protection has been disabled successfully. Rebooting...'
	Exit
}
else
{
	'[+] Tamper Protection is disabled'
}

# Apply registry updates
foreach($policy in $policies)
{
	$path = Get-ItemProperty -Path $policy.Path -ea 0
	
	# Create key if it does not exist
	if(-not $?)
	{
		New-Item $policy.Path | Out-Null
	}
	
	# Obtain current value
	$value = $null
	if($path)
	{
		$value = $path.$($policy.Property)
	}

	if($value -NE $policy.DesiredValue)
	{
		# Set value
		if($policy.DesiredValue -NE $null)
		{
			New-Item -Path $policy.Path -ea 0 | Out-Null
			Set-ItemProperty -Path $policy.Path -Name $policy.Property -Value $policy.DesiredValue
		}
		# Remove property
		else
		{
			Remove-ItemProperty -Path $policy.Path -Name $policy.Property
		}

		if($?)
		{
			"[+] Disabled $($policy.Title)"
		}
		else
		{
			"[+] Something went wrong disabling $($policy.Title)"
			'[+] Unregistering script from automatic startup'
			Set-AutostartScript -Register:$false
			Read-Host -Prompt 'Press Enter to exit...'
			Exit
		}

		if($policy.RebootRequired)
		{
			$message = "$($policy.Title) has been disabled successfully. Rebooting..."
			#Read-Host -Prompt 'Debug'
			shutdown /r /t 5 /c $message
			Exit
		}
	}
	else
	{
		"[+] $($policy.Title) is disabled"
	}
}

# Killing Systray Security Health icon
Stop-Process -Name SecurityHealthSystray -Force -ea 0
'[+] Killed Systray Security Health icon'

# Disabling Windows Defender scheduled tasks
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' | Stop-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' | Disable-ScheduledTask | % { "[+] Disabled task `"$($_.TaskName)`"" }
'[+] Disabled Windows Defender scheduled tasks'

# Cleanup
'[+] Cleanup'
'    [+] Re-enabling UAC'
Set-UAC -Enabled:$true
'    [+] Unregistering script from automatic startup'
Set-AutostartScript -Register:$false

# Final step
'[+] The final step is to boot into Safe Mode and disable the services/drivers related to Windows Defender'
	Write-Host  -ForegroundColor DarkBlue `
				-BackgroundColor Green `
				-Object @'
1. Reboot the machine in Safe Mode: Start -> Power -> Shift+Click on Reboot
   -> Troubleshoot -> Advanced options -> Startup Settings -> Restart
   -> Choose: '4) Enable Safe Mode'
2. Once booted in Safe Mode, launch PowerShell and execute the following oneliner:
   'Sense','WdBoot','WdFilter','WdNisDrv','WdNisSvc','WinDefend' | % { Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\$_ -Name Start -Value 4 -Verbose }
3. Reboot to Normal Mode and Windows Defender will be disabled!

'@
Read-Host -Prompt 'Press Enter to continue...'