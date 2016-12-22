#requires -Version 3.0

<#
.SYNOPSIS
	Safely save the encrypted password to a file.
.DESCRIPTION
	The New-SecureCred.ps1 script safely saves the encrypted text (probably password) to a file.
	To decrypt that text you MUST meet three conditions:
	[1] You are logged on with the same user account used to encrypt the text.
	[2] You are logged on to the same computer used to encrypt the data.
	[3] You has not changed your password since you have created the encrypted file.
.PARAMETER Password
	String to encrypt.
.PARAMETER SecureFile
	Save encrypted password here.
.PARAMETER ShowSecureFile
	Open the SecureFile by any text editor.
.EXAMPLE
	PS C:\scripts> .\New-SecureCred.ps1 'YourPassword'
	Save encrypted password in the default path (the script's root directory).
.EXAMPLE
	PS C:\scripts> .\New-SecureCred.ps1 -Password 'A123456a' -SecureFilePath "$(Split-Path $PROFILE)\mycred.txt"
	Save encrypted password in your PowerShell profile directory.
.EXAMPLE
	PS C:\scripts> .\New-SecureCred.ps1 'A123456a' "$($env:USERPROFILE)\Documents\esx.sec" -Show
	Save encrypted password in your `My Documents` folder.
.NOTES
	Author      :: Roman Gelman
	Version 1.0 :: 14-Jun-2016 :: [Release]
	Version 1.1 :: 21-Dec-2016 :: [Change] Content based help has been added, minor code changes.
.LINK
	http://ps1code.com
#>

Param (
	[Parameter(Mandatory,Position=0,HelpMessage="Enter password to encrypt")]
		[ValidateNotNullorEmpty()]
	[string]$Password
	,
	[Parameter(Mandatory=$false,Position=1,HelpMessage="Secure file full path")]
		[ValidateNotNullorEmpty()]
		[ValidateScript({Test-Path (Split-Path $_) -PathType 'Container'})]
		[Alias("SecureFilePath")]
	[string]$SecureFile = "$PSScriptRoot\secure.cred"
	,
	[Parameter(Mandatory=$false)]
		[Alias("Show")]
	[switch]$ShowSecureFile
)

$Password |ConvertTo-SecureString -AsPlainText -Force |ConvertFrom-SecureString |Out-File $SecureFile
If ($ShowSecureFile -and (Test-Path $SecureFile -PathType Leaf)) {Invoke-Item $SecureFile}
