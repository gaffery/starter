$WISH_LOCAL = Split-Path -Parent $MyInvocation.MyCommand.Definition
#$WISH_LOCAL = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$WISH_PYTHON = (Get-ChildItem -Path "$WISH_LOCAL\packages\python" -Directory | Select-Object -Last 1).Name
$WISH_VERSION = (Get-ChildItem -Path "$WISH_LOCAL\packages\wish" -Directory | Select-Object -Last 1).Name

$env:WISH_PACKAGE_PATH = "$WISH_LOCAL\packages"
$env:WISH_STORAGE_PATH = "$WISH_LOCAL\caches"
$env:WISH_DEVELOP_PATH = "$WISH_LOCAL\develops"

$env:WISH_PACKAGE_ROOT = "$WISH_LOCAL\packages\python\$WISH_PYTHON"
$env:PATH = "$env:WISH_PACKAGE_ROOT\src;$env:PATH"
$env:WISH_PACKAGE_MODE = 1

$env:WISH_RESTAPI_URL = "http://wish.net:9527/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
$env:WISH_STORAGE_URL = "http://wish.net:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"
#$env:WISH_RESTAPI_URL = "http://47.120.50.74:9526/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
#$env:WISH_STORAGE_URL = "http://47.120.50.74:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $WISH_LOCAL\packages\wish\$WISH_VERSION\src\wish wish python - wish launcher - launcher" -WindowStyle Hidden
#ps2exe -inputFile "C:\Users\ADMIN\Documents\launcher.ps1" -outputFile "E:\WishTools\launcher.exe" -icon "C:\Users\ADMIN\Documents\launcher.ico" -noConsole