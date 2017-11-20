!macro checkPHPDependencies

	# Check if SEC_PHP is selected
	${If} ${SectionIsSelected} ${SEC_PHP}
		# Set SEC_PHP_AIMS_9, SEC_PHP_AIMS_WEB_8, or SEC_PHP_AIMS_WEB_9 to not RO
		SectionGetFlags ${SEC_PHP_AIMS_9} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 ^ ${SF_RO}
		SectionSetFlags ${SEC_PHP_AIMS_9} $0
		
		SectionGetFlags ${SEC_PHP_AIMS_WEB_8} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 ^ ${SF_RO}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_8} $0
		
		SectionGetFlags ${SEC_PHP_AIMS_WEB_9} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 ^ ${SF_RO}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_9} $0
	${Else} # if SEC_PHP is not selected:
		# Set SEC_PHP_AIMS_9, SEC_PHP_AIMS_WEB_8, or SEC_PHP_AIMS_WEB_9 to RO and unselected
		SectionGetFlags ${SEC_PHP_AIMS_9} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 | ${SF_SELECTED}
		IntOp $0 $0 ^ ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_9} $0
		
		SectionGetFlags ${SEC_PHP_AIMS_WEB_8} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 | ${SF_SELECTED}
		IntOp $0 $0 ^ ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_8} $0
		
		SectionGetFlags ${SEC_PHP_AIMS_WEB_9} $0
		IntOp $0 $0 | ${SF_RO}
		IntOp $0 $0 | ${SF_SELECTED}
		IntOp $0 $0 ^ ${SF_SELECTED}
		SectionSetFlags ${SEC_PHP_AIMS_WEB_9} $0
	${EndIf}

!macroend