DetailPrint "Adding AIMS 9 support"
SetOutPath $PHPDIR
SetOverwrite on

# Install AIMS 9 Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.aims9.ini"