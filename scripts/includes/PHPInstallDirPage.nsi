Function PHPInstallDirPage	

	${If} ${SectionIsSelected} ${SEC_PHP}
		!insertmacro MUI_INSTALLOPTIONS_EXTRACT_AS ${PHP_INSTDIR_PAGE_INI} "PHPInstallDir.ini"
		WriteINIStr "$PLUGINSDIR\PHPInstallDir.ini" "Field 2" "State" $PHPDIR
		
		!insertmacro MUI_HEADER_TEXT "Select PHP Installation Directory" ""		
		!insertmacro MUI_INSTALLOPTIONS_DISPLAY "PHPInstallDir.ini"
	${EndIf}
	
FunctionEnd

Function PHPInstallPageLeave

	${If} ${SectionIsSelected} ${SEC_PHP}
	
		ReadINIStr $PHPDir "$PLUGINSDIR\PHPInstallDir.ini" "Field 2" "State"
		
	${EndIf}

FunctionEnd