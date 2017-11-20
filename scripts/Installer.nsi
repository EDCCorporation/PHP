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
# Start-Process 'C:\Program Files (x86)\NSIS\makensis.exe' -NoNewWindow -Wait -ArgumentList @("/dPHP_SOURCE=c:\git\PHP", "/dPHP_VERSION=7.1.0", "scripts\Installer.nsi", "/V1")
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
OutFile "${PHP_SOURCE}\releases\7.1\php-${PHP_VERSION}-x64-EDC-Setup.exe"

!include "includes\CONSTANTS.nsi"

CRCCheck on
XPStyle on
SetCompressor /solid lzma

ShowInstDetails show
RequestExecutionLevel admin

VIProductVersion "${PHP_VERSION}.0"
VIAddVersionKey ProductName "EDC PHP Installer"
VIAddVersionKey ProductVersion "${PHP_VERSION}"
VIAddVersionKey CompanyName "${COMPANY}"
VIAddVersionKey CompanyWebsite "${URL}"
VIAddVersionKey FileVersion "${PHP_VERSION}"
VIAddVersionKey FileDescription ""
VIAddVersionKey LegalCopyright "${COPYRIGHT}"
InstallDirRegKey HKLM "${PHP_REGKEY}" Path


#########################################################################################
## GUI Setup
#########################################################################################
!define MUI_ICON "${PHP_SOURCE}\scripts\php.ico"
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

!include "includes\VARS.nsi"

InstType "Everything"
InstType "Base PHP Only"
InstType "AIMS 9 Only"
InstType "AIMS Web 9.x Only"
InstType "AIMS Web 8.x Only"

# installer
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

#########################################################################################
## Installer Sections
#########################################################################################

Section -pre
    SectionIn 1 2 3 4 5
	
	StrCpy $PHPDir $INSTDIR
	
	!include "includes\PRE.nsi"
SectionEnd

Section "PHP ${PHP_VERSION}" SEC_PHP
    SectionIn 1 2 3 4 5 RO
	!include "includes\SEC_PHP.nsi"	
SectionEnd

Section /o "AIMS 9 Support" SEC_PHP_AIMS_9
    SectionIn 1 3
	!include "includes\SEC_PHP_AIMS_9.nsi"	
SectionEnd

Section /o "AIMS Web 9.x Support" SEC_PHP_AIMS_WEB_9
    SectionIn 1 4
	!include "includes\SEC_PHP_AIMS_WEB_9.nsi"
SectionEnd

Section /o "AIMS Web 8.x Support" SEC_PHP_AIMS_WEB_8
    SectionIn 1 5
	!include "includes\SEC_PHP_AIMS_WEB_8.nsi"
SectionEnd

Section -post  
    SectionIn 1 2 3 4 5
	!include "includes\POST.nsi"
SectionEnd


#########################################################################################
## Helper Functions
#########################################################################################

Function .onInit
	
	SectionGetFlags ${SEC_PHP} $0
	IntOp $0 $0 | ${SF_SELECTED}
	SectionSetFlags ${SEC_PHP} $0
	
	!include "includes\onInit.nsi"	
FunctionEnd

Function .onSelChange
	!include "includes\OnSelChange.nsi"
FunctionEnd

#########################################################################################
## Section Descriptions
#########################################################################################

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!include "includes\MUI_DESCRIPTIONS.nsi"
!insertmacro MUI_FUNCTION_DESCRIPTION_END