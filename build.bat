@echo off
setlocal EnableDelayedExpansion
set R2_BASE=""
if %PLATFORM% == x64 (set frida_os_arch=x86_64) else (set frida_os_arch=x86)
for /f %%i in ('radare2 -H R2_USER_PLUGINS') do set R2_PLUGDIR=%%i
for /f %%i in ('where radare2') do set R2_BASE=%%i\..\..
set DEBUG=/O2
set INSTALL=

if not exist %R2_BASE% (
	echo radare2 not found
	set /p R2_BASE="Please enter full path of radare2 installation: "
	set /p R2_PLUGDIR="Please enter full path of radare2 plugin dir (radare2 -H): "
)

set R2_INC=/I"%R2_BASE%\include" /I"%R2_BASE%\include\libr"

for %%i in (%*) do (
	if "%%i"=="debug" (set DEBUG=/Z7)
	if "%%i"=="install" (set INSTALL=1)
)

call npm install
cd src
cat .\_agent.js | xxd -i > .\_agent.h || (echo "xxd not in path?" & exit /b 1)

mkdir frida > nul 2>&1
cd frida

set frida_version=12.6.8
set FRIDA_SDK_URL="https://github.com/frida/frida/releases/download/%frida_version%/frida-core-devkit-%frida_version%-windows-%frida_os_arch%.exe"

if not exist ".\frida-core-sdk-%frida_version%-%frida_os_arch%.exe" (
	echo Downloading Frida Core Sdk
	
	powershell -command "(New-Object System.Net.WebClient).DownloadFile($env:FRIDA_SDK_URL, ""frida-core-sdk.exe-%frida_version%-%frida_os_arch%"")" ^
	|| wget -q --show-progress %FRIDA_SDK_URL% .\frida-core-sdk.exe -O .\frida-core-sdk-%frida_version%-%frida_os_arch%.exe
	
	echo Extracting...
	.\frida-core-sdk-%frida_version%-%frida_os_arch%.exe || (echo Failed to extract & exit /b 1)
)
cd ..

echo Compiling...
cl %DEBUG% /MT /nologo /LD /Gy /D_USRDLL /D_WINDLL /DWITH_CYLANG=0 io_frida.c %R2_INC% /I"%cd%" /I"%cd%\frida" "%cd%\frida\frida-core.lib" "%R2_BASE%\lib\*.lib" || (echo Compilation Failed & exit /b 1)

if not "%INSTALL%"=="" (
	echo Installing...
	mkdir "%R2_PLUGDIR%" > nul 2>&1
	echo Copying 'io_frida.dll' to %R2_PLUGDIR%
	cp io_frida.dll "%R2_PLUGDIR%\io_frida.dll"
	if not "%DEBUG%"=="/O2" (
		echo Copying 'io_frida.pdb' to %R2_PLUGDIR%
		cp io_frida.pdb "%R2_PLUGDIR%\io_frida.pdb"
	)
)
