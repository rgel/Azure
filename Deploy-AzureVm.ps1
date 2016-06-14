#requires -Version 4.0
#requires -Modules 'AzureRM.Storage','AzureRM.Resources','AzureRM.Compute','AzureRM.Network'

<#
.SYNOPSIS
	Deploy Azure VM.
.DESCRIPTION
	This script automate Azure VM deployment process.
.PARAMETER Environment
	This parameter affects the choice of Json file and VM name prefix.
.PARAMETER VMCount
	Number of VM to deploy.
.PARAMETER Guest
	VM Image choice will be based on this parameter.
.PARAMETER NoFilter
	If specified, doesn't filter out ResourceGroups, StorageAccounts, VM Sizes and VM Images.
.PARAMETER Project
	Tag Value for Tag Key 'Project'.
.PARAMETER Notes
	Tag Value for Tag Key 'Notes'.
.PARAMETER FirstStaticIP
	First VM static IP address to generate IP range.
.EXAMPLE
	PS C:\> cd C:\scripts
	PS C:\scripts> .\Deploy-AzureVm.ps1 -Notes DC1
	Deploy single VM with all default options.
.EXAMPLE
	PS C:\> .\Deploy-AzureVm.ps1 -VMCount 3 -NoFilter -Environment DEV -Notes DNS -WhatIf
	Simulate deployment process.
.EXAMPLE
	PS C:\> .\Deploy-AzureVm.ps1 -Guest RedHat -Project SAP
.EXAMPLE
	PS C:\> .\Deploy-AzureVm.ps1 -Environment TEST -Guest WindowsSql -Project IFN -Notes SQL
.NOTES
	Author       ::	Roman Gelman.
	Dependencies ::	Azure PS Modules.
	Version 1.0  ::	14-Jun-2016  :: Release.
.LINK
	https://goo.gl/vAxH2a
#>

[CmdletBinding()]

Param (

	[Parameter(Mandatory=$false,Position=0)]
		[ValidateSet("PROD","DEV","TEST","DMZ","LABS","MSDN")]
		[Alias("Domain","Subscription")]
	[string]$Environment = "MSDN"
	,
	[Parameter(Mandatory=$false,Position=1)]
		[ValidateRange(1,10)]
		[Alias("VMQuantity")]
	[uint16]$VMCount = 1
	,
	[Parameter(Mandatory=$false,Position=2)]
		[ValidateSet("Windows","WindowsSql","RedHat")]
		[Alias("VMGuest")]
	[string]$Guest = 'Windows'
	,
	[Parameter(Mandatory=$false,Position=3)]
		[Alias("DisableFilter")]
	[switch]$NoFilter
	,
	### JSON :: [parameters('vmTag')] ###
	[Parameter(Mandatory=$false,Position=4)]
		[ValidateNotNullorEmpty()]
	[string]$Project = 'Infra'
	,
	### JSON :: [parameters('vmNotes')] ###
	[Parameter(Mandatory=$false,Position=5)]
		[ValidateNotNullorEmpty()]
		[Alias("VMNotes")]
	[string]$Notes = '_xxx_'
	,
	[Parameter(Mandatory=$false,Position=6)]
		[ValidateNotNullorEmpty()]
	[string]$VMName
	,
	[Parameter(Mandatory=$false,Position=7)]
		[Alias("HA")]
	[switch]$HighAvailable
	,
	[Parameter(Mandatory=$false,Position=8)]
	[switch]$WhatIf
)

Begin {

	### Helper functions ###
	Function Write-Menu {

	<#
	.SYNOPSIS
		Display custom menu in the PowerShell console.
	.DESCRIPTION
		This cmdlet writes numbered and colored menues in the PS console window
		and returns the choiced entry.
	.PARAMETER Menu
		Menu entries.
	.PARAMETER PropertyToShow
		If your menu entries are objects and not the strings
		this is property to show as entry.
	.PARAMETER Prompt
		User prompt at the end of the menu.
	.PARAMETER Header
		Menu title (optional).
	.PARAMETER Shift
		Quantity of <TAB> keys to shift the menu right.
	.PARAMETER TextColor
		Menu text color.
	.PARAMETER HeaderColor
		Menu title color.
	.PARAMETER AddExit
		Add 'Exit' as very last entry.
	.EXAMPLE
		PS C:\> Write-Menu -Menu "Open","Close","Save" -AddExit -Shift 1
		Simple manual menu with 'Exit' entry and 'one-tab' shift.
	.EXAMPLE
		PS C:\> Write-Menu -Menu (Get-ChildItem 'C:\Windows\') -Header "`t`t-- File list --`n" -Prompt 'Select any file'
		Folder content dynamic menu with the header and custom prompt.
	.EXAMPLE
		PS C:\> Write-Menu -Menu (Get-Service) -Header ":: Services list ::`n" -Prompt 'Select any service' -PropertyToShow DisplayName
		Display local services menu with custom property 'DisplayName'.
	.EXAMPLE
	      PS C:\> Write-Menu -Menu (Get-Process |select *) -PropertyToShow ProcessName |fl
	      Display full info about choicen process.
	.INPUTS
		[string[]] [pscustomobject[]] or any!!! type of array.
	.OUTPUTS
		[The same type as input object] Single menu entry.
	.NOTES
		Author       ::	Roman Gelman.
		Version 1.0  ::	21-Apr-2016  :: Release.
	.LINK
		http://goo.gl/MgLch1
	#>

	[CmdletBinding()]

	Param (

		[Parameter(Mandatory,Position=0)]
			[Alias("MenuEntry","List")]
		$Menu
		,
		[Parameter(Mandatory=$false,Position=1)]
		[string]$PropertyToShow = 'Name'
		,
		[Parameter(Mandatory=$false,Position=2)]
			[ValidateNotNullorEmpty()]
		[string]$Prompt = 'Pick a choice'
		,
		[Parameter(Mandatory=$false,Position=3)]
			[Alias("MenuHeader")]
		[string]$Header = ''
		,
		[Parameter(Mandatory=$false,Position=4)]
			[ValidateRange(0,5)]
			[Alias("Tab","MenuShift")]
		[int]$Shift = 0
		,
		#[Enum]::GetValues([System.ConsoleColor])
		[Parameter(Mandatory=$false,Position=5)]
			[ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta",
			"DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
			[Alias("Color","MenuColor")]
		[string]$TextColor = 'White'
		,
		[Parameter(Mandatory=$false,Position=6)]
			[ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta",
			"DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
		[string]$HeaderColor = 'Yellow'
		,
		[Parameter(Mandatory=$false,Position=7)]
			[ValidateNotNullorEmpty()]
			[Alias("Exit","AllowExit")]
		[switch]$AddExit
	)

	Begin {

		$ErrorActionPreference = 'Stop'
		If ($Menu -isnot 'array') {Throw "The menu entries must be array or objects"}
		If ($AddExit) {$MaxLength=8} Else {$MaxLength=9}
		If ($Menu.Length -gt $MaxLength) {$AddZero=$true} Else {$AddZero=$false}
		[hashtable]$htMenu = @{}
	}

	Process {

		### Write menu header ###
		If ($Header -ne '') {Write-Host $Header -ForegroundColor $HeaderColor}
		
		### Create shift prefix ###
		If ($Shift -gt 0) {$Prefix = [string]"`t"*$Shift}
		
		### Build menu hash table ###
		For ($i=1; $i -le $Menu.Length; $i++) {
			If ($AddZero) {
				If ($AddExit) {$lz = ([string]($Menu.Length+1)).Length - ([string]$i).Length}
				Else          {$lz = ([string]$Menu.Length).Length - ([string]$i).Length}
				$Key = "0"*$lz + "$i"
			} Else {$Key = "$i"}
			$htMenu.Add($Key,$Menu[$i-1])
			If ($Menu[$i] -isnot 'string' -and ($Menu[$i-1].$PropertyToShow)) {
				Write-Host "$Prefix[$Key] $($Menu[$i-1].$PropertyToShow)" -ForegroundColor $TextColor
			} Else {Write-Host "$Prefix[$Key] $($Menu[$i-1])" -ForegroundColor $TextColor}
		}
		If ($AddExit) {
			[string]$Key = $Menu.Length+1
			$htMenu.Add($Key,"Exit")
			Write-Host "$Prefix[$Key] Exit" -ForegroundColor $TextColor
		}
		
		### Pick a choice ###
		Do {
			$Choice = Read-Host -Prompt $Prompt
			If ($AddZero) {
				If ($AddExit) {$lz = ([string]($Menu.Length+1)).Length - $Choice.Length}
				Else          {$lz = ([string]$Menu.Length).Length - $Choice.Length}
				If ($lz -gt 0) {$KeyChoice = "0"*$lz + "$Choice"} Else {$KeyChoice = $Choice}
			} Else {$KeyChoice = $Choice}
		} Until ($htMenu.ContainsKey($KeyChoice))
	}

	End {return $htMenu.get_Item($KeyChoice)}

	} #EndFunction Write-Menu
	Function New-IPRange ($FirstIP, $LastIP) {

		Try   {$ip1 = ([ipaddress]$FirstIP).GetAddressBytes()}
		Catch {Throw "'$FirstIP' is not valid IPv4 address"}
		[array]::Reverse($ip1)
		$ip1 = ([ipaddress]($ip1 -join '.')).Address

		Try   {$ip2 = ([ipaddress]$LastIP).GetAddressBytes()}
		Catch {Throw "'$LastIP' is not valid IPv4 address"}
		[array]::Reverse($ip2)
		$ip2 = ([ipaddress]($ip2 -join '.')).Address

		For ($x=$ip1; $x -le $ip2; $x++) {
			$ip = ([ipaddress]$x).GetAddressBytes()
			[array]::Reverse($ip)
			$ip -join '.'
		}
		
	} #EndFunction New-IPRange
	
	### Validation/Preparation ###
	$ErrorActionPreference = 'Stop'
	$WarningPreference = 'SilentlyContinue'
	$OSFamily = [regex]::Match($Guest, '^(Windows|RedHat)').Value
	$rgxHostName = ',|~|:|!|@|\#|\$|%|\^|&|`|\(|\)|\{|\}|_|\s|\\|/|\*|\?|"|<|>|\|'
	
	If ($Environment -eq "MSDN") {$rgxEnv = 'visual\sstudio'; $Stages = 7} Else {$rgxEnv = $Environment; $Stages = 8}
	If ($HighAvailable) {$Stages = $Stages+1}

	If ($PSBoundParameters.ContainsKey('VMName') -and $VMName -match $rgxHostName) {
		Throw "-VMName parameter contains not allowed characters"
	}
	
	### JSON :: [parameters('adminPassword')] ###
	$SecureFile = "$PSScriptRoot\secure.cred"
	If (Test-Path $SecureFile -PathType Leaf) {$AdminPwd = Get-Content $SecureFile |ConvertTo-SecureString} Else {Throw "No secure file"}
	
	### New-AzureRmResourceGroupDeployment :: -TemplateFile ###
	$Org = 'Iec'
	$JsonFile = "$PSScriptRoot\$Org" + "_$Environment" + "_$OSFamily"
	If ($HighAvailable) {$JsonFile = $JsonFile + "_AS"}
	$JsonFile = $JsonFile + ".json"
	If (!(Test-Path $JsonFile -PathType Leaf)) {Throw "'$JsonFile' json file doesn't exists"}
	
	### Select subscription context ###
	Try
	{
		If ($NoFilter) {$setSubsc = @((Get-AzureRmSubscription |? {$_.State -eq 'enabled'}).SubscriptionName |sort)}
		Else           {$setSubsc = @((Get-AzureRmSubscription |? {$_.State -eq 'enabled' -and $_.SubscriptionName -match $rgxEnv}).SubscriptionName |sort)}
	}
	Catch
	{
		Login-AzureRmAccount
		If ($NoFilter) {$setSubsc = @((Get-AzureRmSubscription |? {$_.State -eq 'enabled'}).SubscriptionName |sort)}
		Else           {$setSubsc = @((Get-AzureRmSubscription |? {$_.State -eq 'enabled' -and $_.SubscriptionName -match $rgxEnv}).SubscriptionName |sort)}
	}
	Finally
	{
		$Stage = 1
		If     (!$setSubsc)             {Throw "You don't have any enabled subscriptions that match '$Environment' environment"}
		ElseIf ($setSubsc.Length -eq 0) {Throw "You don't have any enabled subscriptions"}
		ElseIf ($setSubsc.Length -eq 1) {$Subscription = $setSubsc[0]; Write-Host "[Stage $Stage..$Stages] The sole Subscription '$Subscription' was choicen by default" -ForegroundColor Yellow}
		Else   {$Subscription = Write-Menu -Menu $setSubsc -Shift 1 -Prompt "Choice Subscription" -Header "[Stage $Stage..$Stages] Available Subscriptions:"}
		Set-AzureRmContext -SubscriptionName $Subscription |Out-Null
	}
	
	### New-AzureRmResourceGroupDeployment :: -ResourceGroupName ###
	$Stage++
	$setResGr = @((Get-AzureRmResourceGroup).ResourceGroupName |sort)
	
	If     ($setResGr.Length -eq 0) {Throw "Subscription '$Subscription' doesn't have any ResourceGroup"}
	ElseIf ($setResGr.Length -eq 1) {$ResourceGroup = $setResGr[0]; Write-Host "[Stage $Stage..$Stages] The sole ResourceGroup '$ResourceGroup' was choicen by default" -ForegroundColor Yellow}
	Else   {$ResourceGroup = Write-Menu -Menu $setResGr -Shift 1 -Prompt "Choice ResourceGroup" -Header "[Stage $Stage..$Stages] Available ResourceGroups:"}
	
	### JSON :: [parameters('storageAccountName')] ###
	$Stage++
	$rgxDiagStor = 'diag'
	$setStorA = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup |? {$_.StorageAccountName -notmatch $rgxDiagStor} |sort StorageAccountName
	
	If     (!$setStorA)             {Throw "ResourceGroup '$ResourceGroup' doesn't have any StorageAccounts except diagnostic"}
	ElseIf ($setStorA.Length -eq 1) {$StorageAccount = $setStorA[0]; Write-Host "[Stage $Stage..$Stages] The sole StorageAccount '$($StorageAccount.StorageAccountName)' was choicen by default" -ForegroundColor Yellow}
	Else   {$StorageAccount = Write-Menu -Menu $setStorA -Shift 1 -Prompt "Choice StorageAccount" -Header "[Stage $Stage..$Stages] Available StorageAccounts:" -PropertyToShow StorageAccountName}
	
	### Choice ResourceGroup that contains Network objects (customer specific) ###
	If ($Environment -eq 'MSDN') {$VnetResourceGroup = $ResourceGroup} Else {$VnetResourceGroup = "$Environment" + "_infra-rg"}
	
	### JSON :: [parameters('virtualNetworkName')] ###
	$Stage++
	$setVirNw = @((Get-AzureRmVirtualNetwork -ResourceGroupName $VnetResourceGroup).Name |sort)
	
	If     ($setVirNw.Length -eq 0) {Throw "ResourceGroup '$VnetResourceGroup' doesn't have any VirtualNetworks"}
	ElseIf ($setVirNw.Length -eq 1) {$VirtualNetwork = $setVirNw[0]; Write-Host "[Stage $Stage..$Stages] The sole VirtualNetwork '$VirtualNetwork' was choicen by default" -ForegroundColor Yellow}
	Else   {$VirtualNetwork = Write-Menu -Menu $setVirNw -Shift 1 -Prompt "Choice VirtualNetwork" -Header "[Stage $Stage..$Stages] Available VirtualNetworks:"}
	
	### JSON :: [parameters('subnetName')] ###
	$Stage++
	$setSubnt = Get-AzureRmVirtualNetwork -Name $VirtualNetwork -ResourceGroupName $VnetResourceGroup |select -expand Subnets |select Name,AddressPrefix |sort Name
	
	If     ($setSubnt.Length -eq 0) {Throw "VirtualNetwork '$VirtualNetwork' doesn't have any Subnets"}
	ElseIf ($setSubnt.Length -eq 1) {$Subnet = $setSubnt[0]; Write-Host "[Stage $Stage..$Stages] The sole Subnet '$($Subnet.Name)' was choicen by default" -ForegroundColor Yellow}
	Else   {$Subnet = Write-Menu -Menu $setSubnt -Shift 1 -Prompt "Choice Subnet" -Header "[Stage $Stage..$Stages] Available Subnets:" -PropertyToShow Name}
	
	### JSON :: [parameters('vmnicStaticIP')] ###
	If ($Environment -ne 'MSDN') {
		$Stage++
		$SubnetAddressPrefix = $Subnet.AddressPrefix
		$rgxSubnet = [regex]::Match($SubnetAddressPrefix, '^(.+)/(\d{1,2})$')
		[ipaddress]$SubnetAddress = $rgxSubnet.Groups[1].Value
		$SubnetMask = $rgxSubnet.Groups[2].Value
		$Octats = $SubnetMask/8 -as [int]
		$SubnetAddressBytes = $SubnetAddress.GetAddressBytes()
		$rgxIP = '^' + ($SubnetAddressBytes[0..($Octats-1)] -join '.') + '.'
		Write-Host "[Stage $Stage..$Stages] Available IP Range [$SubnetAddress]:" -ForegroundColor Yellow
		Do {Try {[ipaddress]$FirstStaticIP = Read-Host -Prompt "Choice First IP Address"} Catch {}} Until ($FirstStaticIP.ToString() -match $rgxIP -and $?)

		If (15..254 -notcontains $FirstStaticIP.GetAddressBytes()[-1])    {Throw "The last octat of the first IP address must be in the range [15..254]"}
		If (($FirstStaticIP.GetAddressBytes()[-1] + $VMCount -1) -gt 254) {Throw "Not enougth IP addresses in the subnet for $VMCount VM, decrease the first IP address"}
		
		$LastStaticIP = $FirstStaticIP -replace ('\d{1,3}$', ($FirstStaticIP.GetAddressBytes()[-1] + $VMCount -1))
		$IPRange = New-IPRange -FirstIP $FirstStaticIP -LastIP $LastStaticIP
		If ($IPRange -is [string]) {$IPRange = $IPRange -as [array]}
	}
	
	### JSON :: [parameters('vmSize')] ###
	$Stage++
	$rgxVMSize = '_(D|G)S'
	If ($StorageAccount.AccountType -notmatch 'premium') {$setVMSiz = (Get-AzureRmVMSize -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location)).Name |sort}
	Else {$setVMSiz = (Get-AzureRmVMSize -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location) |? {$_.Name -match $rgxVMSize}).Name |sort}
	$VMSize = Write-Menu -Menu $setVMSiz -Shift 1 -Prompt "Choice VM Size" -Header "[Stage $Stage..$Stages] Available VM Sizes:"
	
	### Image parameters                       ###
	### JSON :: [parameters('imagePublisher')] ###
	### JSON :: [parameters('imageOffer')]     ###
	### JSON :: [parameters('imageSku')]       ###
	$Stage++
	$rgxVmSku = 'preview'
	Switch -exact ($Guest) {
		'Windows'    {$skuPublisher = 'MicrosoftWindowsServer'; $skuOffer = 'WindowsServer';       Break}
		'WindowsSql' {$skuPublisher = 'MicrosoftSQLServer';     $skuOffer = 'SQL2012SP2-WS2012R2'; Break}
		'RedHat'     {$skuPublisher = 'RedHat';                 $skuOffer = 'RHEL'}
	}
	If ($NoFilter) {$setVMSku = (Get-AzureRmVMImageSku -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location) -Offer $skuOffer -PublisherName $skuPublisher).Skus |sort}
	Else           {$setVMSku = (Get-AzureRmVMImageSku -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location) -Offer $skuOffer -PublisherName $skuPublisher |? {$_.Skus -notmatch $rgxVmSku}).Skus |sort}
	$VMSku = Write-Menu -Menu $setVMSku -Shift 1 -Prompt "Choice VM Image" -Header "[Stage $Stage..$Stages] Available VM Images:"
	
	### JSON :: [parameters('avSet')] ###
	If ($HighAvailable) {
		$Stage++
		$setAvSet = @((Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroup).Name |sort)
		If     ($setAvSet.Length -eq 0) {Throw "ResourceGroup '$ResourceGroup' doesn't have any Availability Sets"}
		ElseIf ($setAvSet.Length -eq 1) {$AvailabilitySet = $setAvSet[0]; Write-Host "[Stage $Stage..$Stages] The sole Availability Set '$AvailabilitySet' was choicen by default" -ForegroundColor Yellow}
		Else   {$AvailabilitySet = Write-Menu -Menu $setAvSet -Shift 1 -Prompt "Choice Availability Set" -Header "[Stage $Stage..$Stages] Available Availability Sets:"}
	}
	
	### JSON :: [parameters('vmName')] ###
	$ExistVM = $VMIndex = $FreeIndex = $VM = @()
	
	If ($PSBoundParameters.ContainsKey('VMName')) {
		$rgxVMPrefix = $VMName
		$ExistVM = Get-AzureRmVM -ResourceGroupName $ResourceGroup |select Name |? {$_.Name -match "^$rgxVMPrefix"} |sort Name
	}
	Else {
		Switch -exact ($OSFamily) {
			'Windows' {$rgxVMPrefix = 'wsrv'}
			'RedHat'  {$rgxVMPrefix = 'lnx'}
		}
		$ExistVM = Get-AzureRmVM -ResourceGroupName $ResourceGroup |select Name |? {$_.Name -match "^$rgxVMPrefix\d{4}$"} |sort Name
	}
	
	
	If ($ExistVM) {Foreach ($one in $ExistVM) {$VMIndex += $one.Name.TrimStart($rgxVMPrefix)}}
	Else {
		### Create very first VM index due to the naming convention ###
		If ($PSBoundParameters.ContainsKey('VMName')) {
			$VMIndex = @('0')
		}
		Else {
			Switch -exact ($Environment) {
				'PROD' {$VMIndex = @('1010'); Break}
				'TEST' {$VMIndex = @('2010'); Break}
				'DEV'  {$VMIndex = @('3010'); Break}
				'DMZ'  {$VMIndex = @('4010'); Break}
				'LABS' {$VMIndex = @('5010'); Break}
				'MSDN' {$VMIndex = @('6010'); Break}
			}
		}
	}
	<#
	### Generate VM Name :: single VM ###
	For ($i=1; $i -le $VMIndex.Length-1; $i++) {
		If ($VMIndex[$i] - $VMIndex[$i-1] -ne 1) {$FreeIndex = [int]$VMIndex[$i-1] + 1}
	}
	If (!$FreeIndex) {$FreeIndex = [int]$VMIndex[-1] + 1}
	$VM = "$rgxVMPrefix$FreeIndex"
	#>
	
	### Generate VM Name :: Multiple VM ###
	For ($i=1; $i -le $VMIndex.Length-1; $i++) {If (([int]$VMIndex[$i]-[int]$VMIndex[$i-1]) -gt 1) {For ($k=1; $k -lt ([int]$VMIndex[$i]-[int]$VMIndex[$i-1]); $k++) {$FreeIndex += [string]([int]$VMIndex[$i-1] + $k)}}}
	$FreeIndexCount = $FreeIndex.Length
	If ($FreeIndexCount -lt $VMCount) {For ($j=1; $j -le ($VMCount-$FreeIndexCount); $j++) {$FreeIndex += [string]([int]$VMIndex[-1] + $j)}} Else {$FreeIndex = $FreeIndex[0..($VMCount-1)]}
	Foreach ($index in $FreeIndex) {$VM += "$rgxVMPrefix$index"}

}

Process {

	For ($d=0; $d -le $VM.Length-1; $d++) {
	
		If ($PSBoundParameters.ContainsKey('WhatIf')) {
			Write-Host "[$($d+1)] Deploy [$VMSku][$VMSize] $Guest Azure VM [$($VM[$d])] in ResourceGroup [$ResourceGroup] on StorageAccount [$($StorageAccount.StorageAccountName)]"
			#"[$($d+1)] $($VM[$d]) $($IPRange[$d])"
		}
		Else {
			Write-Progress -Activity "Deploying [$VMSku] $Guest Azure VM ..." -Status "[$VMSize] VM $($d+1) from $($VM.Length)" -CurrentOperation "VM [$($VM[$d])]" -PercentComplete ($d/$VM.Length*100)
			
			### NON-MSDN deployment :: static IP ###			
			If ($Environment -ne 'MSDN') {
				### AvailabilitySet VM ###
				If ($AvailabilitySet) {
					$DeployJob = New-AzureRmResourceGroupDeployment -ea SilentlyContinue -ResourceGroupName $ResourceGroup `
					-TemplateFile $JsonFile -adminPassword $AdminPwd -vmName $VM[$d] `
					-storageAccountName "$($StorageAccount.StorageAccountName)" `
					-virtualNetworkName $VirtualNetwork -subnetName "$($Subnet.Name)" `
					-vmSize $VMSize -imagePublisher $skuPublisher -imageOffer $skuOffer -imageSku $VMSku `
					-vmTag $Project -vmNotes $Notes -vmnicStaticIP $IPRange[$d] `
					-avSet $AvailabilitySet
				}
				### Standalone VM ###
				Else {
					$DeployJob = New-AzureRmResourceGroupDeployment -ea SilentlyContinue -ResourceGroupName $ResourceGroup `
					-TemplateFile $JsonFile -adminPassword $AdminPwd -vmName $VM[$d] `
					-storageAccountName "$($StorageAccount.StorageAccountName)" `
					-virtualNetworkName $VirtualNetwork -subnetName "$($Subnet.Name)" `
					-vmSize $VMSize -imagePublisher $skuPublisher -imageOffer $skuOffer -imageSku $VMSku `
					-vmTag $Project -vmNotes $Notes -vmnicStaticIP $IPRange[$d]
				}
			}
			### MSDN deployment :: dynamic IP ###
			Else {
				### AvailabilitySet VM ###
				If ($AvailabilitySet) {
					$DeployJob = New-AzureRmResourceGroupDeployment -ea SilentlyContinue -ResourceGroupName $ResourceGroup `
					-TemplateFile $JsonFile -adminPassword $AdminPwd -vmName $VM[$d] `
					-storageAccountName "$($StorageAccount.StorageAccountName)" `
					-virtualNetworkName $VirtualNetwork -subnetName "$($Subnet.Name)" `
					-vmSize $VMSize -imagePublisher $skuPublisher -imageOffer $skuOffer -imageSku $VMSku `
					-vmTag $Project -vmNotes $Notes `
					-avSet $AvailabilitySet
				}
				### Standalone VM ###
				Else {
					$DeployJob = New-AzureRmResourceGroupDeployment -ea SilentlyContinue -ResourceGroupName $ResourceGroup `
					-TemplateFile $JsonFile -adminPassword $AdminPwd -vmName $VM[$d] `
					-storageAccountName "$($StorageAccount.StorageAccountName)" `
					-virtualNetworkName $VirtualNetwork -subnetName "$($Subnet.Name)" `
					-vmSize $VMSize -imagePublisher $skuPublisher -imageOffer $skuOffer -imageSku $VMSku `
					-vmTag $Project -vmNotes $Notes
				}
			}
			
			If ($DeployJob.ProvisioningState -eq 'Succeeded') {
				$DeployVM = ($DeployJob |select -ExpandProperty Parameters).vmName.Value
				Write-Host "Successfully deployed VM '$DeployVM'" -ForegroundColor Yellow
			}
			Else {
				Write-Host "Failed to deploy VM '$($VM[$d])'" -ForegroundColor Red
			}
		}
	} #EndFor
} #EndProcess

End {}
