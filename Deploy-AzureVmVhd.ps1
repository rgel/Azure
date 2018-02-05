
#requires -Version 3.0 -Module Az-Module, AzureRm

<#
.SYNOPSIS
	Deploy Azure VM from VHD.
.DESCRIPTION
	This script deployes Azure VM from JSON template using existing OSDisk VHD blob.
	As intermediate stage, a JSON parameters file is created.
.EXAMPLE
	PS C:\scripts> .\Deploy-AzureVmVhd.ps1 -Envi Test -VMName azvm1 -OSDiskVhd https://azteststg001lrs.blob.core.windows.net/vhds/aztestvm1_osdisk.vhd
.EXAMPLE
	PS C:\scripts> .\Deploy-AzureVmVhd.ps1 Prod azvm2 https://azprodstg001lrs.blob.core.windows.net/vhds/azprodvm2_osdisk.vhd
.NOTES
	Author      :: Roman Gelman @rgelman75
	Version 1.0 :: 31-Jan-2018 :: [Release]
.LINK
	https://ps1code.com/2018/02/05/deploy-azure-vm-vhd-az-module
#>

[CmdletBinding(ConfirmImpact = 'High')]
Param (
	[Parameter(Mandatory, Position = 0)]
	[ValidateSet('Test', 'Prod', 'Dmz', 'Dev')]
	[string]$Envi
	 ,
	[Parameter(Mandatory, Position = 1)]
	[string]$VMName
	 ,
	[Parameter(Mandatory, Position = 2)]
	[uri]$OSDiskVhd
	 ,
	[Parameter(Mandatory = $false)]
	[ValidateSet('Windows', 'Linux')]
	[string]$VMGuest = 'Windows'
	 ,
	[Parameter(Mandatory = $false)]
	[string]$VMProject = '_Proj_'
	 ,
	[Parameter(Mandatory = $false)]
	[string]$VMNotes = '_Notes_'
)

Begin
{
	### Common settings ###
	$JsonPath = 'C:\AzureDeploy'
	$TemplateJson = 'C:\AzureDeploy\Vm_Vhd_OSDisk.json'
	$defaultVmSize = 'Standard_D2_v3'
}
Process
{
	### Select Subscription ###
	Az-Module\Select-AzSubscription -Title | Out-Null
	
	### Select target ResourceGroup for deployment ###
	$RgName = Az-Module\Select-AzResourceGroup
	
	### Select VM Size ###
	$SelectedVMSize = Write-Menu -Menu (Get-AzureRmVMSize -Location (Get-AzureRmResourceGroup -Name $RgName).Location) `
								 -Header 'Available VM Sizes' -Prompt 'Select VM Size, [Exit] for default' -Shift 1 -AddExit
	$VMSize = if ($SelectedVMSize -eq 'exit') { $defaultVmSize } else { $SelectedVMSize.Name; $SelectedVMSize | Out-Host }
	
	### Select VNET ###
	$VNET = Az-Module\Select-AzObject VNET
	
	### Select Subnet ###
	$Subnet = Write-Menu -Menu ($VNET | Az-Module\Get-AzSubnet) -Header 'Available Subnets' -Prompt 'Select Subnet' -Shift 1 -PropertyToShow 'Subnet'
	
	### Get free IP, assuming the Subnet is Class C network ###
	$LastBusyIP = ([ipaddress]$Subnet.BusyIP[-1])
	$LastOctat = $LastBusyIP.GetAddressBytes()[-1]
	if ($LastOctat -le 253) { $FreeIP = $Subnet.BusyIP[-1] -replace "$($LastOctat)$", [string]($LastOctat + 1) }
	else { Throw "No free IP in the subnet [$($Subnet.Subnet)]" }
	
	### New VM settings for the *.json parameters file ###
	$ParamsHash = @{
		'EnvironmentTag' = $Envi;
		'vmName' = $VMName;
		'vmSize' = $VMSize;
		'vmTag' = $VMProject;
		'vmNotes' = $VMNotes;
		'virtualNetworkName' = $VNET.Name;
		'subnetName' = $Subnet.Subnet;
		'vmnicStaticIP' = $FreeIP;
		'osType' = $VMGuest;
		'osDiskVhdUri' = $OSDiskVhd.OriginalString;
	}
	
	### Create and view the parameters json file ###
	$ParamsJson = "$JsonPath\$($ParamsHash['vmName'])"
	Az-Module\New-AzParamsJson $ParamsJson -Params $ParamsHash | Get-Content
	
	### Deploy VM from Template/Parameters JSON files ###
	if ($PSCmdlet.ShouldProcess("ResourceGroup [$RgName]", "Deploy Azure VM [$VMName] from VHD [$($OSDiskVhd.OriginalString)]"))
	{
		New-AzureRmResourceGroupDeployment -Name "azdeploy_$(Get-Date -Format 'yyyy-MM-d_HH-mm')" `
										   -ResourceGroupName $RgName `
										   -TemplateFile $TemplateJson `
										   -TemplateParameterFile $ParamsJson
	}
}
End { }
