#requires -Version 3.0

Param (
	[Parameter(Mandatory,Position=0,HelpMessage="Enter password to encrypt")]
		[ValidateNotNullorEmpty()]
	[string]$Password
	,
	[Parameter(Mandatory=$false,Position=1,HelpMessage="Secure file full path")]
		[ValidateNotNullorEmpty()]
		[ValidateScript({Test-Path (Split-Path $_) -PathType 'Container'})]
	[string]$SecureFile = "$PSScriptRoot\secure.cred"
	,
	[Parameter(Mandatory=$false,Position=2)]
		[Alias("Show")]
	[switch]$ShowSecureFile
)

$Password |ConvertTo-SecureString -AsPlainText -Force |ConvertFrom-SecureString |Out-File $SecureFile
If ($ShowSecureFile) {notepad $SecureFile}
