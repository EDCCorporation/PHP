DetailPrint "Adding AIMS Web 8.x support"
SetOutPath $PHPDIR
SetOverwrite on

# Install AIMS Web 8 Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.aimsweb8.ini"

# Install Wincache Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.wincache.ini"
SetOutPath "$PHPDIR\ext"
File "${PHP_SOURCE}\ext\php_wincache.dll"