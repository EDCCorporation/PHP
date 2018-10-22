# #############################################################################
# This script is used to build our PHP installer
#
# Requirements:
# - You must have GitHub Desktop installed (https://desktop.github.com)
# - You must have a file %LOCALAPPDATA%\GitHub\shell.ps1 which exists (see note below)
# - You must be running this script with a "Start In" set to the proper PHP repository root
# - You must have PuTTY (use Ninite) installed in %PROGRAMFILES32%\PuTTY
#
# Notes:
# - The shell.ps1 file is created by the GitHub Desktop installer automatically if you choose PowerShell as your preferred shell
# - Run with the -test parameter to enable testing mode (no changes are pushed or pulled to/from GitHub)
# #############################################################################

#region Set Parameters

Param(
    # Operational Mode Flags

    # Change this line to = $true if you want to do a lot of test runs
    [switch]$test = $false,
    # Change this line to = $true if you want to run this script in an alternative directory
    [switch]$skip_dir_check = $false,
	# Change this switch to = $true for when this script is being run by a parent project (AIMS 9, AIMS Web 9, etc)
	[switch]$embedded = $false,

    # File Paths
	[string]$makensis = (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "NSIS\makensis.exe"),
    [string]$pscp = (Join-Path -Path ${env:ProgramFiles} -ChildPath "PuTTY\pscp.exe"),

    # Remote server paths
    [string]$php_remote_path = "/home/ftp/pub/php",
    [string]$private_key_file
)
if ($test) { Write-Host -ForegroundColor Yellow "Testing Mode Enabled" }

#endregion

#region Define some system-level attributes
function GetSystemAttributes {
    # Determine the proper private key file to use for uploads
    if($private_key_file -eq "") {
        $script:private_key_file = (Get-ChildItem "~/Keys/*.ppk")[0]
    } else {
        $script:private_key_file = $private_key_file
    }
}
GetSystemAttributes
#endregion

#region Initialize a GitHub SSL session
function InitGitHubSSL {
    Write-Host -ForegroundColor Green "Initializing GitHub SSL session"

    # Get the current ExecutionPolicy
    $OriginalExecutionPolicy = Invoke-Command -ScriptBlock { Get-ExecutionPolicy -Scope Process }

    # Enable running non-signed scripts for this process only
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force

    # Run the GitHub-provided shell script
    & (Join-Path ($env:LOCALAPPDATA + "\GitHub") "shell.ps1")

    # Restore the original ExecutionPolicy
    Set-ExecutionPolicy $OriginalExecutionPolicy -Scope Process -Force

    # Normalize the $env:Path variable, so it doesn't grow with extra executions
    $env:Path = (($env:Path -split ';' | select -Unique) -join ';')
}
if ($embedded -or $test) { 
	$skip_dir_check = $true
} else {
	InitGitHubSSL 
}
#endregion

#region Ensure we're in the repository root directory
function CheckCorrectDirectory {
    Write-Verbose "Verifying that we're in the correct directory"

    $output = Invoke-Expression "git remote -v"
    if (($LASTEXITCODE -ne 0) -or
        ($output -notmatch 'origin\s+https://github.com/EDCCorporation/PHP.git')) {
        Write-Host -ForegroundColor Red "You must run this script from within the context of the proper php repository"
        exit 1
    }
}
if (-not $skip_dir_check) { CheckCorrectDirectory }
#endregion

#region Get the md5 sum of the current BuildRelease.ps1 file
function GetBuildScriptMD5 {
    [Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null

    $file_data = [System.IO.File]::ReadAllBytes((Join-Path (Get-Location) "scripts\BuildRelease.ps1"))
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    return [System.BitConverter]::ToString($md5.ComputeHash($file_data))
}
$build_script_md5 = GetBuildScriptMD5
#endregion

#region Initialize the working directory with the latest from source
function InitWorkingDirectory {
    Write-Host -ForegroundColor Green "Resetting working directory to match the branch origin\master"
    $does_branch_exist = Invoke-Expression "git branch --list master"
    if($does_branch_exist.length -eq 0)
    {
        Write-Host -ForegroundColor Yellow "New remote branch selected, loading it locally"
        Invoke-Expression "git checkout -q --track origin/master"
    } else {
        $current_branch = Invoke-Expression "git rev-parse --abbrev-ref HEAD"
        if($current_branch -ne "master") {
            Write-Host -ForegroundColor Green "Checking out branch master"
            Invoke-Expression "git checkout -q master"
        }
        Write-Host -ForegroundColor Green "Pulling to the latest version of origin\master"
        Invoke-Expression "git pull -q"
    }    
}
if (-not ($test -or $embedded)) { InitWorkingDirectory }
#endregion

#region Verify that the BuildRelease.ps1 file hasn't been modified
# This is done so to alert us if the script file was updated switching
# between beta and stable, and to make sure we're using the *right* one
if(-not $embedded) {
	if($build_script_md5 -ne (GetBuildScriptMD5)) {
		Write-Host -ForegroundColor Yellow "An update to BuildRelease.ps1 was detected, restaring build script"
		Invoke-Expression (Join-Path (Get-Location) "scripts\BuildRelease.ps1")
		exit
	}
}
#endregion

#region Get the version number of the previous build
function GetPHPVersion {
    Write-Verbose "Getting current php version to use"
	
	$script:php_version = Get-Content (Join-Path (Get-Location) "php_version.txt")
	$script:php_major = $script:php_version.Substring(0,3);
	Write-Host -ForegroundColor Green "Using PHP version $script:php_version"
}
GetPHPVersion
#endregion

#region Check to see if our output file already exists
function CheckIfInstallerExists {
	if(Test-Path  (Join-Path (Get-Location) "releases\$script:php_major\php-$script:php_version-x64-EDC-Setup.exe")) {
		Write-Host -ForegroundColor Green "Current PHP installer already exists, no need to build a new one"
		exit
	}
}
if(-not $embedded) { CheckIfInstallerExists }
#endregion

#region Ensure the "source" directory exists
function EnsureSourceDirectoryExists {
	Write-Verbose "Creating the PHP source directory (if it doesn't exist)"	
	if (-Not (Test-Path "source")) {
        New-Item "source" -type directory
    }
}
EnsureSourceDirectoryExists
#endregion

#region Download the latest version of PHP
function DownloadPHP {
	Write-Verbose "Ensuring we have the proper PHP source"
	if(-Not (Test-Path "downloads")) {
		New-Item "downloads" -type directory
	}
	
	$filename = "php-$script:php_version-nts-Win32-VC15-x64.zip"
	$script:php_source = (Join-Path (Get-Location) "downloads\$filename")
	if(-Not (Test-Path $script:php_source)) {
		$url = "https://windows.php.net/downloads/releases/$filename"
		Write-Host -ForegroundColor Green "Downloading $url"
		$web_client = New-Object System.Net.WebClient
		$web_client.Headers.Add("User-Agent", "PowerShell / EDC Build Script");
		$web_client.DownloadFile($url, $script:php_source)
	}
	
	Write-Verbose "Deleting the existing PHP installation"    
    Remove-Item -Recurse "source\*"
	Write-Host -ForegroundColor Green "Extracting php.zip"	
	.\scripts\unzip.exe -q ($script:php_source) -d .\source		
		
	#region Download the latest version of Mozilla's CA Cert's file for inclusion in our PHP release
	$url = "https://curl.haxx.se/ca/cacert.pem"
	Write-Host -ForegroundColor Green "Downloading $url"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$web_client = New-Object System.Net.WebClient
	$web_client.Headers.Add("User-Agent", "PowerShell / EDC Build Script");
	$web_client.DownloadFile($url, (Join-Path (Get-Location) "source\cacert.pem"))
	#endregion
	
	#region Download the latest version of the VC15 redistributable
	$filename = (Join-Path (Get-Location) "downloads\vc_redist.x64.exe")
	$url = 'https://aka.ms/vs/15/release/VC_redist.x64.exe'
	Write-Host -ForegroundColor Green "Downloading $url"
	$web_client = New-Object System.Net.WebClient
	$web_client.Headers.Add("User-Agent", "PowerShell / EDC Build Script");
	$web_client.DownloadFile($url, $filename)
	#endregion
}
DownloadPHP
#endregion

#region Ensure the "releases" directory exists
function EnsureReleasesDirectoryExists {
	Write-Verbose "Creating the PHP releases directory (if it doesn't exist)"	
	if (-Not (Test-Path "releases")) {
        New-Item "releases" -type directory
    }
	if (-Not (Test-Path "releases/$script:php_major")) {
		New-Item "releases/$script:php_major" -type directory
	}
}
EnsureReleasesDirectoryExists
#endregion

#region Build the installer
function BuildInstaller {
	Write-Host -ForegroundColor Green "Building PHP Installer"
    
    $arguments = @("/dPHP_SOURCE=" + (Get-Location))
    $arguments += "/dPHP_VERSION=$script:php_version"
    $arguments += "/V1"
    $arguments += (Join-Path (Get-Location) "scripts/Installer.nsi")
    Start-Process $makensis -NoNewWindow -Wait -ArgumentList $arguments
}
if(-not $embedded) { BuildInstaller }
#endregion

#region Prompt for upload of the build
$publish = $false
if((-not $embedded) -and (-not $test)){
    Write-Host -ForegroundColor Yellow -NoNewLine "Would you like to publish this build to the EDC Website? (y/n): "
    $publish = Read-Host
    if($publish -eq "y") { $publish = $true } else { $publish = $false }
}
#endregion

#region Upload the installers to the EDC website
function UploadToFTPSite {
    Write-Host -ForegroundColor Green "Uploading PHP Installer $script:php_version to the EDC Website"
    Write-Host -ForegroundColor Green "Upload directory set to $php_remote_path"

    $arguments = @("-scp")
    $arguments += @("-l", "edc")
    $arguments += @("-i", $private_key_file)
    $arguments += (Join-Path (Get-Location) "releases\$script:php_major\php-$script:php_version-x64-EDC-Setup.exe")
    $arguments += "www.aimsparking.com:$php_remote_path/php_" + $script:php_major + "_x64/"
    Start-Process $pscp -Wait -ArgumentList $arguments
}
if (-not $publish) { 
	if(-not $embedded) {
		Write-Host -ForegroundColor Yellow "Skipping upload of installer to EDC Website"
	}
} else { UploadToFTPSite }
#endregion

#region Display build complete message

Write-Host -ForegroundColor Green "PHP Build Complete"
if(-not $embedded) {	
	Read-Host "Press enter to continue..."
}

#endregion