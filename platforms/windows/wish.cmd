@echo off

rem set "WISH_LOCAL=%~dp0"
set "WISH_LOCAL=E:\WishTools\"
set "WISH_PYTHON="
for /d %%i in ("%WISH_LOCAL%packages\python\*") do (
    set "WISH_PYTHON=%%~nxi"
)
set "WISH_VERSION="
for /d %%i in ("%WISH_LOCAL%packages\wish\*") do (
    set "WISH_VERSION=%%~nxi"	
)
set "WISH_PACKAGE_PATH=%WISH_LOCAL%packages"
set "WISH_STORAGE_PATH=%WISH_LOCAL%caches"
set "WISH_DEVELOP_PATH=%WISH_LOCAL%develops"

set "WISH_PACKAGE_ROOT=%WISH_LOCAL%packages\python\%WISH_PYTHON%"
set "PATH=%WISH_PACKAGE_ROOT%\src;%PATH%"
set "WISH_PACKAGE_MODE=0"

set "WISH_RESTAPI_URL=http://wish.net:9527/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
set "WISH_STORAGE_URL=http://wish.net:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"

rem set "WISH_RESTAPI_URL=http://47.120.50.74:9526/graphs?access=AKIAI44QH8DHBEXAMPLE&secret=je7MtGbClwBF02Zp9Utk0h3yCo8nvbEXAMPLEKEY"
rem set "WISH_STORAGE_URL=http://47.120.50.74:9000/storage?access=y7ZTrqZcJbl17FHt5bUb&secret=EpqF6UtVwR05lYbvNejTkdAwXX1ZvA4slq7rjZHn"

call "%WISH_LOCAL%packages\wish\%WISH_VERSION%\src\wish" wish - wish %*
