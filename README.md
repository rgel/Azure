# ![azureautomation2](https://cloud.githubusercontent.com/assets/6964549/17082193/9aade278-517d-11e6-8db1-1f04fb786e81.png) Azure Repo
## Microsoft Azure POSH scripts and modules

### <ins>[Az-Module.psm1</ins>] (https://github.com/rgel/Azure/blob/master/Az-Module/Az-Module.psm1)

To install this module, drop the entire '<b>Az-Module</b>' folder into one of your module directories.

The default PowerShell module paths are listed in the `$env:PSModulePath` environment variable.

To make it look better, split the paths in this manner `$env:PSModulePath -split ';'`

The default per-user module path is: `"$env:HOMEDRIVE$env:HOMEPATH\Documents\WindowsPowerShell\Modules"`.

The default computer-level module path is: `"$env:windir\System32\WindowsPowerShell\v1.0\Modules"`.

To use the module, type following command: `Import-Module Az-Module -Force -Verbose`.

To see the commands imported, type `Get-Command -Module Az-Module`.

For help on each individual cmdlet or function, run `Get-Help CmdletName -Full [-Online][-Examples]`.

To start using the module functions:

+ Install <b>Azure Resource Manager Module</b> module from Microsoft PSGallery by `Install-Module AzureRM`.
+ Connect to your Azure account by `Login-AzureRmAccount` cmdlet.
+ Optionally, select your target subscription by `Select-AzureRmSubscription` cmdlet.

#### <b><ins>Az-Module Cmdlets:</ins></b>

|No|Cmdlet|Description|
|----|----|----|
|1|<b> [Get-AzVmPowerState</b>] (http://www.ps1code.com/single-post/2016/06/19/Azure-Automation-How-to-stopstart-Azure-VM-on-schedule)|This filter gets AzureRm VM PowerState|
|2|<b> [Get-AzVmTag</b>] (http://www.ps1code.com/single-post/2016/06/19/Azure-Automation-How-to-stopstart-Azure-VM-on-schedule)|This filter gets AzureRm VM Tag value|
|3|<b> [Add-AzVmTag</b>] (http://www.ps1code.com/single-post/2016/06/29/Azure-VM-Tag-automation)|This cmdlet adds/sets Resource Tag/Tags for Azure VMs|
|4|<b> [Get-AzOrphanedVhd</b>] (http://www.ps1code.com/single-post/2016/07/18/How-to-find-orphaned-VHD-files-in-the-Azure-IaaS-cloud)|This cmdlet finds `orphaned*` Azure VM disks. Orphaned virtual disks - these are `*.vhd` files that reside on Storage Accounts, but are not related to any VM|

### <ins>[Deploy-AzureVm.ps1</ins>] (https://github.com/rgel/Azure/blob/master/Deploy-AzureVm.ps1)

This script deploys multiple Azure VM from JSON templates.

In MSDN subscription it adds public IP and uses DHCP for internal IP address.

For all another subscriptions no Public IP created and static internal IP assigned.

### <ins>[New-SecureCred.ps1</ins>] (https://github.com/rgel/Azure/blob/master/New-SecureCred.ps1)

This script creates file that contains encrypted password for Azure VM local admin account.

"adminPassword" parameter from JSON template.

### <ins>[Iec_Msdn_Windows.json</ins>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows.json)

JSON template example for standalone Azure Windows VMs in MSDN subscription.

### <ins>[Iec_Msdn_Windows_AS.json</ins>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows_AS.json)

JSON template example for Availability Set members Azure Windows VMs in MSDN subscription.
