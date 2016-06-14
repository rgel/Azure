# Azure Repo
## Microsoft Azure POSH scripts

### </b><ins>[Deploy-AzureVm.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/Deploy-AzureVm.ps1)

This script deploys multiple Azure VM from JSON templates.
In MSDN subscription it adds public IP and uses DHCP for internal IP address.
For all another subscriptions no Public IP created and static internal IP assigned.

### </b><ins>[New-SecureCred.ps1</ins></b>] (https://github.com/rgel/Azure/blob/master/New-SecureCred.ps1)

This script creates file that contains encrypted password for Azure VM local admin account.
"adminPassword" parameter from JSON template.
