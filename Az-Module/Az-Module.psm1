Filter Get-AzVmPowerState {

<#
.SYNOPSIS
	Get AzureRm VM PowerState.
.DESCRIPTION
	This filter gets AzureRm VM PowerState.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $MyAzureResourceGroup |select Name,@{N='PowerState';E={$_ |Get-AzVmPowerState}} |ft -au
.INPUTS
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] Azure VM object, returned by Get-AzureRmVm cmdlet.
.OUTPUTS
	[System.String] AzureRm VM Power State.
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	Azure PS Modules.
	Version 1.0  ::	20-Jun-2016  :: Release.
.LINK
	https://goo.gl/vAxH2a
#>

	If ($_ -is [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]) {
		(Get-Culture).TextInfo.ToTitleCase((Get-AzureRmVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Status | `
		select -expand Statuses |? {$_.Code -match 'PowerState/'} | `
		select @{N='PowerState';E={$_.Code.Split('/')[1]}}).PowerState)
	}

} #End Filter Get-AzVmPowerState

Filter Get-AzVmTag {

<#
.SYNOPSIS
	Get AzureRm VM Tag value.
.DESCRIPTION
	This filter gets AzureRm VM Tag value.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $MyAzureResourceGroup |select Name,@{N='Notes';E={$_ |Get-AzVmTag -TagName 'Notes'}} |ft -au
	Get tag 'Notes'.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $MyAzureResourceGroup |select Name,@{N='PowerOn';E={$_ |Get-AzVmTag -TagName 'PowerOn'}},@{N='PowerOff';E={$_ |Get-AzVmTag -TagName 'PowerOff'}} |ft -au
	Get two tags 'PowerOn' and 'PowerOff'.
.INPUTS
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] Azure VM object, returned by Get-AzureRmVm cmdlet.
.OUTPUTS
	[System.String] AzureRm VM Tag value (may be blank if not assigned).
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	Azure PS Modules.
	Version 1.0  ::	20-Jun-2016  :: Release.
.LINK
	https://goo.gl/vAxH2a
#>

	Param ([string]$TagName)

	If ($_ -is [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]) {
		($_).Tags.$TagName
	}

} #End Filter Get-AzVmTag
