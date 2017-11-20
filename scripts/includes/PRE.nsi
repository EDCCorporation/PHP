${If} ${SectionIsSelected} ${SEC_PHP}
	DetailPrint "Stopping IIS"
	nsExec::ExecToLog "iisreset /stop"
${EndIf}