${If} ${SectionIsSelected} ${SEC_PHP}
	DetailPrint "Starting IIS"
	nsExec::ExecToLog "iisreset /start"

	DetailPrint "Writing Registry Keys"
	WriteRegStr HKLM "${PHP_REGKEY}" Path $PHPDir
${EndIf}