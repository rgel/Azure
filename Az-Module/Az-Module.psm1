Class AzModule
{
	
} #EndClass AzModule

Class AzDisk : AzModule
{
	[ValidateNotNullOrEmpty()][string]$ResourceGroup
	[ValidateNotNullOrEmpty()][string]$VM
	[ValidateNotNullOrEmpty()][string]$VMSize
	[ValidateNotNullOrEmpty()][string]$DiskName
	[ValidateNotNullOrEmpty()][string]$DiskType
	[ValidateNotNullOrEmpty()][int]$Index
	[ValidateNotNullOrEmpty()][int]$Lun
	[ValidateNotNullOrEmpty()][string]$StorageAccount
	[ValidateNotNullOrEmpty()][string]$Container
	[ValidateNotNullOrEmpty()][string]$Vhd
	[ValidateNotNullOrEmpty()][string]$Path
	[ValidateNotNullOrEmpty()][int]$SizeGB
	[ValidateNotNullOrEmpty()][string]$Cache
	[ValidateNotNullOrEmpty()][string]$Created
	
	[string] ToString () { return $this.Path }
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] GetParentVM ()
	{
		return Get-AzureRmVM -ResourceGroupName $this.ResourceGroup -Name $this.VM -WarningAction SilentlyContinue
	}	
} #EndClass AzDisk

Class AzBlob : AzModule
{
	[ValidateNotNullOrEmpty()][string]$ResourceGroup
	[ValidateNotNullOrEmpty()][string]$ParentStorageAccount
	[ValidateNotNullOrEmpty()][string]$AccessKey
	[ValidateNotNullOrEmpty()][string]$Location
	[ValidateNotNullOrEmpty()][string]$BlobName
	[ValidateNotNullOrEmpty()][uri]$BlobUri
	[ValidateNotNullOrEmpty()][double]$SizeGB
	[ValidateNotNullOrEmpty()][DateTimeOffset]$Modified
	[ValidateNotNullOrEmpty()][string]$LeaseStatus
	[ValidateNotNullOrEmpty()][string]$LeaseState
	[ValidateNotNullOrEmpty()][string]$ContainerName
	[ValidateNotNullOrEmpty()][uri]$ContainerUri
	
	[string] ToString () { return $this.BlobUri.OriginalString }
	[string] GetParent () { return $this.ContainerUri.OriginalString }
	[Microsoft.Azure.Commands.Management.Storage.Models.PSStorageAccount] GetStorageAccount ()
	{
		return Get-AzureRmStorageAccount -ResourceGroupName $this.ResourceGroup -Name $this.ParentStorageAccount -WarningAction SilentlyContinue
	}
} #EndClass AzBlob

Class AzBlobContainer : AzModule
{
	[ValidateNotNullOrEmpty()][string]$ResourceGroup
	[ValidateNotNullOrEmpty()][string]$ParentStorageAccount
	[ValidateNotNullOrEmpty()][string]$AccessKey
	[ValidateNotNullOrEmpty()][string]$Location
	[ValidateNotNullOrEmpty()][string]$ContainerName
	[ValidateNotNullOrEmpty()][uri]$ContainerUri
	[ValidateNotNullOrEmpty()][string]$PublicAccess
	[ValidateNotNullOrEmpty()][DateTimeOffset]$Modified
	[ValidateNotNullOrEmpty()][string]$LeaseStatus
	[ValidateNotNullOrEmpty()][string]$LeaseState
	
	[string] ToString () { return $this.ContainerUri.OriginalString }
	[string] GetParent () { return $this.ParentStorageAccount }
	[Microsoft.Azure.Commands.Management.Storage.Models.PSStorageAccount] GetStorageAccount ()
	{
		return Get-AzureRmStorageAccount -ResourceGroupName $this.ResourceGroup -Name $this.ParentStorageAccount -WarningAction SilentlyContinue
	}
} #EndClass AzBlobContainer

Class AzVmSize: AzModule
{
	[ValidateNotNullOrEmpty()][string]$Location
	[ValidateNotNullOrEmpty()][string]$VMSize
	[ValidateNotNullOrEmpty()][int]$Cores
	[ValidateNotNullOrEmpty()][decimal]$MemoryGiB
	[ValidateNotNullOrEmpty()][decimal]$OSDiskGiB
	[ValidateNotNullOrEmpty()][int]$DataDisks
	[ValidateNotNullOrEmpty()][string]$Type
	[ValidateNotNullOrEmpty()][string]$Family
	[ValidateNotNullOrEmpty()][string]$Series
	[ValidateNotNullOrEmpty()][string]$Number
	[string]$SubSeries
	[string]$Version
	
	[string] ToString () { return $this.VMSize }
} #EndClass AzVmSize

Function Get-AzVmPowerState
{
	
<#
.SYNOPSIS
	Get Azure VM Power State.
.DESCRIPTION
	This function retrieves Azure VM(s) Power State.
.PARAMETER VM
	Azure VM object(s), returned by Get-AzureRmVm cmdlet.
.EXAMPLE
	PS C:\> Get-AzureRmVM | Get-AzVmPowerState
.EXAMPLE
	PS C:\> Get-AzureRmVm -wa SilentlyContinue | Get-AzVmPowerState -State Running
.EXAMPLE
	PS C:\> Get-AzureRmVm -wa SilentlyContinue -ResourceGroupName (Select-AzResourceGroup) | Get-AzVmPowerState NotRunning
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject VM | Get-AzVmPowerState
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 20-Jun-2016 :: [Release] :: Publicly available :: Filter
	Version 1.1 :: 10-Jan-2017 :: [Change]  :: Warnings suppressed
	Version 2.0 :: 27-Jun-2017 :: [Release] :: Publicly available :: Rewritten from Filter to Function
.LINK
	https://ps1code.com/category/powershell/azure/az-module/
#>
	
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureVm")]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList]$VM
		 ,
		[Parameter(Mandatory = $false, Position = 0)]
		[ValidateSet("Running", "NotRunning")]
		[string]$State
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$ErrorActionPreference = 'Stop'
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
	}
	Process
	{
		Try
		{
			$AzVmPowerState = (Get-AzureRmVM -Name $_.Name `
					-ResourceGroupName $_.ResourceGroupName -Status |
					select -expand Statuses | ? { $_.Code -match 'PowerState/' } |
					select @{ N = 'PowerState'; E = { $_.Code.Split('/')[1] } }).PowerState
			
			$return = [pscustomobject] @{
				VM = $VM.Name
				PowerState = (Get-Culture).TextInfo.ToTitleCase($AzVmPowerState)
			}
			
			switch -exact ($State)
			{
				'Running' { if ($return.PowerState -eq 'running') { $return; Break } }
				'NotRunning' { if ($return.PowerState -ne 'running') { $return; Break } }
				Default { $return }
			}
		}
		Catch
		{
			Write-Verbose "$FunctionName - [$($VM.Name)] error"
		}
	}
	End
	{
		
	}

} #EndFunction Get-AzVmPowerState

Function Get-AzVmTag
{
	
<#
.SYNOPSIS
	Get Azure VM Tag(s).
.DESCRIPTION
	This function retrieves Azure VM Resource Tag(s).
.PARAMETER VM
	Azure VM object(s), returned by Get-AzureRmVm cmdlet.
.PARAMETER Tag
	Specifies Tag name(s). Tag names are case sensitive!
.EXAMPLE
	PS C:\> Get-AzureRmVm -wa SilentlyContinue -ResourceGroupName (Select-AzResourceGroup) | Get-AzVmTag -Tags 'PowerOn', 'PowerOff'
.EXAMPLE
	PS C:\> Get-AzureRmVm -wa SilentlyContinue | Get-AzVmTag -Tag 'Project', 'Notes'
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject VM | Get-AzVmTag -Tags 'PowerOn', 'PowerOff'
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 20-Jun-2016 :: [Release] :: Publicly available :: Filter
	Version 2.0 :: 27-Jun-2017 :: [Release] :: Publicly available :: Rewritten from Filter to Function
.LINK
	https://ps1code.com/2017/06/29/azure-vm-tags
#>
	
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureVm")]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList]$VM
		 ,
		[Parameter(Mandatory, Position = 0)]
		[Alias("Tags")]
		[string[]]$Tag
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$ErrorActionPreference = 'Stop'
		$VmProperty = 'VM'
		if ($Tag -contains $VmProperty) {Write-Verbose "The [$VmProperty] Tag will replace VM name from output"}
	}
	Process
	{
		$VMObject = [pscustomobject] @{
			$VmProperty = $VM.Name
		}
		[hashtable]$htTags = @{}
		
		foreach ($TagName in $Tag)
		{
			$TagValue = if ($VM.Tags.Keys.Contains($TagName)) { $VM.Tags.$TagName } else { $null }
			$htTags.Add($TagName, $TagValue)
			$VMObject | Add-Member -NotePropertyMembers $htTags -Force
		}
		$TagsSorted = @($VmProperty) + @(($VMObject | Get-Member -MemberType NoteProperty |
				select Name |? {$_.Name -ne $VmProperty} | sort Name).Name)
		$VMObject | select $TagsSorted
	}
	End
	{
		
	}
	
} #EndFunction Get-AzVmTag

Function Add-AzVmTag
{
	
<#
.SYNOPSIS
	Add Resource Tag to Azure VM.
.DESCRIPTION
	This function adds/sets Resource Tag(s) to Azure VM(s).
.PARAMETER VM
	Specifies Azure VM object(s), returned by Get-AzureRmVM cmdlet.
.PARAMETER Tag
	Specifies VM Tag name.
.PARAMETER Value
	Specifies VM Tag value.
.PARAMETER Force
	If specified, overwrites a Tag if it exists.
.PARAMETER TagPowerOn
	Specifies VM 'PowerOn' tag's value.
.PARAMETER TagPowerOff
	Specifies VM 'PowerOff' tag's value.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |sort Name |Add-AzVmTag |ft -au
	Set default 'PowerOn' and 'PowerOff' tag values to all VM in a Resource Group.
.EXAMPLE
	PS C:\> Get-AzureRmVM -Name 'azvm1' -ResourceGroupName $AzResourceGroup |Add-AzVmTag -TagPowerOn '08:00' -TagPowerOff '21:00'
	Set custom 'PowerOn' and 'PowerOff' tag values to a single VM.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |? {$_.Name -like 'azvm*'} |Add-AzVmTag -Tag Environment -Value Prod -Force
	Set custom tag to filtered out VMs, overwrite the tag if exists.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |Add-AzVmTag -TagName 'PowerOff' -TagValue '22:22:22' -Force
	Set 'PowerOff' tag only.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject VM |Add-AzVmTag -TagName 'PowerOn' -TagValue '11:11:11' -Force
	Set 'PowerOn' tag only with no change of 'PowerOff' tag.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 27-Jun-2016 :: [Release] :: Publicly available
	Version 1.1 :: 27-Jun-2017 :: [Change] :: Code optimization, aliases added, new examples
	Version 1.2 :: 28-Jun-2017 :: [Bugfix] :: Tag/Value Parameters edited
.LINK
	https://ps1code.com/2017/06/29/azure-vm-tags
#>
	
	[CmdletBinding(DefaultParameterSetName = 'POWER', ConfirmImpact = 'High', SupportsShouldProcess)]
	[Alias("Set-AzVmTag", "New-AzVmTag")]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureVm")]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
		 ,
		[Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'POWER')]
		[Alias("PowerOn")]
		[datetime]$TagPowerOn = '11:11:11'
		 ,
		[Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'POWER')]
		[Alias("PowerOff")]
		[datetime]$TagPowerOff = '22:22:22'
		 ,
		[Parameter(Mandatory, ParameterSetName = 'CUSTOM')]
		[Alias("TagName")]
		[ValidateSet("PowerOn", "PowerOff", "Environment", "Project", "Notes", IgnoreCase = $false)]
		[string]$Tag
		 ,
		[Parameter(Mandatory = $false, ParameterSetName = 'CUSTOM')]
		[Alias("TagValue")]
		[string]$Value
		 ,
		[Parameter(Mandatory = $false, ParameterSetName = 'CUSTOM')]
		[Alias("Overwrite")]
		[switch]$Force
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		if ($PSCmdlet.ParameterSetName -eq 'POWER')
		{
			$TimeFormat   = 'HH:mm:ss'
			$PowerOnTime  = $TagPowerOn.ToString($TimeFormat)
			$PowerOffTime = $TagPowerOff.ToString($TimeFormat)
		}
	}	
	Process
	{
		### Power Tags ###
		if ($PSCmdlet.ParameterSetName -eq 'POWER')
		{
			if ($PSCmdlet.ShouldProcess("VM [$($VM.Name)]", "Add Tags pair: PowerOn [$PowerOnTime] - PowerOff [$PowerOffTime]"))
			{
				Try
				{
					If ($VM.Tags.Keys -contains 'poweron') { $null = $VM.Tags.Remove('PowerOn') }
					If ($VM.Tags.Keys -contains 'poweroff') { $null = $VM.Tags.Remove('PowerOff') }
					
					$null = $VM.Tags.Add('PowerOn', $PowerOnTime)
					$null = $VM.Tags.Add('PowerOff', $PowerOffTime)
					
					$JobPower = Update-AzureRmVM -VM $VM -ResourceGroupName $VM.ResourceGroupName
					$Properties = [ordered]@{
						VM = $VM.Name
						ResourceGroup = $VM.ResourceGroupName
						PowerOn = $PowerOnTime
						PowerOff = $PowerOffTime
						StatusCode = $JobPower.StatusCode
					}
				}
				Catch
				{
					$Properties = [ordered]@{
						VM = $VM.Name
						ResourceGroup = $VM.ResourceGroupName
						PowerOn = $PowerOnTime
						PowerOff = $PowerOffTime
						StatusCode = 'Error'
					}
				}
				Finally
				{
					$Object = New-Object PSObject -Property $Properties
					$Object
				}
			}
		}
		### Custom Tag ###	
		else
		{
			if ($PSCmdlet.ShouldProcess("VM [$($VM.Name)]", "Add Tag [$Tag] - Value [$Value], overwrite if exists"))
			{
				Try
				{
					if ($VM.Tags.Keys -contains $Tag)
					{
						if ($Force) { $null = $VM.Tags.Remove($Tag) } else { $Status = 'TagExists' }
					}
					if ($Status -ne 'TagExists')
					{
						$VM.Tags.Add($Tag, $Value)
						$JobCustom = Update-AzureRmVM -VM $VM -ResourceGroupName $VM.ResourceGroupName
						$Status = $JobCustom.StatusCode
					}
					$Properties = [ordered]@{
						VM = $VM.Name
						ResourceGroup = $VM.ResourceGroupName
						Tag = $Tag
						Value = $Value
						StatusCode = $Status
					}
				}
				Catch
				{
					$Properties = [ordered]@{
						VM = $VM.Name
						ResourceGroup = $VM.ResourceGroupName
						Tag = $Tag
						Value = $Value
						StatusCode = 'Error'
					}
				}
				Finally
				{
					$Object = New-Object PSObject -Property $Properties
					$Object
				}
			}
		}
	}
	End
	{
		
	}
	
} #EndFunction Add-AzVmTag

Function Get-AzOrphanedVhd
{
	
<#
.SYNOPSIS
	Get Azure orphaned VHD files.
.DESCRIPTION
	This function finds orphaned* Azure VM disks.
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
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm and Azure.Storage PowerShell Modules
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0 | Azure.Storage v.2.7.0
	Version 1.0 :: 14-Jul-2016 :: [Release] :: Publicly available
	Version 1.1 :: 03-Apr-2017 :: [Change]  :: Added two properties (State, Status) to the returned object [Thanks to Javier González Tejada]
.LINK
	https://ps1code.com/2017/07/05/azure-orphaned-vhd
#>
	
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ()
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$ErrorActionPreference = 'SilentlyContinue'
		$rgxUrl = '^http(:|s:)/{2}'
		$VmVhd = @()
	}
	Process
	{
		### Get registered VM VHD in all ResourceGroups ###
		foreach ($AzRg in ($ResGroup = Get-AzureRmResourceGroup))
		{
			foreach ($AzVm in ($VM = Get-AzureRmVM -ResourceGroupName ($AzRg.ResourceGroupName)))
			{
				$VmVhd += ($AzVm.StorageProfile.OsDisk.Vhd.Uri) -replace ($rgxUrl,'')
				foreach ($DataDisk in $AzVm.StorageProfile.DataDisks)
				{
					$VmVhd += ($DataDisk.Vhd.Uri) -replace ($rgxUrl,'')
				}
			}
		}
		### Get VHD located in all StorageAccounts ###
		foreach ($Vhd in ($SaVhd = Get-AzureRmStorageAccount | Get-AzureStorageContainer | Get-AzureStorageBlob | ? { $_.Name -match '\.vhd$' }))
		{
			$ModifiedLocal = $Vhd.LastModified.LocalDateTime
			$Now           = [datetime]::Now
			### If a change was made less than 24 hours ago, but it was yesterday returns one day and not zero ###
			if (($Days = (New-TimeSpan -End $Now -Start $ModifiedLocal).Days) -eq 0)
			{
				if ($ModifiedLocal.Day-$Now.Day -eq 1 -or $ModifiedLocal.Day -lt $Now.Day) {$Days = 1}
			}

			$Properties = [ordered]@{
				VHD            = $Vhd.Name
				StorageAccount = $Vhd.Context.StorageAccountName
				SizeGB         = [Math]::Round($Vhd.Length/1GB,0)
				Modified       = $ModifiedLocal.ToString('dd/MM/yyyy HH:mm')
				LastWriteDays  = $Days
				FullPath       = ($Vhd.ICloudBlob.Uri) -replace ($rgxUrl,'')
				Snapshot       = $Vhd.ICloudBlob.IsSnapshot
				State          = $Vhd.ICloudBlob.Properties.LeaseState
				Status         = $Vhd.ICloudBlob.Properties.LeaseStatus
			}
			$Object = New-Object PSObject -Property $Properties
			### Return if not in the list only ###
			if ($VmVhd -notcontains $Object.FullPath) { $Object }
		}
	}
	End { }

} #EndFunction Get-AzOrphanedVhd

Function Get-AzVmDisk
{
	
<#
.SYNOPSIS
	Get Azure VM Virtual Disks.
.DESCRIPTION
	This function retrieves Azure VM Virtual Disks info.
.PARAMETER VM
	Specifies Azure VM object(s), returned by Get-AzureRmVm cmdlet.
.PARAMETER DiskType
	Specifies Virtual Disk Type.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject VM |Get-AzVmDisk
	Get all Virtual Disks for selected VM.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |sort Name |Get-AzVmDisk |select * -exclude Path |ft -au
	Get all Virtual Disks for all VM in a ResourceGroup.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |Get-AzVmDisk -DiskType DataDisk |fl
	Get only DataDisks for all VM in a ResourceGroup.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.0/5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 31-Aug-2016 :: [Release] :: Publicly available
	Version 1.1 :: 26-Jun-2017 :: [Change] :: Code optimization
	Version 2.0 :: 19-Oct-2017 :: [Change] :: Returned object type changed from [PSCustomObject] to [AzDisk]
.LINK
	https://ps1code.com/2017/07/05/azure-vm-add-data-disk
#>

	[CmdletBinding()]
	[OutputType([AzDisk])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureVm")]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
		 ,
		[Parameter(Mandatory = $false, Position = 0)]
		[ValidateSet("OSDisk", "DataDisk", "All")]
		[string]$DiskType = 'All'
	)
	
	Begin
	{
		$rgxUri = '^http(:|s:)/{2}(?<StorageAccount>.+?)\..+/(?<Container>.+)/(?<Vhd>.+)$'	
	}
	Process
	{		
		if ('OSDisk', 'All' -contains $DiskType)
		{
			$VmOsDisk = $VM.StorageProfile.OsDisk
			$OsDiskUri = $VmOsDisk.Vhd.Uri
			$OsDiskUriX = [regex]::Match($OsDiskUri, $rgxUri)
			
			[AzDisk] @{
				ResourceGroup = $VM.ResourceGroupName
				VM = $VM.Name
				VMSize = $VM.HardwareProfile.VmSize
				DiskName = $VmOsDisk.Name
				DiskType = 'OSDisk'
				Index = -1
				Lun = -1
				StorageAccount = $OsDiskUriX.Groups['StorageAccount'].Value
				Container = $OsDiskUriX.Groups['Container'].Value
				Vhd = $OsDiskUriX.Groups['Vhd'].Value
				Path = $OsDiskUri
				SizeGB = 0
				Cache = $VmOsDisk.Caching
				Created = $VmOsDisk.CreateOption
			}
		}
		
		if ('DataDisk', 'All' -contains $DiskType)
		{
			$VmDataDisks = $VM.StorageProfile.DataDisks

			for ($i = 0; $i -lt $VmDataDisks.Count; $i++)
			{
				$DataDiskUri = $VmDataDisks[$i].Vhd.Uri
				$DataDiskUriX = [regex]::Match($DataDiskUri, $rgxUri)
				
				[AzDisk] @{
					ResourceGroup = $VM.ResourceGroupName
					VM = $VM.Name
					VMSize = $VM.HardwareProfile.VmSize
					DiskName = $VmDataDisks[$i].Name
					DiskType = 'DataDisk'
					Index = $i
					Lun = $VmDataDisks[$i].Lun
					StorageAccount = $DataDiskUriX.Groups['StorageAccount'].Value
					Container = $DataDiskUriX.Groups['Container'].Value
					Vhd = $DataDiskUriX.Groups['Vhd'].Value
					Path = $DataDiskUri
					SizeGB = $VmDataDisks[$i].DiskSizeGB
					Cache = $VmDataDisks[$i].Caching
					Created = $VmDataDisks[$i].CreateOption
				}
			}
		}
	}
	End
	{
		
	}
	
} #EndFunction Get-AzVmDisk

Function New-AzVmDisk
{
	
<#
.SYNOPSIS
	Add a new Data Disk to an Azure VM.
.DESCRIPTION
	This function creates and attaches a new data disk to an Azure IaaS Virtual Machine.
.PARAMETER VM
	Azure VM object(s), returned by Get-AzureRmVm cmdlet.
.PARAMETER StorageAccount
	Specifies a StorageAccount selection option.
.PARAMETER SizeGB
	Specifies Disk size in GiB.
.PARAMETER Caching
	Specifies Disk caching mode.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject -ObjectType VM |New-AzVmDisk |Format-Table -AutoSize
	Add a new data disk with all default options.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject VM |New-AzVmDisk -StorageAccount Prompt
	Give an option to pick a StorageAccount from a menu.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject VM |New-AzVmDisk -SizeGB 10 -Caching SqlLog
	Add 10 GiB disk with caching mode recommended by Microsoft for SQL logs.
.EXAMPLE
	PS C:\> Select-AzResourceGroup |Select-AzObject VM |New-AzVmDisk OSDisk 10 |select * -exclude Path
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Get-AzVmDisk function (part of this Module)
	Shell       :: Tested on PowerShell 5.0/5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 31-Aug-2016 :: [Release] :: Publicly available
	Version 1.1 :: 26-Jun-2017 :: [Change] :: Code optimization
	Version 2.0 :: 19-Oct-2017 :: [Change] :: Returned object type changed from [PSCustomObject] to [AzDisk], maximum disk size [$SizeGB] increased to 4TB
.LINK
	https://ps1code.com/2017/07/05/azure-vm-add-data-disk
#>
	
	[CmdletBinding()]
	[Alias("Add-AzVmDisk")]
	[OutputType([AzDisk])]
	Param (	
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureVm")]
		[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
		 ,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateSet("OSDisk", "FirstDataDisk", "Prompt")]
		[Alias("sa")]
		[string]$StorageAccount = 'OSDisk'
		 ,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateRange(10, 4095)]
		[uint16]$SizeGB = 100
		 ,
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateSet("None", "ReadOnly", "ReadWrite", "SqlLog", "SqlTempDB", "SqlData")]
		[string]$Caching = 'None'
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		$DataDiskSuffix = '_datadisk'
		$rgxDataDiskIndex = $DataDiskSuffix + '(\d+)\.vhd$'
		$Cache = switch -regex ($Caching)
		{
			'^sql(t|d)' { 'ReadOnly'; Break }
			'^sqll'     { 'None'; Break }
			Default { $Caching }
		}
	}
	Process
	{
		Try
		{
			$VmDisks = Get-AzVmDisk -VM $VM			
			$ResourceGroup = $VM.ResourceGroupName
			
			$OsDisk = $VmDisks | ? { $_.DiskType -eq 'OSDisk' }
			$DataDisks = $VmDisks | ? { $_.DiskType -eq 'DataDisk' } |
			select *, @{ N = 'Index'; E = { (([regex]::Match($_.Vhd, $rgxDataDiskIndex).Groups[1].Value) -as [int]) } } |
			sort Index
			
			### DataDisk Index&Lun ###
			if ($DataDisks)
			{
				$DataDiskIndex = ($DataDisks[-1].Index -as [int]) + 1
				if (!$DataDiskIndex) { $DataDiskIndex = 1 }
				$DataDiskLun = ($DataDisks[-1].Lun -as [int]) + 1
			}
			else
			{
				$DataDiskIndex = 1
				$DataDiskLun = 0
			}
			
			### DataDisk Name ###
			$DataDiskName = $VM.Name + $DataDiskSuffix + $DataDiskIndex
			
			### DataDisk Vhd Name ###
			$DataDiskVhd = $DataDiskName + '.vhd'
			
			switch -exact ($StorageAccount)
			{
				'OSDisk'
				{
					$StorageAccountName = $OsDisk.StorageAccount
					$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
					Break
				}
				'FirstDataDisk'
				{
					if ($DataDisks)
					{
						$StorageAccountName = $DataDisks[0].StorageAccount
						$DataDiskUri = ($DataDisks[0].Path).Replace($DataDisks[0].Vhd, $DataDiskVhd)
					}
					else
					{
						$StorageAccountName = $OsDisk.StorageAccount
						$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
					}
					Break
				}
				'Prompt'
				{
					$StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup | sort StorageAccountName
					
					if (!$StorageAccounts)
					{
						$StorageAccountName = $OsDisk.StorageAccount
						$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd)
					}
					else
					{
						$StorageAccountPrompt = Write-Menu -Menu $StorageAccounts -Shift 1 `
												-Prompt "Select StorageAccount for your DataDisk" `
												-Header "Available StorageAccounts in the [$($VM.ResourceGroupName)] ResourceGroup:" `
												-PropertyToShow StorageAccountName
						$StorageAccountName = $StorageAccountPrompt.StorageAccountName
						$DataDiskUri = ($OsDisk.Path).Replace($OsDisk.Vhd, $DataDiskVhd).Replace($OsDisk.StorageAccount, $StorageAccountName)
					}
				}
			}
			
			### Reconfigure VM ###
			Write-Progress -Activity "Adding Virtual DataDisk to VM [$($VM.Name)]" `
						   -Status "Updating VM configuration ..." `
						   -CurrentOperation "StorageAccount [$StorageAccountName] | DiskName [$DataDiskName] | LUN [$DataDiskLun] | Size [$SizeGB GiB] | Caching [$Cache]"
			$null = Add-AzureRmVMDataDisk -VM $VM -Name $DataDiskName -Lun $DataDiskLun -CreateOption empty -DiskSizeInGB $SizeGB -VhdUri $DataDiskUri -Caching $Cache
			$null = Update-AzureRmVM -VM $VM -ResourceGroupName $ResourceGroup
			Get-AzureRmVm -ResourceGroupName $ResourceGroup -VMName $VM.Name | Get-AzVmDisk
		}
		Catch
		{
			"{0}" -f $Error.Exception.Message
		}
	}
	End
	{
		Write-Progress -Activity "Completed" -Completed
	}
	
} #EndFunction New-AzVmDisk

Function Expand-AzVmDisk
{
	
<#
.SYNOPSIS
	Increase Azure VM disk.
.DESCRIPTION
	This function increases Azure IaaS Virtual Machine OS or Data disk.
.PARAMETER Disk
	Azure VM Disk object(s), returned by Get-AzVmDisk function.
.PARAMETER SizeGB
	Specifies resultant disk size in GB.
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject -ObjectType VM | Get-AzVmDisk | Expand-AzVmDisk -SizeGB 150
	Increase any disk, the VM deallocation will be required.
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject VM | Get-AzVmDisk DataDisk | Expand-AzVmDisk 4095
	Increase one or more DataDisks to a maximum allowed size.
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject VM | Get-AzVmDisk OSDisk | Expand-AzVmDisk 2048 -Verbose
	Increase OSDisk to a maximum allowed size.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module; Get-AzVmDisk, Get-AzVmPowerState, Write-Menu functions
	Shell       :: Tested on PowerShell 5.0/5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 19-Oct-2017 :: [Release] :: Publicly available
	Version 1.1 :: 12-Feb-2018 :: [Bugfix] :: PoweredOn VM deallocated in any case even while a DataDisk increase, [-Verbose] output supported
.LINK
	https://ps1code.com/2017/10/24/azure-vm-increase-disk
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[OutputType([AzDisk])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[AzDisk]$Disk
		 ,
		[Parameter(Mandatory, Position = 0)]
		[ValidateRange(10, 4095)]
		[uint16]$SizeGB
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
	}
	Process
	{
		if ($SizeGB -le $Disk.SizeGB) { Throw "The resultant disk size must be greater than $($Disk.SizeGB) GB!" }
		if ($Disk.DiskType -eq 'OSDisk' -and $SizeGB -gt 2048) { Throw "The maximum allowed size for OSDisks is 2048 GB!" }
		
		### Deallocate running VM ###
		$VM = Get-AzureRmVM -Name $Disk.VM -ResourceGroupName $Disk.ResourceGroup
		$PowerOn = if (($VM | Get-AzVmPowerState).PowerState -ne 'Deallocated') #-and $Disk.DiskType -eq 'OSDisk')
		{
			$resStop = $VM | Stop-AzureRmVM
			if ($resStop.Status -eq 'Succeeded')
			{
				Write-Verbose "The [$($Disk.VM)] VM has been deallocated successfully"
				$true
			}
			else
			{
				Throw $resStop.Error
				$false
			}
		}
		else
		{
			$false
		}
		
		if ($PSCmdlet.ShouldProcess("$($Disk.VMSize) VM [$($Disk.VM)]", "Increase $($Disk.DiskType) [$($Disk.DiskName)] from $($Disk.SizeGB) to $($SizeGB) GB"))
		{
			### Increase disk ###
			if ($Disk.DiskType -eq 'OSDisk') { $VM.StorageProfile.OSDisk.DiskSizeGB = $SizeGB }
			else { $VM.StorageProfile.DataDisks[$($Disk.Index)].DiskSizeGB = $SizeGB }
			
			Try
			{
				$resUpdate = $VM | Update-AzureRmVM
				Write-Verbose "The [$($Disk.VM)] VM config has been updated successfully"
			}
			Catch { Throw "Failed to update VM config" }
			
			### PowerOn VM if it was PoweredOn before ##
			if ($resUpdate.IsSuccessStatusCode)
			{
				Get-AzureRmVM -Name $Disk.VM -ResourceGroupName $Disk.ResourceGroup | Get-AzVmDisk
				if ($PowerOn)
				{
					Write-Verbose "The [$($Disk.VM)] VM was started"
					Get-AzureRmVM -Name $Disk.VM -ResourceGroupName $Disk.ResourceGroup | Start-AzureRmVm | Out-Null
				}
			}
			else { $resUpdate.ReasonPhrase }
		}
	}
	
} #EndFunction Expand-AzVmDisk

Function New-AzCredProfile
{
	
<#
.SYNOPSIS
	Set your PowerShell session to automatically login to the Azure.
.DESCRIPTION
	This function saves your Azure credentials to a secure JSON file
	and sets your PowerShell session to automatically login to the Azure.
	In addition you will be prompted to select your Azure subscription from the list
	and select and save to the variable your current ResourceGroup.
.PARAMETER AzureProfilePath
	Specifies the path of the file to which to save the Azure authentication info.
.PARAMETER ShowProfile
	Open your PowerShell profile script ($PROFILE) by your favorite script editor.
.EXAMPLE
	PS C:\> New-AzCredProfile
.EXAMPLE
	PS C:\> New-AzCredProfile -ShowProfile
.EXAMPLE
	PS C:\> New-AzCredProfile "$($env:USERPROFILE)\Documents\Azure.json"
	Save the JSON in an alternate location.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module
	Requirement :: AzureRM Module version 2.0+
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 04-Jan-2017 :: [Release] :: Publicly available
	Version 1.1 :: 10-Jan-2017 :: [Multiple Changes]
	   [Bugfix] :: Empty `$PROFILE` file was not processed
	   [Change] :: Suppressed confirmation on existing Azure profile
	  [Feature] :: Added command to populate VM list in the selected Resource Group
	Version 1.2 :: 26-Jun-2017 :: [Change]
	Version 1.3 :: 28-Jun-2017 :: [Bugfix] :: 'PowerSate' representation because Get-AzVmPowerState function change
.LINK
	https://ps1code.com/2017/07/05/login-to-azure-automatically
#>

	[CmdletBinding()]
	[OutputType([bool])]
	Param (
		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "Secure JSON full path")]
		[ValidatePattern("\.json$")]
		[ValidateScript({Test-Path (Split-Path $_) -PathType 'Container'})]
		[string]$AzureProfilePath = "$(Split-Path $PROFILE)\azure.json"
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$ShowProfile
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		
		### Get your Azure credentials ###
		$AzCred = Get-Credential -Message 'Azure Credentials' -User 'user@onmicrosoft.com'
		if (!$AzCred.GetNetworkCredential().Password)
		{ Throw "You must provide a password for the [$($AzCred.GetNetworkCredential().UserName)] account!" }
		
		### Connect to your Azure environment ###
		Try { $AzProfile = Login-AzureRmAccount -Credential $AzCred }
		Catch { Throw "Failed to login to the Azure, please validate your credentials!" }
	}
	Process
	{
		### Create your PowerShell profile script if doesn't exists yet ###
		Try { if (!(Test-Path $PROFILE -PathType Leaf)) { New-Item -ItemType File -Force $PROFILE } }
		Catch { Throw "Failed to create your PowerShell profile script [$PROFILE]!" }
		
		### Save your Azure profile credentials ###
		Try { Save-AzureRmProfile -Path $AzureProfilePath -Force }
		Catch { Throw "Failed to save your Azure Profile [$AzureProfilePath]!" }
		
		### Embed the Azure profile initialization into your PowerShell profile ###
		$InitAzProfile = "Select-AzureRmProfile -Path $AzureProfilePath"
		$SelectSubscription = "Select-AzureRmSubscription -SubscriptionName ((Write-Menu -Menu (Get-AzureRmSubscription -WA SilentlyContinue) -PropertyToShow SubscriptionName -Header 'Welcome to Azure' -Prompt 'Select Subscription' -Shift 1).SubscriptionName)"
		$SelectResourceGroup = "`$AzResourceGroup = (Write-Menu -Menu (Get-AzureRmResourceGroup -WA SilentlyContinue) -PropertyToShow ResourceGroupName -Header 'Initialize variable [`$AzResourceGroup]' -Prompt 'Select ResourceGroup' -Shift 1).ResourceGroupName"
		$GetVM = "Get-AzureRmVM -WA SilentlyContinue -ResourceGroupName `$AzResourceGroup |select @{N='VM';E={`$_.Name}},@{N='Size';E={`$_.HardwareProfile.VmSize}},@{N='PowerState';E={(`$_ |Get-AzVmPowerState).PowerState}} |sort PowerState,VM |ft -au"
		
		if ((Get-Content $PROFILE -Raw) -notmatch 'Select-AzureRmProfile' -or !(Get-Content $PROFILE -Raw))
		{
			Try
			{
				"`n### AZURE AUTO LOGIN ###" | Out-File $PROFILE -Append -Confirm:$false
				$InitAzProfile | Out-File $PROFILE -Append -Confirm:$false
				$SelectSubscription | Out-File $PROFILE -Append -Confirm:$false
				$SelectResourceGroup | Out-File $PROFILE -Append -Confirm:$false
				$GetVM | Out-File $PROFILE -Append -Confirm:$false
				
				return $true
				
				### Open your PowerShell profile script ###
				if ($ShowProfile) { Invoke-Item $PROFILE }
			}
			Catch
			{
				return "{0}" -f $Error.Exception.Message
			}
		}
		else
		{
			return $false
		}
	}
	End
	{
		
	}

} #EndFunction New-AzCredProfile

Function Select-AzResourceGroup
{
	
<#
.SYNOPSIS
	Interactively select Azure ResourceGroup Name.
.DESCRIPTION
	This function allows interactively (from Menu list) to select
	Azure ResourceGroup Name.
.EXAMPLE
	PS C:\> Select-AzResourceGroup
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName (Select-AzResourceGroup) |Get-AzVmPowerState |ft -au
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 26-Jun-2017 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2017/06/29/azure-vm-tags
#>
	
	[CmdletBinding()]
	[Alias("sazrg")]
	[OutputType([string])]
	Param ()
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
	}
	Process
	{
		$DefaultProperty = 'ResourceGroupName'
		return (Write-Menu -Menu (Get-AzureRmResourceGroup | sort $DefaultProperty) `
					 -PropertyToShow $DefaultProperty `
					 -Header 'Available Resource Groups' `
					 -Prompt 'Select Resource Group' `
					 -HeaderColor 'Yellow' -TextColor 'White' -Shift 1
				).$DefaultProperty

	}
	End
	{
		
	}
	
} #EndFunction Select-AzResourceGroup

Function Select-AzLocation
{
	
<#
.SYNOPSIS
	Interactively select Azure Location.
.DESCRIPTION
	This function allows interactively (from Menu list) to select Azure Location.
.PARAMETER Region
	If specified, the locations list will be filtered out by particular Azure region.
.PARAMETER NameOnly
	If specified, the object name only returned insted of the whole object.
.EXAMPLE
	PS C:\> Select-AzLocation
.EXAMPLE
	PS C:\> Select-AzLocation -Region US
.EXAMPLE
	PS C:\> Select-AzLocation Asia -NameOnly
.EXAMPLE
	PS C:\> Select-AzLocation | Get-AzureRmVMSize
	Get all VMSizes available in the selected Azure Location.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.0
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 14-Feb-2018 :: [Release] :: Publicly available
	Version 1.1 :: 15-Feb-2018 :: [Feature] :: Added [-Region] parameter
.LINK
	https://ps1code.com/2018/02/19/azure-vm-size-powershell
#>
	
	[CmdletBinding()]
	[Alias("sazlo")]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[ValidateSet('Asia', 'Australia', 'Brazil', 'Canada', 'Europe',
			'India', 'Japan', 'Korea', 'UK', 'US', IgnoreCase = $false)]
		[string]$Region
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$NameOnly
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$Header = 'Available Locations'
		$DisplayProperty = 'DisplayName'
		$NameProperty = 'Location'
	}
	Process
	{
		
		$Locations = if ($PSBoundParameters.ContainsKey('Region'))
		{
			(Get-AzureRmLocation).Where{ $_.$DisplayProperty -cmatch $Region }
			$Header += " in the $Region region"
		}
		else { Get-AzureRmLocation }
		
		$AzObject = Write-Menu -Menu ($Locations | sort $DisplayProperty) `
							   -PropertyToShow $DisplayProperty `
							   -Header $Header `
							   -Prompt 'Select Location' `
							   -HeaderColor 'Yellow' -TextColor 'White' -Shift 1
	}
	End
	{
		if ($NameOnly) { $AzObject.$NameProperty } else { $AzObject }
	}
	
} #EndFunction Select-AzLocation

Function Select-AzSubscription
{
	
<#
.SYNOPSIS
	Interactively select Azure Subscription.
.DESCRIPTION
	This function allows interactively (from Menu list) to select
	Azure Subscription name and pass it to Select-AzureRmSubscription cmdlet.
.EXAMPLE
	PS C:\> Select-AzSubscription
.EXAMPLE
	PS C:\> Select-AzSubscription -Title
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.0/5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 24-Aug-2017 :: [Release] :: Publicly available
	Version 1.1 :: 19-Oct-2017 :: [Feature] :: New parameter -Title
.LINK
	https://ps1code.com/
#>
	
	[CmdletBinding()]
	[Alias("sazsu")]
	Param (
		[Parameter(Mandatory = $false)]
		[switch]$Title
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
	}
	Process
	{
		$DefaultProperty = 'Name'
		$SubscriptionName = (Write-Menu -Menu (Get-AzureRmSubscription | sort $DefaultProperty) `
					 -PropertyToShow $DefaultProperty `
					 -Header 'Available Subscriptions' `
					 -Prompt 'Select Subscription' `
					 -HeaderColor 'Yellow' -TextColor 'White' -Shift 1
		).$DefaultProperty
		$res = Select-AzureRmSubscription -SubscriptionName $SubscriptionName
		if ($Title) { $Host.UI.RawUI.WindowTitle = "$($res.Environment) - [$SubscriptionName]" }
	}
	End
	{
		$res
	}
	
} #EndFunction Select-AzSubscription

Function Select-AzObject
{
	
<#
.SYNOPSIS
	Interactively select an Azure object.
.DESCRIPTION
	This function allows interactively (from Menu list) select
	single object, related to particular object type.
.PARAMETER ResourceGroup
	Specifies ResourceGroup name.
.PARAMETER ObjectType
	Specifies Azure object type (VM, StorageAccount, etc.).
.PARAMETER NameOnly
	If specified, the object name only returned insted of the whole object.
.EXAMPLE
	PS C:\> Select-AzObject StorageAccount
.EXAMPLE
	PS C:\> Select-AzResourceGroup | Select-AzObject -ObjectType AS -NameOnly
.EXAMPLE
	PS C:\> Select-AzObject -ObjectType VirtualNetwork -ResourceGroup (Select-AzResourceGroup) -NameOnly -Verbose
.EXAMPLE
	PS C:\> Select-AzObject -ObjectType VM | Get-AzVmDisk
.EXAMPLE
	PS C:\> Select-AzObject VNET | select -expand DhcpOptions
.EXAMPLE
	PS C:\> Select-AzObject VM -Filter testvm* | Start-AzureRmVM
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 26-Jun-2017 :: [Release] :: Publicly available
	Version 1.1 :: 08-Feb-2018 :: [Change] :: Added [Select-AzItem] alias, verbose output [-Verbose] and [-Filter] parameter
.LINK
	https://ps1code.com/2018/02/14/azure-vhd-operations-powershell
#>
	
	[CmdletBinding()]
	[Alias("Select-AzItem", "sazob")]
	Param (
		[Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias("ResourceGroupName", "RG")]
		[string]$ResourceGroup
		 ,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateSet("VM", "StorageAccount", "SA", "VirtualNetwork", "VNET", "AvailabilitySet", "AS")]
		[string]$ObjectType = 'VM'
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$NameOnly
		 ,
		[Parameter(Mandatory = $false, Position = 2)]
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string]$Filter
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$DefaultProperty = 'Name'
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
		$menuHeader = "Available $($ObjectType)s"
		$menuHeaderC = 'Yellow'
		$menuTextC = 'White'
		$menuShift = 1
	}
	Process
	{
		$AzureRmFunction = switch -exact ($ObjectType)
		{
			'VM'
			{
				'Get-AzureRmVM'
			}
			{ 'StorageAccount', 'SA' -contains $_ }
			{
				'Get-AzureRmStorageAccount'
				$DefaultProperty = 'StorageAccountName'
			}
			{ 'VirtualNetwork', 'VNET' -contains $_ }
			{
				'Get-AzureRmVirtualNetwork'
			}
			{ 'AvailabilitySet', 'AS' -contains $_ }
			{
				'Get-AzureRmAvailabilitySet'
				if (!$PSBoundParameters.ContainsKey('ResourceGroup')) { Throw "You have to specify ResourceGroup name" }
			}
		}
		
		### Build menu ###
		$Menu = if ($PSBoundParameters.ContainsKey('ResourceGroup'))
		{
			$menuHeader = "$menuHeader in the [$ResourceGroup] Resource Group"
			&$AzureRmFunction -ResourceGroupName $ResourceGroup
		}
		else
		{
			&$AzureRmFunction
		}
		
		### Shorten the menu by -Filter ###
		$Menu = if ($PSBoundParameters.ContainsKey('Filter')) { $Menu | ? { $_.$DefaultProperty -like $Filter } } else { $Menu }
		
		### Show menu ###
		$AzObject = if ($Menu)
		{
			Write-Menu -Menu ($Menu | sort $DefaultProperty) `
				 -PropertyToShow $DefaultProperty `
				 -Header $menuHeader `
				 -Prompt "Select $ObjectType" `
				 -HeaderColor $menuHeaderC -TextColor $menuTextC -Shift $menuShift
			Write-Verbose "$FunctionName - A $ObjectType object selected"
		}
		else
		{
			$null
			Write-Verbose "$FunctionName - No $ObjectType found!"
		}
		
	}
	End
	{
		if ($NameOnly) { $AzObject.$DefaultProperty } else { $AzObject }
	}
	
} #EndFunction Select-AzObject

Function Get-AzSubnet
{
	
<#
.SYNOPSIS
	Get Azure Subnets Busy IP addresses.
.DESCRIPTION
	This function retrieves busy IP addresses in each Azure Subnet.
.PARAMETER VirtualNetwork
	Specifies Azure VirtualNetwork object(s), returned by Get-AzureRmVirtualNetwork cmdlet.
.PARAMETER Name
	Specifies Subnet name.
.EXAMPLE
	PS C:\> Get-AzureRmVirtualNetwork | Get-AzSubnet
.EXAMPLE
	PS C:\> Select-AzObject VirtualNetwork | Get-AzSubnet
	Interactively select VNET and get Subnets info.
.EXAMPLE
	PS C:\> Select-AzObject VirtualNetwork | Get-AzSubnet | ? {$_.Address -like '172.23.*'}
	Find Subnets which IP address concerns to 172.23.x.x networks.
.EXAMPLE
	PS C:\> Select-AzObject VirtualNetwork | Get-AzSubnet | ? {$_.Subnet -like 'dmz*'}
	Find Subnets which names start from 'dmz'.
.EXAMPLE
	PS C:\> Select-AzObject VNET | Get-AzSubnet -Name subnet1 | ? {$_.BusyIP -contains '172.31.2.100'}
	Check if particular IP is currently being busy.
.EXAMPLE
	PS C:\> Select-AzObject VNET | Get-AzSubnet test-subnet-1 | select -expand BusyIP
	Expand BusyIP property for particular subnet.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.0/5.1
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 26-Jun-2017 :: [Release] :: Publicly available
	Version 1.1 :: 24-Aug-2017 :: [Improvement] :: Added property [BusyIP] for every Subnet
	Version 1.2 :: 29-Oct-2017 :: [Improvement] :: Added [-Name] parameter to specify Subnet name and [ResourceGroup] property, IP addresses sorted by Sort-IpAddress
	Version 1.3 :: 05-Feb-2018 :: [Bugfix] :: Single IP in the [BusyIP] property returned as array
.LINK
	https://ps1code.com/2017/10/30/azure-ipam-powershell
#>
	
	[CmdletBinding()]
	[Alias("Get-AzBusyIP")]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
		 ,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	
	Begin
	{ }
	Process
	{
		$IPs = Get-AzureRmNetworkInterface | ? { $_.VirtualMachine.Id } |
		select @{ N = 'IP'; E = { $_.IpConfigurations.PrivateIpAddress } },
		  	   @{ N = 'Subnet'; E = { $script:subnet = if ($_.IpConfigurations.Subnet.Id.GetType().Name -eq 'string') `
				{ $_.IpConfigurations.Subnet.Id } `
				else { $_.IpConfigurations.Subnet.Id[0] } `
				[regex]::Match($script:subnet, 'subnets/(.+)$').Groups[1].Value } } | ? { $_.IP -match '\.' } | sort Subnet, IP
		
		
		$Subnets = if ($PSBoundParameters.ContainsKey('Name')) { $VirtualNetwork | select -expand Subnets | select Name, AddressPrefix | ? { $_.Name -eq $Name } }
		else { $VirtualNetwork | select -expand Subnets | select Name, AddressPrefix | sort Name }
		
		foreach ($Subnet in $Subnets)
		{
			$BusyIP = @()
			foreach ($IP in $IPs) { if ($Subnet.Name -eq $IP.Subnet) { $BusyIP += $IP.IP } }
			$BusyIP = $BusyIP | Invoke-SortIpAddress
			
			[pscustomobject] @{
				ResourceGroup = $VirtualNetwork.ResourceGroupName
				Network = $VirtualNetwork.Name
				Subnet = $Subnet.Name
				Address = $Subnet.AddressPrefix
				BusyIP = @($BusyIP)
			}
		}
	}
	End
	{ }
	
} #EndFunction Get-AzSubnet

Function Select-AzChildObject
{
	
<#
.SYNOPSIS
	Interactively select an Azure child object.
.DESCRIPTION
	This function allows interactively (from Menu list) select
	single child object, related to particular object type.
.PARAMETER ParentObject
	Specifies Parent object to retrieve any its childs.
.PARAMETER CustomOutput
	If specified, the original Microsoft object will be changed to more reliable custom object.
.EXAMPLE
	PS C:\> $azObject = Select-AzObject StorageAccount | Select-AzChildObject
	Select any Storage Account's child object and save it to a variable.
.EXAMPLE
	PS C:\> Select-AzObject SA | Select-AzChildObject -CustomOutput -Verbose
.EXAMPLE
	PS C:\> Select-AzObject SA | Select-AzChildObject | Select-AzChildObject
	Choice 'Blob Container' first and then 'Blob' to retrieve Blobs from a single Container to improve query's performance.
.EXAMPLE
	PS C:\> Select-AzObject VM | Select-AzChildObject
.EXAMPLE
	PS C:\> Select-AzObject SA | Select-AzChildObject -Filter *.vhd
	Shorten menu list by filtering out VHD blobs only.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Requirement :: PowerShell 4.0
	Dependency  :: AzureRm PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.0
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 14-Feb-2018 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2018/02/14/azure-vhd-operations-powershell
#>
	
	[CmdletBinding()]
	[Alias("sazco", "Select-AzChildItem", "sazci")]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		$ParentObject
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$CustomOutput
		 ,
		[Parameter(Mandatory = $false, Position = 1)]
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string]$Filter
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$DefaultProperty = 'Name'
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
		$menuHeaderC = 'Yellow'
		$menuTextC = 'White'
		$menuShift = 1
	}
	Process
	{
		### Get supported child object type(s) ###
		$ChildObjectTypes = switch ($ParentObject)
		{
			### PARENT :: [Storage Account] ###
			{ $_ -is [Microsoft.Azure.Commands.Management.Storage.Models.PSStorageAccount] }
			{
				@('Storage Context', 'Blob', 'Blob Container', 'Share', 'File', 'Table', 'Queue')
				Break
			}
			### PARENT :: [Container] ###
			{ $_ -is [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer] }
			{
				'Single Container Blob'
				Break
			}
			### PARENT :: [VM] ###
			{ $_ -is [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList] }
			{
				'Vnic'
			}
			### PARENT :: NOT SUPPORTED ###
			Default { Throw "Not supported Parent Object type" }
		}
		
		### Select child object type ###
		if ($ChildObjectTypes.Count -gt 1)
		{
			$ChildObjectType = Write-Menu -Menu $ChildObjectTypes `
									-Header 'Child Objects' `
									-Prompt "Select Object Type" `
									-HeaderColor $menuHeaderC -TextColor $menuTextC -Shift $menuShift
		}
		else { $ChildObjectType = $ChildObjectTypes }

		### Build menu ###
		$Menu = switch -exact ($ChildObjectType)
		{
			'Blob' { ($ParentObject | Get-AzureStorageContainer | Get-AzureStorageBlob).Where{ $_.Name -notmatch '{|}' }; Break }
			'Single Container Blob' { ($ParentObject | Get-AzureStorageBlob).Where{ $_.Name -notmatch '{|}' }; Break }
			'Blob Container' { $ParentObject | Get-AzureStorageContainer; Break }
			'Storage Context' {
				Get-AzureRmStorageAccountKey -ResourceGroupName $ParentObject.ResourceGroupName -Name $ParentObject.StorageAccountName
				$DefaultProperty = 'KeyName'
				Break
			}
			'Share' { $ParentObject | Get-AzureStorageShare; Break }
			'File' { $ParentObject | Get-AzureStorageShare | Get-AzureStorageFile; Break }
			'Table' { $ParentObject | Get-AzureStorageTable; Break }
			'Queue' { $ParentObject | Get-AzureStorageQueue; Break }
			'Vnic' { Get-AzureRmNetworkInterface | ? { $ParentObject.NetworkProfile.NetworkInterfaces.Id -contains $_.Id }; Break }
		}
		### Truncate the menu by -Filter ###
		$Menu = if ($PSBoundParameters.ContainsKey('Filter')) { $Menu | ? { $_.$DefaultProperty -like $Filter } } else { $Menu }
		
		### Show menu ###
		$AzObject = if ($Menu)
		{
			Write-Menu -Menu ($Menu | sort $DefaultProperty) `
				 -PropertyToShow $DefaultProperty `
				 -Header "Available $($ChildObjectType)s" `
				 -Prompt "Select $ChildObjectType" `
				 -HeaderColor $menuHeaderC -TextColor $menuTextC -Shift $menuShift
			Write-Verbose "$FunctionName - A $($ChildObjectType) object selected"
		}
		else
		{
			$null
			Write-Verbose "$FunctionName - No $($ChildObjectType) objects found!"
		}
		
		### Output ###
		if ($CustomOutput)
		{
			switch -exact ($ChildObjectType)
			{
				'Blob' {
					$AccessKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ParentObject.ResourceGroupName -StorageAccountName $ParentObject.StorageAccountName -ErrorAction Stop
					[AzBlob] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						AccessKey = $AccessKeys[0].Value
						Location = $ParentObject.Location
						BlobName = $AzObject.Name
						BlobUri = $AzObject.ICloudBlob.Uri
						SizeGB = [Math]::Truncate($AzObject.Length/1GB)
						Modified = $AzObject.LastModified.ToLocalTime()
						LeaseStatus = [string]$AzObject.ICloudBlob.Properties.LeaseStatus
						LeaseState = [string]$AzObject.ICloudBlob.Properties.LeaseState
						ContainerName = $AzObject.ICloudBlob.Container.Name
						ContainerUri = $AzObject.ICloudBlob.Container.Uri
					}
					Break
				}
				'Single Container Blob' {
					$AccessKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ParentObject.ResourceGroupName -StorageAccountName $ParentObject.StorageAccountName -ErrorAction Stop
					$SA = (Get-AzureRmStorageAccount -ErrorAction Stop).Where{ $_.StorageAccountName -eq $AzObject.Context.StorageAccountName }
					[AzBlob] @{
						ResourceGroup = $SA.ResourceGroupName
						ParentStorageAccount = $AzObject.Context.StorageAccountName
						AccessKey = $AccessKeys[0].Value
						Location = $SA.Location
						BlobName = $AzObject.Name
						BlobUri = $AzObject.ICloudBlob.Uri
						SizeGB = [Math]::Truncate($AzObject.Length/1GB)
						Modified = $AzObject.LastModified.ToLocalTime()
						LeaseStatus = [string]$AzObject.ICloudBlob.Properties.LeaseStatus
						LeaseState = [string]$AzObject.ICloudBlob.Properties.LeaseState
						ContainerName = $AzObject.ICloudBlob.Container.Name
						ContainerUri = $AzObject.ICloudBlob.Container.Uri
					}
					Break
				}
				'Blob Container' {
					$AccessKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ParentObject.ResourceGroupName -StorageAccountName $ParentObject.StorageAccountName -ErrorAction Stop
					[AzBlobContainer] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						AccessKey = $AccessKeys[0].Value
						Location = $ParentObject.Location
						ContainerName = $AzObject.Name
						ContainerUri = $AzObject.CloudBlobContainer.Uri
						PublicAccess = [string]$AzObject.PublicAccess
						Modified = $AzObject.LastModified.ToLocalTime()
						LeaseStatus = [string]$AzObject.CloudBlobContainer.Properties.LeaseStatus
						LeaseState = [string]$AzObject.CloudBlobContainer.Properties.LeaseState
					}	
					Break
				}
				'Storage Context' {
					New-AzureStorageContext -StorageAccountName $ParentObject.StorageAccountName -StorageAccountKey $AzObject.Value
					Break
				}
				'Share' {
					[pscustomobject] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						Location = $ParentObject.Location
						ShareName = $AzObject.Name
						Host = $AzObject.Uri.Host
						Uri = [uri]$AzObject.Uri.OriginalString
						IsReadOnly = $AzObject.Metadata.IsReadOnly
						Modified = $AzObject.Properties.LastModified.ToLocalTime()
						QuotaTB = [Math]::Round($AzObject.Properties.Quota/1024, 0)
					}
					Break
				}
				'File' {
					$Modified = Try { $AzObject.Properties.LastModified.ToLocalTime() } Catch { $null }
					[pscustomobject] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						Location = $ParentObject.Location
						FileName = $AzObject.Name
						ShareName = $AzObject.Share.Name
						ShareUri = $AzObject.Share.Uri
						SizeMB = [Math]::Round($AzObject.Properties.Length/1MB, 2)
						IsReadOnly = $AzObject.Metadata.IsReadOnly
						Modified = $Modified
					}
					Break
				}
				'Table' {
					[pscustomobject] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						Location = $ParentObject.Location
						TableName = $AzObject.Name
						TableUri = $AzObject.Uri.OriginalString
						IsReadOnly = $AzObject.Context.ExtendedProperties.IsReadOnly
					}
					Break
				}
				'Queue' {
					[pscustomobject] @{
						ResourceGroup = $ParentObject.ResourceGroupName
						ParentStorageAccount = $ParentObject.StorageAccountName
						Location = $ParentObject.Location
						QueueName = $AzObject.Name
						QueueUri = $AzObject.Uri.OriginalString
						IsReadOnly = $AzObject.Context.ExtendedProperties.IsReadOnly
					}
					Break
				}
				'Vnic' {
					$IpConfigs = $AzObject.IpConfigurations | % { if ($_.PrivateIpAddressVersion -eq 'ipv4') { $_ } }
					[pscustomobject] @{
						ResourceGroup = $AzObject.ResourceGroupName
						ParentVm = $ParentObject.Name
						Location = $AzObject.Location
						VnicName = $AzObject.Name
						PrivateIPv4 = $IpConfigs.PrivateIpAddress
						PublicIPv4 = $IpConfigs.PublicIpAddress.IpAddress
						MAC = $AzObject.MacAddress
						Subnet = $AzObject.IpConfigurations | % { [regex]::Match($_.Subnet.Id, '.+/(.+)$').Groups[1].Value }
					}
					Break
				}
			}
		}
		else { $AzObject }
	}
	End { }
	
} #EndFunction Select-AzChildObject

Function Copy-AzBlob
{
	
<#
.SYNOPSIS
	Copy Azure blobs.
.DESCRIPTION
	This function copies or moves Azure blobs (*.VHD or any other files) to another location.
	The location may be either another blob container or container in different Storage Account.
.PARAMETER Blob
	Specifies Azure blob (aka source file).
.PARAMETER Container
	Specifies Azure container (aka destination folder).
.PARAMETER NewName
	If specified, the blob will be renamed at the destination.
	If the new name does not include a file extension, it will be inherited from the source blob.
.PARAMETER Move
	If specified, the blob will be deleted at the source location after successful copy.
.EXAMPLE
	PS C:\> Select-AzObject StorageAccount | Select-AzChildObject -CustomOutput | Copy-AzBlob -Container (Select-AzObject StorageAccount | Select-AzChildObject -CustomOutput)
.EXAMPLE
	PS C:\> Select-AzObject SA | Select-AzChildObject -CustomOutput -Verbose | Copy-AzBlob -Container (Select-AzObject SA | Select-AzChildObject -CustomOutput -Verbose) -NewName vm1_osdisk.vhd -Move
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module, Select-AzChildObject function (part of this Module)
	Shell       :: Tested on PowerShell 5.0
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 14-Feb-2018 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2018/02/14/azure-vhd-operations-powershell
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[Alias("Copy-AzVhd", "cpblob")]
	[OutputType([AzBlob])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[AzBlob]$Blob
		 ,
		[Parameter(Mandatory, Position = 0)]
		[Alias("Destination")]
		[AzBlobContainer]$Container
		 ,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$NewName
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$Move
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
		$Action = if ($Move) { 'Move' } else { 'Copy' }
	}
	Process
	{
		$NewBlobName = if ($PSBoundParameters.ContainsKey('NewName'))
		{
			if ($NewName -notmatch '\.') { "$NewName$([regex]::Match($($Blob.BlobName), '\.\w+$').Value)" }
			else { $NewName }
			$Action += ' and rename'
		}
		else { $Blob.BlobName }
		
		if ($PSCmdlet.ShouldProcess("Storage Account [$($Blob.ParentStorageAccount)]", "$Action blob [$($Blob.BlobName)] to the container [$($Container.ContainerUri)]"))
		{
			$srcContext = New-AzureStorageContext -StorageAccountName $Blob.ParentStorageAccount -StorageAccountKey $Blob.AccessKey
			$dstContext = New-AzureStorageContext -StorageAccountName $Container.ParentStorageAccount -StorageAccountKey $Container.AccessKey
			
			$outCopy = Start-AzureStorageBlobCopy -SrcContainer $Blob.ContainerName `
									   -DestContainer $Container.ContainerName `
									   -SrcBlob $Blob.BlobName `
									   -DestBlob $NewBlobName `
									   -Context $srcContext `
									   -DestContext $dstContext
			if ($?)
			{
				[AzBlob] @{
					ResourceGroup = $Container.ResourceGroup
					ParentStorageAccount = $Container.ParentStorageAccount
					AccessKey = $Container.AccessKey
					Location = $Container.Location
					BlobName = $NewBlobName
					BlobUri = [uri]"$($Container.ContainerUri)/$NewBlobName"
					SizeGB = $Blob.SizeGB
					Modified = $outCopy.LastModified.ToLocalTime()
					LeaseStatus = 'Unlocked'
					LeaseState = 'Available'
					ContainerName = $Container.ContainerName
					ContainerUri = $Container.ContainerUri
				}
				if ($Move)
				{
					if ($Blob.LeaseState -eq 'leased') { Write-Error "$FunctionName - The source blob is leased and cannot be removed, please break the lease and remove it manually" }
					else { Remove-AzureStorageBlob -Container $Blob.ContainerName -Context $srcContext -Blob $Blob.BlobName | Out-Null }
				}
			}
		}
	}
	End { }
	
} #EndFunction Copy-AzBlob

Function New-AzParamsJson
{
	
<#
.SYNOPSIS
	Create Azure deployment parameters JSON file.
.DESCRIPTION
	This function creates Azure resource group deployment parameters json file
	either from user provided parameters hash table or from source json template file.
	If created successfully, the reference to the file is returned.
.PARAMETER Params
	Specifies parameters hashtable. Example: @{ParameterName1 = Value1; ParameterName2 = Value2;} etc.
.PARAMETER TemplatePath
	Specifies json template file full path.
.PARAMETER JsonPath
	Specifies json output file full path.
	If the *.json extension is missed, it will be automatically added.
.EXAMPLE
	PS C:\> New-AzParamsJson C:\AzureDeploy\blank.params.json
	Create a blank json with no parameters.
.EXAMPLE
	PS C:\> New-AzParamsJson -JsonPath C:\AzureDeploy\azvm1.params -Params @{'vmName' = 'azvm1'; 'vmSize' = 'Standard_D2_v3'; 'storageAccount' = 'azstg01lrs';} | Get-Content
	Create a json with three parameters and view its content in the console.
.EXAMPLE
	PS C:\> New-AzParamsJson C:\AzureDeploy\Vm_from_Vhd.params -TemplatePath C:\AzureDeploy\Vm_from_Vhd.json
	Create json parameters file, based on json template. The parameters' values will be empty.
.EXAMPLE
	PS C:\> Get-Item 'C:\AzureDeploy\Vm_from_Vhd.json' | New-AzParamsJson C:\AzureDeploy\Vm_from_Vhd.params | Get-Content
	The template json may be pipelined to the function.
.EXAMPLE
	PS C:\> Get-ChildItem C:\AzureDeploy\ -Filter *.json -Recurse | ? { $_.BaseName -inotmatch '\.param(s|eters)$' } | % { New-AzParamsJson "$($_.DirectoryName)\$($_.BaseName).params" -TemplatePath $_.FullName }
	Recursively create json parameter files for multiple json templates.
	Place json in the same folder with a template and add '*.params.json' to the file name.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Requirement :: PowerShell 3.0
	Shell       :: Tested on PowerShell 5.0
	Version 1.0 :: 31-Jan-2018 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2018/02/01/azure-json-parameter-files
#>
	
	[CmdletBinding(DefaultParameterSetName = 'FROMHASH')]
	[OutputType([System.IO.FileInfo])]
	[Alias("azjson")]
	Param (
		[Parameter(Mandatory = $false, ParameterSetName = 'FROMHASH')]
		[hashtable]$Params
		 ,
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'FROMTEMPLATE')]
		[ValidateScript({ Test-Path $_ -PathType 'Leaf' })]
		[string]$TemplatePath
		 ,
		[Parameter(Mandatory, Position = 0)]
		[ValidateScript({ Test-Path (Split-Path $_) -PathType 'Container' })]
		[string]$JsonPath
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		
		### Add .json extension if not exists ###
		$JsonPath += if ($JsonPath -inotmatch '\.json$') { '.json' }
	}
	Process
	{
		### Populate initial hash table either from user input [-Params] or from JSON template file [-TemplatePath] ###
		$ParamsHash = @{ }
		if ($PSCmdlet.ParameterSetName -eq 'FROMHASH')
		{
			$ParamsHash = $Params
		}
		else
		{
			$jsonTemplate = Get-Item $TemplatePath | Get-Content | ConvertFrom-Json
			$jsonTemplate.parameters | Get-Member -MemberType NoteProperty, Property | % { $ParamsHash.Add($_.Name, '') }
		}
		
		### Populate Level2 & Level3 hash tables ###
		$paramsL2 = @{ }
		if ($ParamsHash)
		{
			$ParamsHash.Keys.GetEnumerator() | % {
				$paramL3 = @{ }
				$paramL3.Add('value', $ParamsHash.$_)
				$paramsL2.Add($_, $paramL3)
			}
		}
		
		### High Level hash table ###
		$hashL1 = [ordered]@{
			'$schema' = 'https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#';
			'contentVersion' = '1.0.0.0';
			'parameters' = $paramsL2
		}
		
		### Convert High Level hash table to PSObject, then to Json and then export to a file ###
		[PSCustomObject]$hashL1 | ConvertTo-Json -Depth 3 | Out-File $JsonPath
		if ($?) { Get-Item $JsonPath } else { $null }
	}
	End { }
	
} #EndFunction New-AzParamsJson

Function Remove-AzObject
{
	
<#
.SYNOPSIS
	Interactively delete Azure object.
.DESCRIPTION
	This function allows interactively (from Menu list) to select and delete an Azure item.
.EXAMPLE
	PS C:\> Select-AzObject VM | Select-AzChildObject | Remove-AzObject
	Delete selected VM NIC.
.EXAMPLE
	PS C:\> Select-AzObject SA | Select-AzChildObject | Remove-AzObject -Confirm:$false -Verbose
	Delete selected blob or container with no confirmation.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.0
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 14-Feb-2018 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2018/02/14/azure-vhd-operations-powershell
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[OutputType([bool])]
	[Alias("Remove-AzItem", "xazob")]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Alias("AzureItem")]
		$AzureObject
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
	}
	Process
	{
		switch ($AzureObject)
		{
			### CONTAINER ###
			{ $_ -is [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer] }
			{
				$ObjectType = 'Blob Container'
				if ($_.CloudBlobContainer.Properties.LeaseStatus -eq 'Unlocked')
				{
					if ($PSCmdlet.ShouldProcess("Storage Account [$($_.Context.StorageAccountName)]", "Delete $ObjectType [$($_.Name)] and all its child blobs"))
					{
						$_.CloudBlobContainer.Delete()
						if ($?) { Write-Verbose "$FunctionName - The $ObjectType [$($_.Name)] deleted successfully"; $true } else { $false }
					}
				}
				else
				{
					Write-Error "The $ObjectType [$($AzureObject.Name)] is [$($AzureObject.CloudBlobContainer.Properties.LeaseState)] therefore it cannot be deleted"
				}
				Break
			}
			### BLOB ###
			{ $_ -is [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBlob] }
			{
				$ObjectType = 'Blob'
				if ($_.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked')
				{
					if ($PSCmdlet.ShouldProcess("Storage Account [$($_.Context.StorageAccountName)]", "Delete $ObjectType [$($_.Name)]"))
					{
						$_.ICloudBlob.Delete()
						if ($?) { Write-Verbose "$FunctionName - The $ObjectType [$($_.Name)] deleted successfully"; $true } else { $false }
					}
				}
				else
				{
					Write-Error "The $ObjectType [$($_.Name)] is [$($_.ICloudBlob.Properties.LeaseState)] therefore it cannot be deleted"
				}
				Break
			}
			### VIRTUAL NIC ###
			{ $_ -is [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface] }
			{
				$ObjectType = 'VM NIC'
				if ($_.VirtualMachine.Id -eq $null)
				{
					if ($PSCmdlet.ShouldProcess("Resource Group [$($_.ResourceGroupName)]", "Delete $ObjectType [$($_.Name)]"))
					{
						$_ | Remove-AzureRmNetworkInterface -Confirm:$false -Force
						if ($?) { Write-Verbose "$FunctionName - The $ObjectType [$($_.Name)] deleted successfully"; $true } else { $false }
					}
				}
				else
				{
					$ParentVm = [regex]::Match($_.VirtualMachine.Id, '.+/(.+)$').Groups[1].Value
					Write-Error "The $ObjectType [$($_.Name)] is linked to VM [$ParentVm] therefore it cannot be deleted"
				}
			}
			### UNSUPPORTED ###
			Default { Throw "Not supported object type" }
		}
	}
	End { }
	
} #EndFunction Remove-AzObject

Function Get-AzVmSize
{
	
<#
.SYNOPSIS
	Get Azure VMSizes that meet specified requirements.
.DESCRIPTION
	This function retrieves Azure VMSizes that meet specified requirements.
.PARAMETER Location
	Specifies Azure Location Name or object, returned by Select-AzLocation function.
.PARAMETER Profile
	Specifies workload profile for which a VMSize is optimized.
.PARAMETER Core
	Specifies minimum required vCPU count.
.PARAMETER MemoryGB
	Specifies minimum required Memory.
.PARAMETER DataDisk
	Specifies minimum required Data Disk count, supported by VMSize.
.EXAMPLE
	PS C:\> Get-AzVmSize -Location centralus -Profile Compute
.EXAMPLE
	PS C:\> Select-AzLocation | Get-AzVmSize
	Get all VMSizes available in the selected Azure Location.
.EXAMPLE
	PS C:\> Select-AzLocation | Get-AzVmSize Memory -Core 4 -DataDisk 16
	Get memory optimized VMSizes with at least four vCPU that
	support more than sixteen data disks in the selected Azure Location.
.EXAMPLE
	PS C:\> Get-AzureRmLocation | Get-AzVmSize Storage
	Get storage optimized VMSizes in all existing locations.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.0
	Platform    :: Tested on AzureRm 4.3.1
	Version 1.0 :: 15-Feb-2018 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2018/02/19/azure-vm-size-powershell
#>
	
	[CmdletBinding()]
	[Alias("azvms")]
	Param (
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		$Location
		 ,
		[Parameter(Mandatory = $false, Position = 0)]
		[ValidateSet('General', 'Compute', 'Memory', 'Storage', 'GPU', 'Powerful')]
		[string]$Profile
		 ,
		[Parameter(Mandatory = $false)]
		[Alias('Cores')]
		[uint16]$Core
		 ,
		[Parameter(Mandatory = $false)]
		[uint16]$MemoryGB
		 ,
		[Parameter(Mandatory = $false)]
		[Alias('DataDisks')]
		[uint16]$DataDisk
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$rgxVmSize = '^(?<Type>[a-zA-Z]+)_(?<Series>[A-Z]{1,2})(?<Number>\d+-{0,1}\d*)(?<SubSeries>[a-z]*)(?<Version>_v\d+.*|$)'
		$AzSizes = @()
	}
	Process
	{
		$LocationName = switch ($Location)
		{
			{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceProviderLocation] } { $Location.DisplayName; Break }
			{ $_ -is [string] } { $Location }
			Default { Throw "Not supported location data type" }
		}
		
		$AzSizes = Get-AzureRmVMSize -Location $LocationName | % {
			$ParseVmSize = [regex]::Match($_.Name, $rgxVmSize)
			$Series = $ParseVmSize.Groups['Series'].Value
			$SubSeries = $ParseVmSize.Groups['SubSeries'].Value
			$v = [regex]::Match($ParseVmSize.Groups['Version'].Value, 'v\d+').Value
			$Number = $ParseVmSize.Groups['Number'].Value
			$Precision = if ($_.MemoryInMB -lt 10240) { 2 } else { 0 }
			
			$AzSize = [AzVmSize] @{
				Location = $LocationName
				VMSize = $_.Name
				Cores = $_.NumberOfCores
				MemoryGiB = [Math]::Round($_.MemoryInMB/1024, $Precision)
				OSDiskGiB = [Math]::Round($_.OSDiskSizeInMB/1024, 0)
				DataDisks = $_.MaxDataDiskCount
				Type = $ParseVmSize.Groups['Type'].Value
				Family = "$Series$SubSeries$v"
				Series = $Series
				Number = $Number
				SubSeries = $SubSeries
				Version = $v
			}
			
			### Filter out by VM Size profile ###
			if ($PSBoundParameters.ContainsKey('Profile'))
			{
				$SortBy = @('Cores', 'MemoryGiB')
				
				switch ($Profile)
				{
					'General'
					{
						switch ($AzSize)
						{
							{ 'B', 'D' -contains $_.Series } { $_ }
							{ (0 .. 7 | % { "A$_" }) -contains "$($_.Series)$Number" } { $_ }
							{ "$($_.Series)$($_.Version)" -eq 'Av2' } { $_ }
						}
						$SortBy = @('Type', 'Cores', 'MemoryGiB')
						Break
					}
					'Compute'
					{
						if ($AzSize.Series -eq 'F') { $AzSize }
						Break
					}
					'Memory'
					{
						switch ($AzSize)
						{
							{ 'D', 'G', 'GS', 'M' -contains $_.Series } { $_ }
							{ 'Ev3', 'Esv3' -contains "$($_.Series)$($_.SubSeries)$($_.Version)" } { $_ }
						}
						$SortBy = @('MemoryGiB', 'Series')
						Break
					}
					'Storage'
					{
						if ("$($AzSize.Series)$($AzSize.SubSeries)" -eq 'Ls') { $AzSize }
						Break
					}
					'GPU'
					{
						if ('NC', 'ND', 'NV' -contains "$($AzSize.Series)$($AzSize.SubSeries)") { $AzSize }
						Break
					}
					'Powerful'
					{
						switch ($AzSize)
						{
							{ (8 .. 11 | % { "A$_" }) -contains "$($_.Series)$Number" } { $_ }
							{ "$($_.Series)" -eq 'H' } { $_ }
						}
					}
				}
			}
			else
			{
				$AzSize
				$SortBy = @('Type', 'Series', 'SubSeries')
			}
		}
		
		### Filter out by Virtual hardware requirements ###
		$AzSizes = if ($PSBoundParameters.ContainsKey('Core')) { $AzSizes.Where{ $_.Cores -ge $Core } } else { $AzSizes }
		$AzSizes = if ($PSBoundParameters.ContainsKey('MemoryGB')) { $AzSizes.Where{ $_.MemoryGiB -ge $MemoryGB } } else { $AzSizes }
		$AzSizes = if ($PSBoundParameters.ContainsKey('DataDisk')) { $AzSizes.Where{ $_.DataDisks -ge $DataDisk } } else { $AzSizes }
		
		return $AzSizes | Sort-Object $SortBy
	}
	End { }
	
} #EndFunction Get-AzVmSize
