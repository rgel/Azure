<#
.SYNOPSIS
	Start/Stop Azure VM in parallel on schedule based on two VM Tags (PowerOn/PowerOff).
.DESCRIPTION
	This Azure Automation PowerShell Workflow type Runbook Start/Stop Azure VM in parallel on schedule based on two VM Tags (PowerOn/PowerOff).
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	Azure PowerShell modules.
	Version 1.0  ::	19-Jun-2016 :: Release.
.LINK
	http://www.ps1code.com/#!Azure-Automation-How-to-stopstart-Azure-VM-on-schedule/c1tye/576660770cf2426d7619470c
#>

Workflow Apply-AzVmPowerStatePolicyWf {

Param (
	[Parameter(Mandatory=$false,Position=1)]
	[string]$AzureCredentialAsset = 'Default Automation Credential'
	,
	[Parameter(Mandatory=$false,Position=2)]
	[string]$AzureSubscription = 'Visual Studio Enterprise'
	,
	[Parameter(Mandatory,Position=3)]
	[string]$AzureResourceGroup
	,
	#[System.TimeZoneInfo]::GetSystemTimeZones() |ft -au
	[Parameter(Mandatory=$false,Position=4)]
	[string]$AzureVmTimeZone = 'Israel Standard Time'
	,
	[Parameter(Mandatory=$false,Position=5)]
	[switch]$WhatIf
)

$ErrorActionPreference = 'SilentlyContinue'
$azCredential = Get-AutomationPSCredential -Name $AzureCredentialAsset
$null = Login-AzureRmAccount -Credential $azCredential
$null = Set-AzureRmContext -SubscriptionName $AzureSubscription
$AzVms = Get-AzureRmVm -ResourceGroupName $AzureResourceGroup |select Name,Tags,@{N='PowerState';E={(Get-AzureRmVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Status |select -expand Statuses |? {$_.Code -match 'PowerState/'} |select @{N='PowerState';E={$_.Code.Split('/')[1]}}).PowerState}} |sort Name

Foreach -Parallel($AzVm in $AzVms) {

	### Running VM ###
	If ($AzVm.PowerState -eq 'running') {
		$azTime = [datetime]::Now
		$TimeShort = $azTime.ToString('HH:mm')
		$TimeVm = [System.TimeZoneInfo]::ConvertTimeFromUtc($TimeShort, [System.TimeZoneInfo]::FindSystemTimeZoneById($AzureVmTimeZone))
		
		### 00:00---On+++Off---00:00 ###
		If ([datetime]$AzVm.Tags.PowerOn -lt [datetime]$AzVm.Tags.PowerOff) {
			If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOff -or $TimeVm -lt [datetime]$AzVm.Tags.PowerOn) {
				If ($WhatIf) {$Status = 'Simulation'}
				Else {
					$Result = Stop-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup -Force
					$Status = ($Result.StatusCode)
				}
				$Execution = 'Stopped'
			} Else {$Execution = 'NotRequired'}
		
		### 00:00+++Off---On+++00:00 ###
		} Else {
			If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOff -and $TimeVm -lt [datetime]$AzVm.Tags.PowerOn) {
				If ($WhatIf) {$Status = 'Simulation'}
				Else {
					$Result = Stop-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup -Force
					$Status = ($Result.StatusCode)
				}
				$Execution = 'Stopped'
			} Else {$Execution = 'NotRequired'}
		}
		
	### Not running VM (stopped/deallocated/suspended etc) ###
	} Else {
		$azTime = [datetime]::Now
		$TimeShort = $azTime.ToString('HH:mm')
		$TimeVm = [System.TimeZoneInfo]::ConvertTimeFromUtc($TimeShort, [System.TimeZoneInfo]::FindSystemTimeZoneById($AzureVmTimeZone))
		
		### 00:00---On+++Off---00:00 ###
		If ([datetime]$AzVm.Tags.PowerOn -lt [datetime]$AzVm.Tags.PowerOff) {
			If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOn -and $TimeVm -lt [datetime]$AzVm.Tags.PowerOff) {
				If ($WhatIf) {$Status = 'Simulation'}
				Else {
					$Result = Start-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup
					$Status = ($Result.StatusCode)
				}
				$Execution = 'Started'
			} Else {$Execution = 'NotRequired'}
		
		### 00:00+++Off---On+++00:00 ###
		} Else {
			If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOn -or $TimeVm -lt [datetime]$AzVm.Tags.PowerOff) {
				If ($WhatIf) {$Status = 'Simulation'}
				Else {
					$Result = Start-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup
					$Status = ($Result.StatusCode)
				}
				$Execution = 'Stopped'
			} Else {$Execution = 'NotRequired'}
		}
	}
	
	$Prop = [ordered]@{
		AzureVM       = $AzVm.Name
		ResourceGroup = $AzureResourceGroup
		PowerState    = (Get-Culture).TextInfo.ToTitleCase($AzVm.PowerState)
		PowerOn       = $AzVm.Tags.PowerOn
		PowerOff      = $AzVm.Tags.PowerOff
		StateChange   = $Execution
		StatusCode    = $Status
		TimeStamp     = $TimeVm
	}
	$Obj = New-Object PSObject -Property $Prop
	Write-Output -InputObject $Obj
		
} #End Foreach
} #End Workflow Apply-AzVmPowerStatePolicyWf
