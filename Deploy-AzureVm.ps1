#requires -Version 4.0 -Modules 'AzureRM.Storage','AzureRM.Resources','AzureRM.Compute','AzureRM.Network'

<#
.SYNOPSIS
	Deploy Azure VM.
.DESCRIPTION
	This script automates Azure VM deployment process.
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
	PS C:\> .\Deploy-AzureVm.ps1 -Environment TEST -Guest WindowsSql12 -Project IFN -Notes SQL -VMCount 2 -HighAvailable
.NOTES
	Author      :: Roman Gelman @rgelman75
	Dependency  :: AzureRm PowerShell Module
	Shell       :: Tested on PowerShell 5.1
	Platform    :: Tested on AzureRm v.3.7.0
	Version 1.0 :: 20-Jun-2016 :: [Release]
	Version 1.1 :: 21-Jul-2016 :: [Improvement] Added more supported VM images [-Guest] parameter
	Version 1.2 :: 24-Aug-2016 :: [Bugfix]      StorageAccount type determining changed to generate VMSize list
	Version 1.3 :: 22-Sep-2016 :: [New Feature] Added optional parameter [-AzureCred]
	Version 1.4 :: 27-Jun-2017 :: [Change]      Code optimizations 
.LINK
	https://ps1code.com/category/powershell/azure/
#>

[CmdletBinding()]
Param (
	[Parameter(Mandatory = $false, Position = 0)]
	[ValidateSet("PROD", "DEV", "TEST", "DMZ", "LABS", "MSDN")]
	[Alias("Domain")]
	[string]$Environment = "MSDN"
	 ,
	[Parameter(Mandatory = $false, Position = 1)]
	[ValidateRange(1, 10)]
	[Alias("VMQuantity")]
	[uint16]$VMCount = 1
	 ,
	[Parameter(Mandatory = $false, Position = 2)]
	[ValidateSet("Windows", "WindowsSql12", "WindowsSql14", "WindowsSql16", "RedHat")]
	[Alias("VMGuest")]
	[string]$Guest = 'Windows'
	 ,
	[Parameter(Mandatory = $false)]
	[Alias("DisableFilter")]
	[switch]$NoFilter
	 ,
	### JSON :: [parameters('vmTag')] ###
	[Parameter(Mandatory = $false, Position = 3)]
	[ValidateNotNullorEmpty()]
	[string]$Project = 'Infra'
	 ,
	### JSON :: [parameters('vmNotes')] ###
	[Parameter(Mandatory = $false, Position = 4)]
	[ValidateNotNullorEmpty()]
	[Alias("VMNotes")]
	[string]$Notes = '_xxx_'
	 ,
	[Parameter(Mandatory = $false, Position = 5)]
	[ValidateNotNullorEmpty()]
	[string]$VMName
	 ,
	[Parameter(Mandatory=$false)]
	[Alias("HA")]
	[switch]$HighAvailable
	 ,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullorEmpty()]
	[Alias("Credential")]
	[System.Management.Automation.PSCredential]$AzureCred
	 ,
	[Parameter(Mandatory = $false)]
	[switch]$WhatIf
)

Begin
{
	### Helper functions ###
	Function Write-Menu
	{
		
	<#
	.SYNOPSIS
		Display custom menu in the PowerShell console.
	.DESCRIPTION
		The Write-Menu cmdlet creates numbered and colored menues
		in the PS console window and returns the choiced entry.
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
		Quantity of <TAB> keys to shift the menu items right.
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
		Any type of data (object(s), string(s), number(s), etc).
	.OUTPUTS
		[The same type as input object] Single menu item.
	.NOTES
		Author      :: Roman Gelman @rgelman75
		Version 1.0 :: 21-Apr-2016 :: [Release]
		Version 1.1 :: 03-Nov-2016 :: [Change] Supports a single item as menu entry
		Version 1.2 :: 22-Jun-2017 :: [Change] Throw an error if property, specified by -PropertyToShow does not exist. Code optimization
	.LINK
		https://ps1code.com/2016/04/21/write-menu-powershell
	#>
		
	[CmdletBinding()]
	[Alias("menu")]
	Param (
		[Parameter(Mandatory, Position = 0)]
		[Alias("MenuEntry", "List")]
		$Menu
		 ,
		[Parameter(Mandatory = $false, Position = 1)]
		[string]$PropertyToShow = 'Name'
		 ,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNullorEmpty()]
		[string]$Prompt = 'Pick a choice'
		 ,
		[Parameter(Mandatory = $false, Position = 3)]
		[Alias("Title")]
		[string]$Header = ''
		 ,
		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateRange(0, 5)]
		[Alias("Tab", "MenuShift")]
		[int]$Shift = 0
		 ,
		[Parameter(Mandatory = $false, Position = 5)]
		[Alias("Color", "MenuColor")]
		[System.ConsoleColor]$TextColor = 'White'
		 ,
		[Parameter(Mandatory = $false, Position = 6)]
		[System.ConsoleColor]$HeaderColor = 'Yellow'
		 ,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[Alias("Exit", "AllowExit")]
		[switch]$AddExit
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		if ($Menu -isnot [array]) { $Menu = @($Menu) }
		if ($Menu[0] -isnot [string])
		{
			if (!($Menu | Get-Member -MemberType Property, NoteProperty -Name $PropertyToShow)) { Throw "Property [$PropertyToShow] does not exist" }
		}
		$MaxLength = if ($AddExit) { 8 }
		else { 9 }
		$AddZero = if ($Menu.Length -gt $MaxLength) { $true }
		else { $false }
		[hashtable]$htMenu = @{ }
	}
	Process
	{
		### Write menu header ###
		if ($Header -ne '') { Write-Host $Header -ForegroundColor $HeaderColor }
		
		### Create shift prefix ###
		if ($Shift -gt 0) { $Prefix = [string]"`t" * $Shift }
		
		### Build menu hash table ###
		for ($i = 1; $i -le $Menu.Length; $i++)
		{
			$Key = if ($AddZero)
			{
				$lz = if ($AddExit) { ([string]($Menu.Length + 1)).Length - ([string]$i).Length }
				else { ([string]$Menu.Length).Length - ([string]$i).Length }
				"0" * $lz + "$i"
			}
			else
			{
				"$i"
			}
			
			$htMenu.Add($Key, $Menu[$i - 1])
			
			if ($Menu[$i] -isnot 'string' -and ($Menu[$i - 1].$PropertyToShow))
			{
				Write-Host "$Prefix[$Key] $($Menu[$i - 1].$PropertyToShow)" -ForegroundColor $TextColor
			}
			else
			{
				Write-Host "$Prefix[$Key] $($Menu[$i - 1])" -ForegroundColor $TextColor
			}
		}
		
		### Add 'Exit' row ###
		if ($AddExit)
		{
			[string]$Key = $Menu.Length + 1
			$htMenu.Add($Key, "Exit")
			Write-Host "$Prefix[$Key] Exit" -ForegroundColor $TextColor
		}
		
		### Pick a choice ###
		Do
		{
			$Choice = Read-Host -Prompt $Prompt
			$KeyChoice = if ($AddZero)
			{
				$lz = if ($AddExit) { ([string]($Menu.Length + 1)).Length - $Choice.Length }
				else { ([string]$Menu.Length).Length - $Choice.Length }
				if ($lz -gt 0) { "0" * $lz + "$Choice" }
				else { $Choice }
			}
			else
			{
				$Choice
			}
		}
		Until ($htMenu.ContainsKey($KeyChoice))
	}
	End
	{
		return $htMenu.get_Item($KeyChoice)
	}
		
	} #EndFunction Write-Menu
	Function New-IPRange ($FirstIP, $LastIP)
	{
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
	
	If ($PSBoundParameters.ContainsKey('VMName') -and $VMName -match $rgxHostName)
	{ Throw "-VMName parameter contains not allowed characters" }
	
	### JSON :: [parameters('adminPassword')] ###
	### if (Test-Path .\Deploy-AzureVm.ps1 -PathType Leaf) {.\New-SecureCred.ps1 -Password '******' -SecureFile .\secure.cred} else {Write-Host "cd to the dir, containing [Deploy-AzureVm.ps1] script !!!" -ForegroundColor Red}
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
		If ($AzureCred) {Login-AzureRmAccount -Credential $AzureCred} Else {Login-AzureRmAccount}
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
	
	If     ($setResGr.Length -eq 0) {Throw "Subscription '$Subscription' doesn't have any ResourceGroups"}
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
	Else   {$Subnet = Write-Menu -Menu $setSubnt -Shift 1 -Prompt "Choice Subnet" -Header "[Stage $Stage..$Stages] Available Subnets:"}
	
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
	If ($StorageAccount.Sku.Tier -notmatch 'premium') {$setVMSiz = (Get-AzureRmVMSize -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location)).Name |sort}
	Else {$setVMSiz = (Get-AzureRmVMSize -Location ((Get-AzureRmResourceGroup -Name $ResourceGroup).Location) |? {$_.Name -match $rgxVMSize}).Name |sort}
	$VMSize = Write-Menu -Menu $setVMSiz -Shift 1 -Prompt "Choice VM Size" -Header "[Stage $Stage..$Stages] Available VM Sizes for '$($StorageAccount.Sku.Name)' StorageAccount:"
	
	### Image parameters                       ###
	### JSON :: [parameters('imagePublisher')] ###
	### JSON :: [parameters('imageOffer')]     ###
	### JSON :: [parameters('imageSku')]       ###
	$Stage++
	$rgxVmSku = 'preview'
	Switch -exact ($Guest) {
		'Windows'		{$skuPublisher = 'MicrosoftWindowsServer'; $skuOffer = 'WindowsServer';       Break}
		'WindowsSql12'	{$skuPublisher = 'MicrosoftSQLServer';     $skuOffer = 'SQL2012SP3-WS2012R2'; Break}
		'WindowsSql14'	{$skuPublisher = 'MicrosoftSQLServer';     $skuOffer = 'SQL2014SP1-WS2012R2'; Break}
		'WindowsSql16'	{$skuPublisher = 'MicrosoftSQLServer';     $skuOffer = 'SQL2016RC3-WS2012R2'; Break}
		'RedHat'		{$skuPublisher = 'RedHat';                 $skuOffer = 'RHEL'}
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
	
	### Single VM with custom name ###
	If ($PSBoundParameters.ContainsKey('VMName') -and $VMCount -eq 1) {$VM += $VMName}
	
	### Generate VM Name :: Multiple VM ###
	Else {
		For ($i=1; $i -le $VMIndex.Length-1; $i++) {If (([int]$VMIndex[$i]-[int]$VMIndex[$i-1]) -gt 1) {For ($k=1; $k -lt ([int]$VMIndex[$i]-[int]$VMIndex[$i-1]); $k++) {$FreeIndex += [string]([int]$VMIndex[$i-1] + $k)}}}
		$FreeIndexCount = $FreeIndex.Length
		If ($FreeIndexCount -lt $VMCount) {For ($j=1; $j -le ($VMCount-$FreeIndexCount); $j++) {$FreeIndex += [string]([int]$VMIndex[-1] + $j)}} Else {$FreeIndex = $FreeIndex[0..($VMCount-1)]}
		Foreach ($index in $FreeIndex) {$VM += "$rgxVMPrefix$index"}
	}
}
Process
{

	For ($d=0; $d -le $VM.Length-1; $d++) {
	
		If ($PSBoundParameters.ContainsKey('WhatIf')) {
			Write-Host "[$($d+1)] Deploy [$VMSku][$VMSize] $Guest Azure VM [$($VM[$d])] in ResourceGroup [$ResourceGroup] on StorageAccount [$($StorageAccount.StorageAccountName)]"
			#"[$($d+1)] $($VM[$d]) $($IPRange[$d])"
		}
		Else {
			Write-Progress -Activity "Deploying [$VMSku] $Guest Azure VM ..." `
						   -Status "[$VMSize] VM $($d + 1) from $($VM.Length)" `
						   -CurrentOperation "VM [$($VM[$d])]" `
						   -PercentComplete ($d/$VM.Length*100)
			
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
				Write-Host "Successfully deployed VM [$DeployVM]" -ForegroundColor Yellow
			}
			Else {
				Write-Host "Failed to deploy VM [$($VM[$d])]" -ForegroundColor Red
			}
		}
	} #End For
}
End { }
