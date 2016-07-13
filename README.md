# Azure Repo
## Microsoft Azure POSH scripts and modules

### </b><ins>[Az-Module.psm1</ins></b>] (https://github.com/rgel/Azure/blob/master/Az-Module/Az-Module.psm1)

To install this module, drop the entire '<b>Az-Module</b>' folder into one of your module directories.

The default PowerShell module paths are listed in the `$env:PSModulePath` environment variable.

To make it look better, split the paths in this manner `$env:PSModulePath -split ';'`

The default per-user module path is: `"$env:HOMEDRIVE$env:HOMEPATH\Documents\WindowsPowerShell\Modules"`.

The default computer-level module path is: `"$env:windir\System32\WindowsPowerShell\v1.0\Modules"`.

To use the module, type following command: `Import-Module Az-Module -Force -Verbose`.

To see the commands imported, type `Get-Command -Module Az-Module`.

For help on each individual cmdlet or function, run `Get-Help CmdletName -Full [-Online][-Examples]`.

##### <ins>Cmdlets:</ins>

###### <b>1. [Get-AzVmPowerState</b>] (http://goo.gl/x8Wwjk)

This filter gets AzureRm VM PowerState.

###### <b>2. [Get-AzVmTag</b>] (http://goo.gl/x8Wwjk)

This filter gets AzureRm VM Tag value.

###### <b>3. [Add-AzVmTag</b>] (http://goo.gl/gvLUlN)

This cmdlet adds/sets Resource Tag/Tags for Azure VMs.

### </b><ins>[Deploy-AzureVm.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/Deploy-AzureVm.ps1)

This script deploys multiple Azure VM from JSON templates.

In MSDN subscription it adds public IP and uses DHCP for internal IP address.

For all another subscriptions no Public IP created and static internal IP assigned.

### </b><ins>[New-SecureCred.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/New-SecureCred.ps1)

This script creates file that contains encrypted password for Azure VM local admin account.

"adminPassword" parameter from JSON template.

### </b><ins>[Iec_Msdn_Windows.json</ins></b>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows.json)

JSON template example for standalone Azure Windows VMs in MSDN subscription.

### </b><ins>[Iec_Msdn_Windows_AS.json</ins></b>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows_AS.json)

JSON template example for Availability Set members Azure Windows VMs in MSDN subscription.
