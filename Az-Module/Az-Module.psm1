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

Function Add-AzVmTag {

<#
.SYNOPSIS
	Add Resource Tags for Azure VMs.
.DESCRIPTION
	This cmdlet adds/sets Resource Tag/Tags for Azure VMs.
.PARAMETER VM
	Azure Virtual Machines.
.PARAMETER Tag
	VM Tag name.
.PARAMETER Value
	VM Tag value.
.PARAMETER Force
	Overwrite tag if exists.
.PARAMETER TagPowerOn
	VM 'PowerOn' tag's value.
.PARAMETER TagPowerOff
	VM 'PowerOff' tag's value.
.EXAMPLE
	PS C:\> $MyAzureResourceGroup = 'Production'
	PS C:\> Get-AzureRmVM -ResourceGroupName $MyAzureResourceGroup |sort Name |Add-AzVmTag |ft -au
	Set default 'PowerOn' and 'PowerOff' tag values to all VM in a Resource Group.
.EXAMPLE
	PS C:\> Get-AzureRmVM -Name 'azvm1' -ResourceGroupName $MyAzureResourceGroup |Add-AzVmTag -TagPowerOn '08:00' -TagPowerOff '21:00'
	Set custom 'PowerOn' and 'PowerOff' tag values to a single VM.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $MyAzureResourceGroup |? {$_.Name -like 'azvm*'} |Add-AzVmTag -Tag Environment -Value Prod -Force
	Set custom tag to filtered out VMs, overwrite the tag if exists.
.INPUTS
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine[]] AzureRm VM objects, returned by Get-AzureRmVM cmdlet.
.OUTPUTS
	[System.Management.Automation.PSCustomObject] PSObject collection.
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	AzureRm PowerShell Module.
	Version 1.0  ::	27-Jun-2016  :: Release.
.LINK
	https://goo.gl/vAxH2a
#>

[CmdletBinding(DefaultParameterSetName='POWER')]

Param (

	[Parameter(Mandatory,Position=1,ValueFromPipeline)]
		[Alias("AzureVm")]
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine[]]$VM
	,
	[Parameter(Mandatory=$false,Position=2,ParameterSetName='POWER')]
		[ValidateNotNullorEmpty()]
	[datetime]$TagPowerOn = '06:00'
	,
	[Parameter(Mandatory=$false,Position=3,ParameterSetName='POWER')]
		[ValidateNotNullorEmpty()]
	[datetime]$TagPowerOff = '18:00'
	,
	[Parameter(Mandatory,Position=2,ParameterSetName='CUSTOM')]
		[Alias("TagName")]
		[ValidateSet("PowerOn","PowerOff","Environment","Project","Notes")]
	[string]$Tag
	,
	[Parameter(Mandatory,Position=3,ParameterSetName='CUSTOM')]
		[Alias("TagValue")]
	[string]$Value
	,
	[Parameter(Mandatory=$false,Position=4,ParameterSetName='CUSTOM')]
		[Alias("Overwrite")]
	[switch]$Force
)

Begin {

	$ErrorActionPreference = 'Stop'
	
	If ($PSCmdlet.ParameterSetName -eq 'POWER') {
		$TimeFormat   = 'HH:mm'
		$PowerOnTime  = $TagPowerOn.ToString($TimeFormat)
		$PowerOffTime = $TagPowerOff.ToString($TimeFormat)
	}
	
} #End Begin

Process {

	### Power Tags ###
	If ($PSCmdlet.ParameterSetName -eq 'POWER') {
			
		Foreach ($AzVm in $VM) {
		
			 Try
				{
					If ($AzVm.Tags.Keys -contains 'poweron')  {$null = $AzVm.Tags.Remove('PowerOn')}
					If ($AzVm.Tags.Keys -contains 'poweroff') {$null = $AzVm.Tags.Remove('PowerOff')}
					
					$null = $AzVm.Tags.Add('PowerOn',$PowerOnTime)
					$null = $AzVm.Tags.Add('PowerOff',$PowerOffTime)
				
					$JobPower = Update-AzureRmVM -VM $AzVm -ResourceGroupName $AzVm.ResourceGroupName
					$Properties = [ordered]@{
						AzureVm       = $AzVm.Name
						ResourceGroup = $AzVm.ResourceGroupName
						PowerOn       = $PowerOnTime
						PowerOff      = $PowerOffTime
						StatusCode    = $JobPower.StatusCode
					}
				}
		   Catch
				{
					$Properties = [ordered]@{
						AzureVm       = $AzVm.Name
						ResourceGroup = $AzVm.ResourceGroupName
						PowerOn       = $PowerOnTime
						PowerOff      = $PowerOffTime
						StatusCode    = 'Error'
					}
				}
		 Finally
				{
					$Object = New-Object PSObject -Property $Properties
					$Object
				}
		} #End Foreach
	### Custom Tag ###	
	} Else {
		
		Foreach ($AzVm in $VM) {
		
			 Try
				{
					If ($AzVm.Tags.Keys -contains $Tag) {
						If ($Force) {$null = $AzVm.Tags.Remove($Tag)}
						Else {$Status = 'TagExists'}
					}
					If ($Status -ne 'TagExists') {
						$AzVm.Tags.Add($Tag,$Value)
						$JobCustom = Update-AzureRmVM -VM $AzVm -ResourceGroupName $AzVm.ResourceGroupName
						$Status = $JobCustom.StatusCode
					}
					$Properties = [ordered]@{
						AzureVm       = $AzVm.Name
						ResourceGroup = $AzVm.ResourceGroupName
						Tag           = $Tag
						Value         = $Value
						StatusCode    = $Status
					}
				}
		   Catch
				{
					$Properties = [ordered]@{
						AzureVm       = $AzVm.Name
						ResourceGroup = $AzVm.ResourceGroupName
						Tag           = $Tag
						Value         = $Value
						StatusCode    = 'Error'
					}
				}
		 Finally
				{
					$Object = New-Object PSObject -Property $Properties
					$Object
				}
		} #End Foreach
	}
	
} #End Process

} #End Function Add-AzVmTag
