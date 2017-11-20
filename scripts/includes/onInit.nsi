# Load the previous install path (if any)
ReadRegStr $PHPDir HKLM "${PHP_REGKEY}" Path

${If} $PHPDir == ""
	# default to standard install folder		
	StrCpy $PHPDir "c:\PHP"
${Else}
	# Set the default options for all AIMS client components to be installed if previously installed
	${If} ${FileExists} "$PHPDir\php.d\php.iis.ini"
		SectionGetFlags ${SEC_PHP} $0
		IntOp $0 $0 | ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP} $0
	${EndIf}
	${If} ${FileExists} "$PHPDir\php.d\php.aims9.ini"
		SectionGetFlags ${SEC_PHP_AIMS_9} $0
		IntOp $0 $0 | ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_9} $0
	${EndIf}
	${If} ${FileExists} "$PHPDir\php.d\php.aimsweb8.ini"
		SectionGetFlags ${SEC_PHP_AIMS_WEB_8} $0
		IntOp $0 $0 | ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_8} $0
	${EndIf}
	${If} ${FileExists} "$PHPDir\php.d\php.aimsweb9.ini"
		SectionGetFlags ${SEC_PHP_AIMS_WEB_9} $0
		IntOp $0 $0 | ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_9} $0
	${EndIf}
${EndIf}

!insertmacro checkPHPDependencies
	
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