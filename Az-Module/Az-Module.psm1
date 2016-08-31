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
	Dependencies ::	AzureRm PowerShell Module.
	Version 1.0  ::	20-Jun-2016  :: Release.
.LINK
	http://www.ps1code.com/single-post/2016/06/19/Azure-Automation-How-to-stopstart-Azure-VM-on-schedule
#>

	If ($_ -is [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]) {
		(Get-Culture).TextInfo.ToTitleCase((Get-AzureRmVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Status | `
		select -expand Statuses |? {$_.Code -match 'PowerState/'} | `
		select @{N='PowerState';E={$_.Code.Split('/')[1]}}).PowerState)
	}

} #EndFilter Get-AzVmPowerState

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
	Dependencies ::	AzureRm PowerShell Module.
	Version 1.0  ::	20-Jun-2016  :: Release.
.LINK
	http://www.ps1code.com/single-post/2016/06/19/Azure-Automation-How-to-stopstart-Azure-VM-on-schedule
#>

	Param ([string]$TagName)

	If ($_ -is [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]) {
		($_).Tags.$TagName
	}

} #EndFilter Get-AzVmTag

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
	http://www.ps1code.com/single-post/2016/06/29/Azure-VM-Tag-automation
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

} #EndFunction Add-AzVmTag

Function Get-AzOrphanedVhd {

<#
.SYNOPSIS
	Get Azure orphaned VHD files.
.DESCRIPTION
	This cmdlet finds orphaned* Azure VM disks.
	* - VHD files that are not registered to any existing VM.
.EXAMPLE
	PS C:\> Login-AzureRmAccount
	PS C:\> Select-AzureRmSubscription
	PS C:\> Get-AzOrphanedVhd
.EXAMPLE
	PS C:\> Get-AzOrphanedVhd |Format-Table -AutoSize
.EXAMPLE
	PS C:\> Get-AzOrphanedVhd |Export-Csv -NoTypeInformation '.\Vhd.csv'
.INPUTS
	No input.
.OUTPUTS
	[System.Management.Automation.PSCustomObject] PSObject collection.
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	AzureRm and Azure.Storage PowerShell Modules.
	Version 1.0  ::	14-Jul-2016  :: Release.
.LINK
	http://www.ps1code.com/single-post/2016/07/18/How-to-find-orphaned-VHD-files-in-the-Azure-IaaS-cloud
#>

	Begin {
		$WarningPreference = 'SilentlyContinue'
		$ErrorActionPreference = 'SilentlyContinue'
		$rgxUrl = '^http(:|s:)/{2}'
		$VmVhd = @()
	}

	Process {

		### Get registerd in VM VHD in all ResourceGroups ###
		Foreach ($AzRg in ($ResGroup = Get-AzureRmResourceGroup)) {
			Foreach ($AzVm in ($VM = Get-AzureRmVM -ResourceGroupName ($AzRg.ResourceGroupName))) {
				$VmVhd += ($AzVm.StorageProfile.OsDisk.Vhd.Uri) -replace ($rgxUrl,'')
				Foreach ($DataDisk in $AzVm.StorageProfile.DataDisks) {
					$VmVhd += ($DataDisk.Vhd.Uri) -replace ($rgxUrl,'')
				}
			}
		}
		### Get VHD located in all StorageAccouns ###
		Foreach ($Vhd in ($SaVhd = Get-AzureRmStorageAccount |Get-AzureStorageContainer |Get-AzureStorageBlob |? {$_.Name -match '\.vhd$'})) {
		
			$ModifiedLocal = $Vhd.LastModified.LocalDateTime
			$Now           = [datetime]::Now
			### If a change was made less than 24 hours ago, but it was yesterday return one day and not zero ###
			If (($Days = (New-TimeSpan -End $Now -Start $ModifiedLocal).Days) -eq 0) {
				If ($ModifiedLocal.Day-$Now.Day -eq 1 -or $ModifiedLocal.Day -lt $Now.Day) {$Days = 1}
			}

			$Properties = [ordered]@{
				VHD            = $Vhd.Name
				StorageAccount = $Vhd.Context.StorageAccountName
				SizeGB         = [Math]::Round($Vhd.Length/1GB,0)
				Modified       = $ModifiedLocal.ToString('dd/MM/yyyy HH:mm')
				LastWriteDays  = $Days
				FullPath       = ($Vhd.ICloudBlob.Uri) -replace ($rgxUrl,'')
				Snapshot       = $Vhd.ICloudBlob.IsSnapshot
			}
			$Object = New-Object PSObject -Property $Properties
			### Return if not in the list only ###
			If ($VmVhd -notcontains $Object.FullPath) {$Object}
		}

	} #End Process

	End {}

} #EndFunction Get-AzOrphanedVhd

Function Get-AzVmDisk {

<#
.SYNOPSIS
	Get Azure VM Virtual Disks.
.DESCRIPTION
	This cmdlet gets Azure VM Virtual Disks.
.PARAMETER VM
	Azure VM.
.PARAMETER DiskType
	Virtual Disk Type.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' -VMName 'azvm1' |Get-AzVmDisk
	Get all Virtual Disks for a given VM.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' |sort Name |Get-AzVmDisk |select * -exclude Path |ft -au
	Get all Virtual Disks for all VM in specific ResourceGroup.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' |Get-AzVmDisk -DiskType DataDisk
	Get only DataDisks for all VM in specific ResourceGroup.
.INPUTS
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine[]] Azure VM object(s), returned by 'Get-AzureRmVm' cmdlet.
.OUTPUTS
	[System.Management.Automation.PSCustomObject] PSObject collection.
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	AzureRM PowerShell Module.
	Version 1.0  ::	31-Aug-2016  :: Release.
.LINK
	http://ps1code.com
#>

[CmdletBinding()]

Param (

	[Parameter(Mandatory,Position=1,ValueFromPipeline)]
		[Alias("AzureVm")]
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine[]]$VM
	,
	[Parameter(Mandatory=$false,Position=2)]
		[ValidateSet("OSDisk","DataDisk","All")]
	[string]$DiskType = 'All'
)

Begin {

	$rgxUri = '^http(:|s:)/{2}(?<StorageAccount>.+?)\..+/(?<Container>.+)/(?<Vhd>.+)$'

} #EndBegin

Process {

	If ('OSDisk','All' -contains $DiskType) {
		$VmOsDisk   = $VM.StorageProfile.OsDisk
		$OsDiskUri  = $VmOsDisk.Vhd.Uri
		$OsDiskUriX = [regex]::Match($OsDiskUri, $rgxUri)
		
		$Properties = [ordered]@{
			VM             = $VM.Name
			VMSize         = $VM.HardwareProfile.VmSize
			DiskName       = $VmOsDisk.Name
			DiskType       = 'OSDisk'
			Lun            = -1
			StorageAccount = $OsDiskUriX.Groups['StorageAccount'].Value
			Container      = $OsDiskUriX.Groups['Container'].Value
			Vhd            = $OsDiskUriX.Groups['Vhd'].Value
			Path           = $OsDiskUri
			SizeGB         = 0
			Cache          = $VmOsDisk.Caching
			Created        = $VmOsDisk.CreateOption
		}
		$Object = New-Object PSObject -Property $Properties
		$Object
	}
	
	If ('DataDisk','All' -contains $DiskType) {
		$VmDataDisks = $VM.StorageProfile.DataDisks
		Foreach ($DataDisk in $VmDataDisks) {
			$DataDiskUri  = $DataDisk.Vhd.Uri
			$DataDiskUriX = [regex]::Match($DataDiskUri, $rgxUri)
			
			$Properties   = [ordered]@{
				VM             = $VM.Name
				VMSize         = $VM.HardwareProfile.VmSize
				DiskName       = $DataDisk.Name
				DiskType       = 'DataDisk'
				Lun            = $DataDisk.Lun
				StorageAccount = $DataDiskUriX.Groups['StorageAccount'].Value
				Container      = $DataDiskUriX.Groups['Container'].Value
				Vhd            = $DataDiskUriX.Groups['Vhd'].Value
				Path           = $DataDiskUri
				SizeGB         = $DataDisk.DiskSizeGB
				Cache          = $DataDisk.Caching
				Created        = $DataDisk.CreateOption
			}
			$Object = New-Object PSObject -Property $Properties
			$Object
		}
	}
} #EndProcess

} #EndFunction Get-AzVmDisk

Function New-AzVmDisk {

<#
.SYNOPSIS
	Add a new data disk to an Azure VM.
.DESCRIPTION
	This cmdlet creates and attaches a new data disk to an Azure Virtual Machine.
.PARAMETER VM
	Azure VM.
.PARAMETER StorageAccount
	From where to take a StorageAccount name.
.PARAMETER SizeGB
	Disk size in GiB.
.PARAMETER Caching
	Disk caching mode.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' -VMName 'azvm1' |New-AzVmDisk
	Add a new data disk with all default options.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' -VMName 'azvm1' |New-AzVmDisk -StorageAccount Prompt
	Give an option to pick a StorageAccount from a menu.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName 'YourResourceGroupName' -VMName 'azvm1' |New-AzVmDisk -SizeGB 10 -Caching SqlLog
	Add 10 GiB disk with caching mode recommended by Microsoft for SQL logs.
.INPUTS
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] Azure VM object, returned by 'Get-AzureRmVm' cmdlet.
.OUTPUTS
	[System.Management.Automation.PSCustomObject] PSObject collection.
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	AzureRM PowerShell Module.
	Version 1.0  ::	31-Aug-2016  :: Release.
.LINK
	http://ps1code.com
#>

[CmdletBinding()]

Param (

	[Parameter(Mandatory,Position=1,ValueFromPipeline)]
		[Alias("AzureVm")]
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
	,
	[Parameter(Mandatory=$false,Position=2)]
		[ValidateSet("OSDisk","FirstDataDisk","Prompt")]
		[Alias("Storage")]
	[string]$StorageAccount = 'OSDisk'
	,
	[Parameter(Mandatory=$false,Position=3)]
		[ValidateRange(10,1023)]
	[uint16]$SizeGB = 100
	,
	[Parameter(Mandatory=$false,Position=4)]
		[ValidateSet("None","ReadOnly","ReadWrite","SqlLog","SqlTempDB","SqlData")]
	[string]$Caching = 'None'
)

Begin {

	$ErrorActionPreference = 'SilentlyContinue'
	$WarningPreference     = 'SilentlyContinue'
	$DataDiskSuffix = '_datadisk'
	$rgxDataDiskIndex = $DataDiskSuffix + '(\d+)\.vhd$'
	Switch -regex ($Caching) {
		'^sql(t|d)' {$Cache = 'ReadOnly'; Break}
		'^sqll'     {$Cache = 'None'    ; Break}
		Default     {$Cache = $Caching}
	}
	
} #EndBegin

Process {

	$VmDisks = Get-AzVmDisk -VM $VM
	
	Write-Host "`n:: BEFORE ::" -ForegroundColor Yellow
	$VmDisks |select * -ExcludeProperty VM*,Path |Format-Table -AutoSize
	
	$ResourceGroup = $VM.ResourceGroupName
	
	$OsDisk    = $VmDisks |? {$_.DiskType -eq 'OSDisk'}
	$DataDisks = $VmDisks |? {$_.DiskType -eq 'DataDisk'} |
	select *,@{N='Index';E={(([regex]::Match($_.Vhd, $rgxDataDiskIndex).Groups[1].Value) -as [int])}} |sort Index
	
	### DataDisk Index&Lun ###
	If ($DataDisks) {
		$DataDiskIndex = ($DataDisks[-1].Index -as [int]) + 1
		If (!$DataDiskIndex) {$DataDiskIndex = 1}
		$DataDiskLun = ($DataDisks[-1].Lun -as [int]) + 1
	} Else {
		$DataDiskIndex = 1
		$DataDiskLun = 0
	}
	
	### DataDisk Name ###
	$DataDiskName = $VM.Name + $DataDiskSuffix + $DataDiskIndex
	
	### DataDisk Vhd Name ###
	$DataDiskVhd = $DataDiskName+'.vhd'
	
	Switch -exact ($StorageAccount) {
	
		'OSDisk'
		{
			$StorageAccountName = $OsDisk.StorageAccount
			$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
			Break
		}
		'FirstDataDisk'
		{
			If ($DataDisks) {
				$StorageAccountName = $DataDisks[0].StorageAccount
				$DataDiskUri = ($DataDisks[0].Path).Replace($DataDisks[0].Vhd, $DataDiskVhd)
			} Else {
				$StorageAccountName = $OsDisk.StorageAccount
				$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
			}
			Break
		}
		'Prompt'
		{
			$StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup |sort StorageAccountName
			
			If (!$StorageAccounts) {
				$StorageAccountName = $OsDisk.StorageAccount
				$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
			} Else {
				$StorageAccountPrompt = Write-Menu -Menu $StorageAccounts -Shift 1 -Prompt "Choice StorageAccount for your DataDisk" -Header "Available StorageAccounts in the [$($VM.ResourceGroupName)] ResourceGroup:" -PropertyToShow StorageAccountName
				$StorageAccountName = $StorageAccountPrompt.StorageAccountName
				$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd).Replace($OsDisk.StorageAccount, $StorageAccountName)
			}
		}
		
	} #EndSwitch
	
	$null = Add-AzureRmVMDataDisk -VM $VM -Name $DataDiskName -Lun $DataDiskLun -CreateOption empty -DiskSizeInGB $SizeGB -VhdUri $DataDiskUri -Caching $Cache
	
	Write-Progress -Activity "Adding Virtual DataDisk to VM [$($VM.Name)]" `
	-Status "Updating VM configuration ..." `
	-CurrentOperation "StorageAccount [$StorageAccountName] | DiskName [$DataDiskName] | LUN [$DataDiskLun] | Size [$SizeGB GiB] | Caching [$Cache]"
	
	$null = Update-AzureRmVM -VM $VM -ResourceGroupName $ResourceGroup -ErrorVariable ErrUpdateVm
	If ($ErrUpdateVm) {$ErrMsg = $ErrUpdateVm.Exception.Message; Write-Host $ErrMsg -ForegroundColor Yellow}
	
	Write-Host "`n:: AFTER ::" -ForegroundColor Yellow
	Get-AzureRmVm -ResourceGroupName $ResourceGroup -VMName $VM.Name |Get-AzVmDisk |select * -ExcludeProperty VM*,Path |Format-Table -AutoSize
	
} #EndProcess

End {
	Write-Progress -Activity "Completed" -Completed
}

} #EndFunction New-AzVmDisk

Export-ModuleMember -Alias '*' -Function '*'
