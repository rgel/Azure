Function Invoke-SortIpAddress
{
	
<#
.SYNOPSIS
	Sort IP addresses pool.
.DESCRIPTION
	This simple and short function intellectually sorts IP addresses.
.PARAMETER IpPool
	Specifies IP addresses to sort.
.PARAMETER ZA
	If specified, sort descending.
.EXAMPLE
	PS C:\> '172.31.97.14', '172.31.97.20', '172.31.97.4' | Sort-IpAddress
	Try the same with the Sort-Object cmdlet instead of the Sort-IpAddress and compare the results :-)
.EXAMPLE
	PS C:\> 1..254 |% {"192.168.10.$_"} | Sort-IpAddress -ZA
	Sort descending a Class C subnet.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Version 1.0 :: 24-Oct-2017 :: [Release] :: Publicly available
.LINK
	https://ps1code.com/2017/10/26/sort-ip-address-powershell
#>
	
	[CmdletBinding()]
	[Alias("Sort-IpPool", "Sort-IpAddress")]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[ipaddress[]]$IpPool
		 ,
		[Parameter(Mandatory = $false)]
		[switch]$ZA
	)
	
	Begin
	{ }
	Process
	{
		$IpPool2 += $IpPool
	}
	End
	{
		$IpPoolObj = foreach ($Ip in $IpPool2)
		{
			$IpBytes = $Ip.GetAddressBytes()
			
			[pscustomobject] @{
				IP = $Ip.IPAddressToString
				Octat1 = $IpBytes[0]
				Octat2 = $IpBytes[1]
				Octat3 = $IpBytes[2]
				Octat4 = $IpBytes[3]
			}
		}
		if ($ZA) { ($IpPoolObj | Sort-Object -Descending Octat1, Octat2, Octat3, Octat4).IP }
		else { ($IpPoolObj | Sort-Object Octat1, Octat2, Octat3, Octat4).IP }
	}
	
} #EndFunction Invoke-SortIpAddress
