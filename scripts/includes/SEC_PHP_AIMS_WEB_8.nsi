DetailPrint "Adding AIMS Web 8.x support"
SetOutPath $PHPDIR
SetOverwrite on

# Install AIMS Web 8 Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.aimsweb8.ini"