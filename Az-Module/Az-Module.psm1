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
	Version 1.0 :: 20-Jun-2016 :: [Release] :: Filter
	Version 1.1 :: 10-Jan-2017 :: [Change]  :: Warnings suppressed
	Version 2.0 :: 27-Jun-2017 :: [Release] :: Rewritten from Filter to Function
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
	Version 1.0 :: 20-Jun-2016 :: [Release] :: Filter
	Version 2.0 :: 27-Jun-2017 :: [Release] :: Rewritten from Filter to Function
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
	Version 1.0 :: 27-Jun-2016 :: [Release]
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
	Version 1.0 :: 14-Jul-2016 :: [Release]
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
			### If a change was made less than 24 hours ago, but it was yesterday return one day and not zero ###
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
			If ($VmVhd -notcontains $Object.FullPath) {$Object}
		}
	}
	End
	{
		
	}

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
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup -VMName 'azvm1' |Get-AzVmDisk
	Get all Virtual Disks for a given VM.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |sort Name |Get-AzVmDisk |select * -exclude Path |ft -au
	Get all Virtual Disks for all VM in specific ResourceGroup.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup |Get-AzVmDisk -DiskType DataDisk
	Get only DataDisks for all VM in specific ResourceGroup.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0 | AzureRM.Compute v.2.8.0
	Version 1.0 :: 31-Aug-2016 :: [Release]
	Version 1.1 :: 26-Jun-2017 :: [Change] :: Code optimization
.LINK
	https://ps1code.com/2017/07/05/azure-vm-add-data-disk
#>

	[CmdletBinding()]
	[OutputType([PSCustomObject])]
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
			
			[pscustomobject]@{
				VM = $VM.Name
				VMSize = $VM.HardwareProfile.VmSize
				DiskName = $VmOsDisk.Name
				DiskType = 'OSDisk'
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
			foreach ($DataDisk in $VmDataDisks)
			{
				$DataDiskUri = $DataDisk.Vhd.Uri
				$DataDiskUriX = [regex]::Match($DataDiskUri, $rgxUri)
				
				[pscustomobject] @{
					VM = $VM.Name
					VMSize = $VM.HardwareProfile.VmSize
					DiskName = $DataDisk.Name
					DiskType = 'DataDisk'
					Lun = $DataDisk.Lun
					StorageAccount = $DataDiskUriX.Groups['StorageAccount'].Value
					Container = $DataDiskUriX.Groups['Container'].Value
					Vhd = $DataDiskUriX.Groups['Vhd'].Value
					Path = $DataDiskUri
					SizeGB = $DataDisk.DiskSizeGB
					Cache = $DataDisk.Caching
					Created = $DataDisk.CreateOption
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
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup -VMName 'azvm1' |New-AzVmDisk |Format-Table -AutoSize
	Add a new data disk with all default options.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup -VMName 'azvm1' |New-AzVmDisk -StorageAccount Prompt
	Give an option to pick a StorageAccount from a menu.
.EXAMPLE
	PS C:\> Get-AzureRmVM -ResourceGroupName $AzResourceGroup -VMName 'azvm1' |New-AzVmDisk -SizeGB 10 -Caching SqlLog
	Add 10 GiB disk with caching mode recommended by Microsoft for SQL logs.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Get-AzVmDisk function (part of this Module)
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0 | AzureRM.Compute v.2.8.0 | AzureRM.Storage v.2.7.0
	Version 1.0 :: 31-Aug-2016 :: [Release]
	Version 1.1 :: 26-Jun-2017 :: [Change] :: Code optimization
.LINK
	https://ps1code.com/2017/07/05/azure-vm-add-data-disk
#>
	
	[CmdletBinding()]
	[Alias("Add-AzVmDisk")]
	[OutputType([PSCustomObject])]
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
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateRange(10, 1023)]
		[uint16]$SizeGB = 100
		 ,
		[Parameter(Mandatory = $false, Position = 2)]
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
			Get-AzureRmVm -ResourceGroupName $ResourceGroup -VMName $VM.Name | Get-AzVmDisk | select * -exclude Path
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
	Version 1.0 :: 04-Jan-2017 :: [Release]
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
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 26-Jun-2017 :: [Release]
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
		return (menu -Menu (Get-AzureRmResourceGroup | sort $DefaultProperty) `
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
	PS C:\> Select-AzResourceGroup |Select-AzObject -ObjectType AS -NameOnly
.EXAMPLE
	PS C:\> Select-AzObject -ObjectType VirtualNetwork -ResourceGroup (Select-AzResourceGroup) -NameOnly -Verbose
.EXAMPLE
	PS C:\> Select-AzObject -ObjectType VM |Get-AzVmDisk
.EXAMPLE
	PS C:\> Select-AzObject VNET |select -expand DhcpOptions
.EXAMPLE
	PS C:\> Select-AzObject VM |Start-AzureRmVM
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module, Write-Menu function (part of this Module)
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 26-Jun-2017 :: [Release]
.LINK
	https://ps1code.com/2017/06/29/azure-vm-tags
#>
	
	[CmdletBinding()]
	[Alias("sazo")]
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
				if (!$PSBoundParameters.ContainsKey('ResourceGroup')) {Throw "You have to specify ResourceGroup name"}
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
		### Show menu ###
		$AzObject = if ($Menu)
		{
			menu -Menu ($Menu | sort $DefaultProperty) `
				 -PropertyToShow $DefaultProperty `
				 -Header $menuHeader `
				 -Prompt "Select $ObjectType" `
				 -HeaderColor $menuHeaderC -TextColor $menuTextC -Shift $menuShift
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
	Get Azure Subnets.
.DESCRIPTION
	This function retrieves Azure Subnets.
.PARAMETER VirtualNetwork
	Specifies Azure VirtualNetwork object(s), returned by Get-AzureRmVirtualNetwork cmdlet.
.EXAMPLE
	PS C:\> Get-AzureRmVirtualNetwork | Get-AzSubnet
.EXAMPLE
	PS C:\> Select-AzObject VirtualNetwork | Get-AzSubnet
.EXAMPLE
	PS C:\> Get-AzureRmVirtualNetwork | Get-AzSubnet | ? {$_.Address -like '172.23.*'}
.EXAMPLE
	PS C:\> Get-AzureRmVirtualNetwork | Get-AzSubnet | ? {$_.Subnet -match '^dmz'}
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRM PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0 | AzureRM.Network v.3.6.0
	Version 1.0 :: 26-Jun-2017 :: [Release]
.LINK
	https://ps1code.com/category/powershell/azure/az-module/
#>
	
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
	)
	
	Begin
	{
		
	}
	Process
	{
		$Subnets = $VirtualNetwork | select -expand Subnets |
		select Name, AddressPrefix | sort AddressPrefix
		
		foreach ($Subnet in $Subnets)
		{
			[pscustomobject] @{
				Network = $VirtualNetwork.Name
				Subnet = $Subnet.Name
				Address = $Subnet.AddressPrefix
			}	
		}
	}
	End
	{
		
	}
	
} #EndFunction Get-AzSubnet
