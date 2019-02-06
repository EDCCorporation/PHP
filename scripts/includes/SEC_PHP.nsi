DetailPrint "Installing the Microsoft Visual C++ Redistributable for Visual Studio 2015 (VC14)"
SetOutPath $pluginsdir
File "${PHP_SOURCE}\downloads\vc_redist.x64.exe"
ExecWait "$pluginsdir\vc_redist.x64.exe /install /quiet /norestart"

DetailPrint "Installing PHP ${PHP_VERSION} Build"	
SetOutPath $PHPDIR
SetOverwrite on

# Set the PHP_INI_SCAN_DIR environment variable
DetailPrint "Setting PHP_INI_SCAN_DIR Environment Variable"
WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" PHP_INI_SCAN_DIR "$PHPDIR\php.d"
SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

# Install base php installation files
File /r "${PHP_SOURCE}\Source\*"
File /oname=php.ini "${PHP_SOURCE}\Source\php.ini-production"

# Add common custom ini's	
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.common.ini"
File "${PHP_SOURCE}\php.d\php.curl.ini"
File "${PHP_SOURCE}\php.d\php.iis.ini"
File "${PHP_SOURCE}\php.d\php.opcache.ini"
File "${PHP_SOURCE}\php.d\php.paths.ini"
File "${PHP_SOURCE}\php.d\php.uploads.ini"

# Set the timezone in php.timezone.ini
File "${PHP_SOURCE}\php.d\php.timezone.ini"	
${If} $PHPTimeZone != ""
	FileOpen $0 "$PHPDIR\php.d\php.timezone.ini" a
	FileSeek $0 0 END
	FileWrite $0 "$\r$\n$\r$\n"
	FileWrite $0 "; Timezone set by EDC PHP Installer:$\r$\n"
	FileWrite $0 "date.timezone = $PHPTimeZone$\r$\n"
	FileClose $0
${EndIf}

# Write the zz_custom file (if it doesn't already exist)
${IfNot} ${FileExists} "$PHPDir\php.d\php.zz_custom.ini"
	File "${PHP_SOURCE}\php.d\php.zz_custom.ini"
${EndIf}

# Make sure the sessions directory exists
CreateDirectory "$PHPDIR\sessions"			
# Set the permissions on the sessions directory
AccessControl::GrantOnFile "$PHPDIR\sessions" "IUSR" "GenericRead + GenericExecute + GenericWrite + Delete + ListDirectory"
AccessControl::GrantOnFile "$PHPDIR\sessions" "IIS_IUSRS" "GenericRead + GenericExecute + GenericWrite + Delete + ListDirectory"

# Delete the wincache files if they exist (as we're no longer using them)
${If} ${FileExists} "$PHPDir\php.d\php.wincache.ini"
	Delete "$PHPDir\php.d\php.wincache.ini"
${EndIf}
${If} ${FileExists} "$PHPDir\ext\php_wincache.dll"
	Delete "$PHPDir\ext\php_wincache.dll"
${EndIf}