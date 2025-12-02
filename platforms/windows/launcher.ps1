# $WISH_LOCAL = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WISH_LOCAL = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$WISH_PYTHON = (Get-ChildItem -Path "$WISH_LOCAL\packages\python" -Directory | Select-Object -Last 1).Name
$WISH_VERSION = (Get-ChildItem -Path "$WISH_LOCAL\packages\wish" -Directory | Select-Object -Last 1).Name

$env:WISH_STORAGE_PATH = "$WISH_LOCAL\caches"
$env:WISH_DEVELOP_PATH = "$WISH_LOCAL\develops"
$env:WISH_PACKAGE_PATH = "$WISH_LOCAL\packages"

$env:WISH_OFFLINE_MODE = 1

$env:WISH_PACKAGE_ROOT = "$WISH_LOCAL\packages\python\$WISH_PYTHON"
$env:PATH = "$env:WISH_PACKAGE_ROOT\src;$env:PATH"
$env:WISH_RESTAPI_URL = "http://wish.net:9527/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
$env:WISH_STORAGE_URL = "http://wish.net:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"

#$env:WISH_RESTAPI_URL = "http://47.120.50.74:9527/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
#$env:WISH_STORAGE_URL = "http://47.120.50.74:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"

if ($Args.Count -gt 0) {
    $env:WISH_OFFLINE_MODE = 0
}
$PassthruArgString = $Args -join ' '
$WishExecutable = "$WISH_LOCAL\packages\wish\$WISH_VERSION\src\wish"
$WishCommandFull = " wish - wish $PassthruArgString launcher - launcher"
Start-Process -FilePath "cmd.exe" -ArgumentList "/k $WishExecutable $WishCommandFull" -WindowStyle Hidden
#ps2exe -inputFile "C:\Users\ADMIN\Documents\launcher.ps1" -outputFile "D:\WishTools\launcher.exe" -icon "C:\Users\ADMIN\Documents\launcher.ico" -noConsole