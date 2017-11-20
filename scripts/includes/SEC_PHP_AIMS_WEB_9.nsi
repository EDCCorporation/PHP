DetailPrint "Adding AIMS Web 9.x support"
SetOutPath $PHPDIR
SetOverwrite on

# Install AIMS Web 9 Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.aimsweb9.ini"

# Install Mongo Library
SetOutPath "$PHPDIR\php.d"
File "${PHP_SOURCE}\php.d\php.mongodb.ini"
SetOutPath "$PHPDIR\ext"
File "${PHP_SOURCE}\ext\php_mongodb.dll"