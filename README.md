# Azure Repo
## Microsoft Azure POSH scripts

### </b><ins>[Deploy-AzureVm.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/Deploy-AzureVm.ps1)

This script deploys multiple Azure VM from JSON templates.

In MSDN subscription it adds public IP and uses DHCP for internal IP address.

For all another subscriptions no Public IP created and static internal IP assigned.

### </b><ins>[New-SecureCred.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/New-SecureCred.ps1)

This script creates file that contains encrypted password for Azure VM local admin account.

"adminPassword" parameter from JSON template.

### </b><ins>[Iec_Msdn_Windows.json</ins></b>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows.json)

JSON example for standalone Azure Windows VMs in MSDN subscription.

### </b><ins>[Iec_Msdn_Windows_AS.json</ins></b>] (https://github.com/rgel/Azure/blob/master/Iec_Msdn_Windows_AS.json)

JSON example for Availability Set members Azure Windows VMs in MSDN subscription.
