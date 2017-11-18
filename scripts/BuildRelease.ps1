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
if ($embedded) { 
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
if(Test-Path  (Join-Path (Get-Location) "releases\$script:php_major\php-$script:php_version-x64-EDC-Setup.exe")) {
	Write-Host -ForegroundColor Green "Current PHP installer already exists, no need to build a new one"
	exit
}
#endregion

#region Download the latest version of PHP
function DownloadPHP {
	Write-Verbose "Deleting the existing PHP installation"
	Remove-Item -Recurse "source\*"
	
	$url = "http://windows.php.net/downloads/releases/php-$script:php_version-nts-Win32-VC14-x64.zip"
	Write-Host -ForegroundColor Green "Downloading $url"
	(New-Object System.Net.WebClient).DownloadFile($url, (Join-Path (Get-Location) "source\php.zip"))
	
	Write-Host -ForegroundColor Green "Extracting php.zip"	
	.\scripts\unzip.exe -q .\source\php.zip -d .\source	
	
	Remove-Item "source\php.zip"
		
	$url = "https://curl.haxx.se/ca/cacert.pem"
	Write-Host -ForegroundColor Green "Downloading $url"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	(New-Object System.Net.WebClient).DownloadFile($url, (Join-Path (Get-Location) "source\cacert.pem"))
}
DownloadPHP
#endregion

#region Build the installer
function BuildInstaller {
	Write-Host -ForegroundColor Green "Building PHP Installer"
    
    $aims9source = Get-Location

    $arguments = @("/dSOURCE=" + (Get-Location))
    $arguments += "/dVERSION=$script:php_version"
    $arguments += "/V1"
    $arguments += (Join-Path (Get-Location) "scripts/Installer.nsi")
    Start-Process $makensis -NoNewWindow -Wait -ArgumentList $arguments
}
if(-not $embedded) { BuildInstaller }

#region Prompt for upload of the build
$publish = $false
if(-not $embedded) {
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
if (-not $publish) { Write-Host -ForegroundColor Yellow "Skipping upload of installer to EDC Website"
} else { UploadToFTPSite }
#endregion
function UploadChangeLogs {

    # Prep the login header for all JSON headings
    $login_token_bytes = [System.Text.Encoding]::ASCII.GetBytes($zendesk_login_token)
    $login_token_base64 = [System.Convert]::ToBase64String($login_token_bytes)
    $headers = @{ Authorization = "Basic $login_token_base64" }

    # Load the new content for the changelog KB article
    $new_content = [IO.File]::ReadAllText($script:changelog_filename)
    $new_content = $new_content.Replace("`r`n", "<br/>").Replace("`n", "<br/>");

    # Load all exiting articles, and check for if the article already exists
    $found = $false
    $articles_http_response = Invoke-WebRequest -Uri $kb_articles_url -Headers $headers 
    $articles_json = $articles_http_response.Content | ConvertFrom-Json

    foreach ($article in $articles_json.articles) {
        if($article.name -match $script:knowledge_base_title) {

            # Get the article id
            $article_id = $article.id

            # Update the existing article using the ZenDesk "translation" command
            Invoke-WebRequest `
                -Uri "https://edchelp.zendesk.com/api/v2/help_center/articles/$article_id/translations/en-us.json" `
                -Headers $headers -Method PUT `
                -Body ('{"translation": {"body": ' + ($new_content | ConvertTo-Json) + ' }}') `
                -ContentType "application/json" | Out-Null
        
            $found = $true
            break
        }
    }
 
     if(!$found){
        # Create a new article
        $new_article_cmd = '{"article":{"title": '+ ($script:knowledge_base_title | ConvertTo-Json) +' , "body": ' + ($new_content | ConvertTo-Json) + ' , "locale": "en-us"}}'
        Invoke-WebRequest -Uri $kb_articles_url -Headers $headers -Method POST -Body $new_article_cmd -ContentType "application/json" | Out-Null
     }
}
if (-not $publish) { Write-Host -ForegroundColor Yellow "Skipping uploading change logs to the knowlegebase"
} else { UploadChangeLogs }
#endregion

#region Display build complete message

Write-Host -ForegroundColor Green "PHP Build Complete"
if(-not $embedded) {	
	Read-Host "Press enter to continue..."
}

#endregion