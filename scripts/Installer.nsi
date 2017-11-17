########################################################################################
##
## PHP Install Script
## 
## This script will build the PHP installer
## 
## Built-time define's supported:
##      SOURCE		    Required    Value: Path to the source i.e. "c:\git\PHP"
##      VERSION         Required    Value: PHP Build Version i.e. "7.1.0"
##
########################################################################################

#########################################################################################
# You can use the following powershell command to test as well:
# Start-Process 'C:\Program Files (x86)\NSIS\makensis.exe' -NoNewWindow -Wait -ArgumentList @("/dSOURCE=c:\git\PHP", "/dVERSION=7.1.0", "Installer.nsi", "/V1")
#########################################################################################	

#########################################################################################
## Global Installer Settings
#########################################################################################

!define NAME "EDC_PHP_Installer"
!define COMPANY "EDC Corporation"
!define URL "http://aimsparking.com/"
!define COPYRIGHT "(c)2017 EDC Corporation"

Name ${NAME}
InstallDir "c:\PHP"
OutFile "${SOURCE}\releases\7.1\php-${VERSION}-x64-EDC-Setup.exe"

CRCCheck on
XPStyle on

ShowInstDetails show
RequestExecutionLevel admin

VIProductVersion "${VERSION}.0"
VIAddVersionKey ProductName "EDC PHP Installer"
VIAddVersionKey ProductVersion "${VERSION}"
VIAddVersionKey CompanyName "${COMPANY}"
VIAddVersionKey CompanyWebsite "${URL}"
VIAddVersionKey FileVersion "${VERSION}"
VIAddVersionKey FileDescription ""
VIAddVersionKey LegalCopyright "${COPYRIGHT}"
!define REGKEY "SOFTWARE\${NAME}"
InstallDirRegKey HKLM "${REGKEY}" Path


#########################################################################################
## GUI Setup
#########################################################################################
!define MUI_ICON "${SOURCE}\scripts\php.ico"
!define MUI_FINISHPAGE_NOAUTOCLOSE

#########################################################################################
## Include 3rd Party Plugins
#########################################################################################

!include Sections.nsh
!include MUI2.nsh
!include LogicLib.nsh

#########################################################################################
## The "Main" code to the installer
#########################################################################################

Var PHPTimeZone

InstType "Everything"
InstType "AIMS 9 Only"
InstType "AIMS Web 8.x Only"
InstType "AIMS Web 9.x Only"

# installer
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

#########################################################################################
## Installer Sections
#########################################################################################

Section -pre
    SectionIn 1 2 3 4
	
	DetailPrint "Stopping IIS"
	nsExec::ExecToLog "iisreset /stop"
    
SectionEnd

Section "-Base PHP" SEC_PHP
    SectionIn 1 2 3 4
	
	DetailPrint "Installing Base PHP Build"	
    SetOutPath $INSTDIR
    SetOverwrite on

	# Set the PHP_INI_SCAN_DIR environment variable
	DetailPrint "Setting PHP_INI_SCAN_DIR Environment Variable"
	WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" PHP_INI_SCAN_DIR "$INSTDIR\php.d"
	SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
	
	# Install base php installation files
	File /r "${SOURCE}\Source\*"
	File /oname=php.ini "${SOURCE}\Source\php.ini-production"
	
	# Add common custom ini's	
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.iis.ini"
	File "${SOURCE}\php.d\php.opcache.ini"
	File "${SOURCE}\php.d\php.paths.ini"
	File "${SOURCE}\php.d\php.uploads.ini"
	
	# Set the timezone in php.timezone.ini
	File "${SOURCE}\php.d\php.timezone.ini"	
	${If} $PHPTimeZone != ""
		FileOpen $0 "$INSTDIR\php.d\php.timezone.ini" a
		FileSeek $0 0 END
		FileWrite $0 "$\r$\n$\r$\n"
		FileWrite $0 "; Timezone set by EDC PHP Installer:$\r$\n"
		FileWrite $0 "date.timezone = $PHPTimeZone$\r$\n"
		FileClose $0
	${EndIf}
	
	# Make sure the sessions directory exists
	CreateDirectory "$INSTDIR\sessions"			
	# Set the permissions on the sessions directory
	AccessControl::GrantOnFile "$INSTDIR\sessions" "IUSR" "GenericRead + GenericExecute + GenericWrite + Delete + ListDirectory"
	AccessControl::GrantOnFile "$INSTDIR\sessions" "IIS_IUSRS" "GenericRead + GenericExecute + GenericWrite + Delete + ListDirectory"
	
SectionEnd

Section /o "AIMS 9 Support" SEC_AIMS_9
    SectionIn 1 2
	
	DetailPrint "Adding AIMS 9 support"
    SetOutPath $INSTDIR
    SetOverwrite on

	# Install AIMS 9 Library
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.aims9.ini"
	
SectionEnd

Section /o "AIMS Web 8.x Support" SEC_AIMS_WEB_8
    SectionIn 1 3
	
	DetailPrint "Adding AIMS Web 8.x support"
    SetOutPath $INSTDIR
    SetOverwrite on

	# Install AIMS Web 8 Library
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.aimsweb8.ini"
	
	# Install Wincache Library
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.wincache.ini"
	SetOutPath "$INSTDIR\ext"
	File "${SOURCE}\ext\php_wincache.dll"
	
SectionEnd

Section /o "AIMS Web 9.x Support" SEC_AIMS_WEB_9
    SectionIn 1 4
	
	DetailPrint "Adding AIMS Web 9.x support"
    SetOutPath $INSTDIR
    SetOverwrite on

	# Install AIMS Web 9 Library
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.aimsweb9.ini"
	
	# Install Mongo Library
	SetOutPath "$INSTDIR\php.d"
	File "${SOURCE}\php.d\php.mongodb.ini"
	SetOutPath "$INSTDIR\ext"
	File "${SOURCE}\ext\php_mongodb.dll"
	
SectionEnd

Section -post  
    SectionIn 1 2 3 4	
	
	DetailPrint "Starting IIS"
	nsExec::ExecToLog "iisreset /start"
	
	DetailPrint "Writing Registry Keys"
	WriteRegStr HKLM "${REGKEY}" Path $INSTDIR
    	
SectionEnd


#########################################################################################
## Helper Functions
#########################################################################################

;;=======================================================================================
Function .onInit

	# Load the previous install path (if any)
	ReadRegStr $INSTDIR HKLM "${REGKEY}" Path
	${If} $INSTDIR == ""
		# default to standard install folder		
		StrCpy $INSTDIR "c:\PHP"
	${Else}
		# Set the default options for all AIMS client components to be installed if previously installed
		${If} ${FileExists} "$INSTDIR\php.d\php.aims9.ini"
			SectionGetFlags ${SEC_AIMS_9} $0
			IntOp $0 $0 | ${SF_SELECTED}
			SectionSetFlags ${SEC_AIMS_9} $0
		${EndIf}
		${If} ${FileExists} "$INSTDIR\php.d\php.aimsweb8.ini"
			SectionGetFlags ${SEC_AIMS_WEB_8} $0
			IntOp $0 $0 | ${SF_SELECTED}
			SectionSetFlags ${SEC_AIMS_WEB_8} $0
		${EndIf}
		${If} ${FileExists} "$INSTDIR\php.d\php.aimsweb9.ini"
			SectionGetFlags ${SEC_AIMS_WEB_9} $0
			IntOp $0 $0 | ${SF_SELECTED}
			SectionSetFlags ${SEC_AIMS_WEB_9} $0
		${EndIf}
	${EndIf}
		
	# Set the default timezone value
	StrCpy $PHPTimeZone ""
	nsExec::ExecToStack "tzutil /g"
	Pop $R0
	${If} $R0 == "0"
		Pop $R0
		${If} $R0 == "Eastern Standard Time"
			StrCpy $PHPTimeZone "America/New_York"
		${ElseIf} $R0 == "Central Standard Time"
			StrCpy $PHPTimeZone "America/Chicago"
		${ElseIf} $R0 == "Mountain Standard Time"
			StrCpy $PHPTimeZone "America/Denver"
		${ElseIf} $R0 == "US Mountain Standard Time"
			StrCpy $PHPTimeZone "America/Phoenix"
		${ElseIf} $R0 == "Pacific Standard Time"
			StrCpy $PHPTimeZone "America/Los_Angeles"
		${EndIf}
	${EndIf}

FunctionEnd
;;=======================================================================================

#########################################################################################
## Section Descriptions
#########################################################################################

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SEC_AIMS_9} "Installs additional php modules required for supporting AIMS 9.x"
	!insertmacro MUI_DESCRIPTION_TEXT ${SEC_AIMS_WEB_8} "Installs additional php modules required for supporting AIMS Web 8.x"
	!insertmacro MUI_DESCRIPTION_TEXT ${SEC_AIMS_WEB_9} "Installs additional php modules required for supporting AIMS Web 9.x"
!insertmacro MUI_FUNCTION_DESCRIPTION_END