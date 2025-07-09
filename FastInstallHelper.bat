@echo off
chcp 65001

:: متغیرها
set "tmpDir=%temp%\Installer"
set "logFile=%tmpDir%\install_log.txt"
set "download=powershell -Command Invoke-WebRequest -Uri"
set "pythonLibs=psutil requests"
set "requiredWinRarVersion=7.11"
set "requiredSublimeBuild=4200"
set "pythonDir="
set "pythonDirArg="
set "defaultPythonDir=%ProgramFiles%\Python"
set "useCurl=0"
set "defaultPythonUrl=https://www.python.org/ftp/python/3.13.4/python-3.13.4-amd64.exe"

:: ساخت پوشه موقت و لاگ
if not exist "%tmpDir%" (
    mkdir "%tmpDir%" >nul 2>&1
)
if not exist "%tmpDir%" (
    echo Failed to create temporary directory: %tmpDir%
    echo [%date% %time%] ERROR: Failed to create temp dir >>"%logFile%"
    pause
    exit /b
)
echo ----------- Run: %date% %time% ----------- >"%logFile%"

:: تابع لاگ‌نویسی
:Log
echo [%date% %time%] %~1 >>"%logFile%"
goto :eof

:: بررسی دسترسی PowerShell و curl
powershell -Command "exit 0" >nul 2>&1
if %errorlevel% neq 0 (
    curl --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo Neither PowerShell nor curl is available on this system!
        call :Log "ERROR: Neither PowerShell nor curl available."
        pause
        exit /b
    ) else (
        set "download=curl -L -o"
        set "useCurl=1"
        call :Log "PowerShell unavailable, using curl for downloads."
    )
) else (
    call :Log "PowerShell available, using Invoke-WebRequest."
)

:: بررسی دسترسی ادمین
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires Administrator privileges. Please run as Administrator!
    call :Log "ERROR: Not admin"
    pause
    exit /b
)

:: تست اتصال اینترنت
if %useCurl%==1 (
    curl -L -o "%tmpDir%\test.ico" "https://www.google.com/favicon.ico" >nul 2>&1
) else (
    %download% "https://www.google.com/favicon.ico" -OutFile "%tmpDir%\test.ico" >nul 2>&1
)
if not exist "%tmpDir%\test.ico" (
    echo Internet connection is not available!
    call :Log "ERROR: No internet connection."
    pause
    exit /b
)
del "%tmpDir%\test.ico" >nul 2>&1

:: پردازش آرگومان‌ها (نرم‌افزار و مسیر نصب Python)
set "DO_WINRAR=0"
set "DO_PYTHON=0"
set "DO_SUBLIME=0"
set "DO_FIREFOX=0"
set "DO_VLC=0"
set "pythonDir=%defaultPythonDir%"

for %%A in (%*) do (
    if /I "%%A"=="winrar" set "DO_WINRAR=1"
    if /I "%%A"=="python" set "DO_PYTHON=1"
    if /I "%%A"=="sublime" set "DO_SUBLIME=1"
    if /I "%%A"=="firefox" set "DO_FIREFOX=1"
    if /I "%%A"=="vlc" set "DO_VLC=1"
    echo %%A | findstr /I /C:"--pythondir=" >nul
    if not errorlevel 1 (
        for /f "tokens=2 delims==" %%B in ("%%A") do set "pythonDir=%%B"
        set "pythonDirArg=1"
    )
)
:: اگر هیچ نرم‌افزاری انتخاب نشده، همه را نصب کن
if %DO_WINRAR%==0 if %DO_PYTHON%==0 if %DO_SUBLIME%==0 if %DO_FIREFOX%==0 if %DO_VLC%==0 (
    set "DO_WINRAR=1"
    set "DO_PYTHON=1"
    set "DO_SUBLIME=1"
    set "DO_FIREFOX=1"
    set "DO_VLC=1"
)

:: نصب WinRAR
if %DO_WINRAR%==1 (
    call :Log "Checking WinRAR installation..."
    set "winRarInstalled=0"
    set "winRarVersion="
    set "licensePath="
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinRAR archiver" /v InstallLocation 2^>nul') do set "licensePath=%%b"
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinRAR archiver" /v DisplayVersion 2^>nul') do set "winRarVersion=%%a"
    if defined licensePath if defined winRarVersion (
        set "winRarInstalled=1"
        call :Log "WinRAR version %winRarVersion% found at %licensePath%."
    )
    if %winRarInstalled%==1 (
        if "%winRarVersion%" GEQ "%requiredWinRarVersion%" (
            echo WinRAR version %winRarVersion% already installed.
            call :Log "WinRAR version %winRarVersion% meets requirement."
            if exist "%licensePath%\rarreg.key" (
                call :Log "WinRAR already activated."
            ) else (
                call :ActivateWinRAR
            )
        ) else (
            call :InstallWinRAR
        )
    ) else (
        call :InstallWinRAR
    )
)

:InstallWinRAR
title Installing WinRAR ...
set "winRarUrl=https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-711.exe"
set "winRarTmp=%tmpDir%\winrar.exe"
call :Log "Downloading WinRAR..."
if %useCurl%==1 (
    %download% "%winRarTmp%" "%winRarUrl%"
) else (
    %download% "%winRarUrl%" -OutFile "%winRarTmp%"
)
if not exist "%winRarTmp%" (
    echo Failed to download WinRAR!
    call :Log "ERROR: WinRAR download failed."
    pause
    exit /b
)
"%winRarTmp%" /S
if %errorlevel% neq 0 (
    echo Failed to install WinRAR!
    call :Log "ERROR: WinRAR install failed."
    pause
    exit /b
) else (
    call :Log "WinRAR installed."
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinRAR archiver" /v InstallLocation 2^>nul') do set "licensePath=%%b"
    call :ActivateWinRAR
)
goto :eof

:ActivateWinRAR
if defined licensePath (
    >"%licensePath%\rarreg.key" (
        echo RAR registration data
        echo Hardik
        echo www.Hardik.live
        echo UID=448c4a899c6cdc1039c5
        echo 641221225039c585fc5ef8da12ccf689780883109587752a828ff0
        echo 59ae0579fe68942c97d160f361d16f96c8fe03f1f89c66abc25a37
        echo 7777a27ec82f103b3d8e05dcefeaa45c71675ca822242858a1c897
        echo c57d0b0a3fe7ac36c517b1d2be385dcc726039e5f536439a806c35
        echo 1e180e47e6bf51febac6eaae111343d85015dbd59ba45c71675ca8
        echo 2224285927550547c74c826eade52bbdb578741acc1565af60e326
        echo 6b5e5eaa169647277b533e8c4ac01535547d1dee14411061928023
    )
    call :Log "WinRAR activated."
) else (
    call :Log "ERROR: WinRAR install path not found."
)
goto :eof

:: نصب Python
if %DO_PYTHON%==1 (
    call :Log "Checking Python installation..."
    set "pythonBin="
    where python >nul 2>&1
    if %errorlevel%==0 (
        for /f "tokens=*" %%i in ('where python') do set "pythonBin=%%i"
        echo Python already installed at %pythonBin%.
        call :Log "Python already installed at %pythonBin%."
        call :CheckPythonLibs
    ) else (
        call :InstallPython
    )
)

:InstallPython
title Installing Python ...
if defined pythonDirArg (
    mkdir "%pythonDir%" >nul 2>&1
    if not exist "%pythonDir%" (
        echo Invalid Python installation directory: %pythonDir%
        call :Log "ERROR: Invalid Python directory."
        pause
        exit /b
    )
    echo Test > "%pythonDir%\test.txt" 2>nul
    if %errorlevel% neq 0 (
        echo No write permission for Python directory: %pythonDir%
        call :Log "ERROR: No write permission for Python directory."
        pause
        exit /b
    )
    del "%pythonDir%\test.txt" >nul 2>&1
)
set "pythonTmp=%tmpDir%\python.exe"
call :Log "Detecting Python version..."
if %useCurl%==1 (
    set "pythonUrl=%defaultPythonUrl%"
    call :Log "Using default Python version (3.13.4) with curl."
) else (
    powershell -Command ^
        "$p=(Invoke-RestMethod https://www.python.org/api/v2/downloads/release/?is_published=true).results | Where-Object { $_.name -match 'Python 3\.\d+\.\d+$' -and $_.is_published -eq $true } | Sort-Object -Descending -Property name; $v=$p[0]; $link=$v.files | Where-Object { $_.filename -like '*amd64.exe' -and $_.name -notlike '*web*' }; if ($link) { Write-Host $link.url }" > "%tmpDir%\pyurl.txt"
    set /p pythonUrl=<"%tmpDir%\pyurl.txt"
    if "%pythonUrl%"=="" (
        call :Log "ERROR: Could not find latest Python version, falling back to default."
        set "pythonUrl=%defaultPythonUrl%"
    )
)
call :Log "Downloading Python from %pythonUrl% ..."
if %useCurl%==1 (
    %download% "%pythonTmp%" "%pythonUrl%"
) else (
    %download% "%pythonUrl%" -OutFile "%pythonTmp%"
)
if not exist "%pythonTmp%" (
    echo Failed to download Python!
    call :Log "ERROR: Python download failed."
    pause
    exit /b
)
"%pythonTmp%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 TargetDir="%pythonDir%"
:waitForPython
set "pythonBin="
where python >nul 2>&1
if %errorlevel%==0 (
    for /f "tokens=*" %%i in ('where python') do set "pythonBin=%%i"
)
if not defined pythonBin (
    timeout /t 2 >nul
    goto :waitForPython
)
call :Log "Python installed at %pythonBin%."
call :CheckPythonLibs
goto :eof

:CheckPythonLibs
:: بررسی و آپدیت pip
setlocal enabledelayedexpansion
call :Log "Checking pip version..."
for /f "tokens=*" %%i in ('"%pythonBin%" -m pip --version') do set "pipVersion=%%i"
call :Log "Current pip version: %pipVersion%"
"%pythonBin%" -m pip install --upgrade pip >nul 2>&1
if %errorlevel% neq 0 (
    call :Log "WARNING: Failed to update pip."
) else (
    call :Log "Pip updated."
)
:: بررسی نصب قبلی کتابخانه‌ها و نصب فقط موارد لازم
set "missingLibs="
for %%L in (%pythonLibs%) do (
    "%pythonBin%" -c "import %%L" 2>nul
    if errorlevel 1 (
        set "missingLibs=!missingLibs! %%L"
    )
)
if defined missingLibs (
    call :Log "Installing Python libraries: !missingLibs!"
    "%pythonBin%" -m pip install!missingLibs!
    if %errorlevel% neq 0 (
        echo Failed to install Python libraries!
        call :Log "ERROR: Python libs install failed."
        endlocal
        pause
        exit /b
    ) else (
        call :Log "Python libraries installed."
    )
) else (
    call :Log "All required Python libraries already installed."
)
endlocal
goto :eof

:: نصب Sublime Text
if %DO_SUBLIME%==1 (
    call :Log "Checking Sublime Text installation..."
    set "sublimeInstalled=0"
    set "sublimeVersion="
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text*" /v DisplayVersion 2^>nul') do set "sublimeVersion=%%a"
    if defined sublimeVersion (
        set "sublimeInstalled=1"
        call :Log "Sublime Text build %sublimeVersion% found."
    )
    if %sublimeInstalled%==1 (
        if %sublimeVersion% GEQ %requiredSublimeBuild% (
            echo Sublime Text build %sublimeVersion% already installed.
            call :Log "Sublime Text build %sublimeVersion% meets requirement."
        ) else (
            call :InstallSublime
        )
    ) else (
        call :InstallSublime
    )
)

:InstallSublime
title Installing Sublime Text ...
set "sublimeTextUrl=https://download.sublimetext.com/sublime_text_build_4200_x64_setup.exe"
set "sublimeTextTmp=%tmpDir%\sublime_text.exe"
call :Log "Downloading Sublime Text..."
if %useCurl%==1 (
    %download% "%sublimeTextTmp%" "%sublimeTextUrl%"
) else (
    %download% "%sublimeTextUrl%" -OutFile "%sublimeTextTmp%"
)
if not exist "%sublimeTextTmp%" (
    echo Failed to download Sublime Text!
    call :Log "ERROR: Sublime download failed."
    pause
    exit /b
)
"%sublimeTextTmp%" /VERYSILENT /NORESTART
if %errorlevel% neq 0 (
    echo Failed to install Sublime Text!
    call :Log "ERROR: Sublime install failed."
    pause
    exit /b
) else (
    call :Log "Sublime Text installed."
    call :ActivateSublime
)
goto :eof

:ActivateSublime
set "sublimeTextPatchUrl=https://raw.githubusercontent.com/N1xUser/SublimeText-Patch/refs/heads/main/SublimeTextPatch.py"
set "sublimeTextPatchTmp=%tmpDir%\SublimeTextPatch.py"
call :Log "Downloading Sublime Patch..."
if %useCurl%==1 (
    %download% "%sublimeTextPatchTmp%" "%sublimeTextPatchUrl%"
) else (
    %download% "%sublimeTextPatchUrl%" -OutFile "%sublimeTextPatchTmp%"
)
if not exist "%sublimeTextPatchTmp%" (
    echo Failed to download Sublime Text patch!
    call :Log "ERROR: Sublime patch download failed."
    pause
    exit /b
)
if not defined pythonBin (
    where python >nul 2>&1
    if %errorlevel%==0 (
        for /f "tokens=*" %%i in ('where python') do set "pythonBin=%%i"
    )
)
if defined pythonBin (
    (
        echo 1
        echo yes
        echo no
    ) | "%pythonBin%" "%sublimeTextPatchTmp%"
    if %errorlevel% neq 0 (
        echo Failed to patch Sublime Text!
        call :Log "ERROR: Sublime patch failed."
        pause
        exit /b
    ) else (
        call :Log "Sublime Text patched."
    )
) else (
    echo Python not found for running Sublime Text patch!
    call :Log "ERROR: Python not found for Sublime patch."
    pause
    exit /b
)
goto :eof

:: نصب Firefox
if %DO_FIREFOX%==1 (
    call :Log "Checking Firefox installation..."
    reg query "HKLM\SOFTWARE\Mozilla\Mozilla Firefox" >nul 2>&1
    if %errorlevel%==0 (
        echo Firefox already installed.
        call :Log "Firefox already installed."
    ) else (
        title Installing Firefox ...
        set "firefoxUrl=https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
        set "firefoxTmp=%tmpDir%\firefox.exe"
        call :Log "Downloading Firefox..."
        if %useCurl%==1 (
            %download% "%firefoxTmp%" "%firefoxUrl%"
        ) else (
            %download% "%firefoxUrl%" -OutFile "%firefoxTmp%"
        )
        if not exist "%firefoxTmp%" (
            echo Failed to download Firefox!
            call :Log "ERROR: Firefox download failed."
            pause
            exit /b
        )
        "%firefoxTmp%" -ms
        if %errorlevel% neq 0 (
            echo Failed to install Firefox!
            call :Log "ERROR: Firefox install failed."
            pause
            exit /b
        ) else (
            call :Log "Firefox installed."
        )
    )
)

:: نصب VLC
if %DO_VLC%==1 (
    call :Log "Checking VLC installation..."
    reg query "HKLM\SOFTWARE\VideoLAN\VLC" >nul 2>&1
    if %errorlevel%==0 (
        echo VLC already installed.
        call :Log "VLC already installed."
    ) else (
        title Installing VLC ...
        set "vlcUrl=https://get.videolan.org/vlc/3.0.20/win64/vlc-3.0.20-win64.msi"
        set "vlcTmp=%tmpDir%\vlc.msi"
        call :Log "Downloading VLC..."
        if %useCurl%==1 (
            %download% "%vlcTmp%" "%vlcUrl%"
        ) else (
            %download% "%vlcUrl%" -OutFile "%vlcTmp%"
        )
        if not exist "%vlcTmp%" (
            echo Failed to download VLC!
            call :Log "ERROR: VLC download failed."
            pause
            exit /b
        )
        msiexec /i "%vlcTmp%" /quiet /norestart
        if %errorlevel% neq 0 (
            echo Failed to install VLC!
            call :Log "ERROR: VLC install failed."
            pause
            exit /b
        ) else (
            call :Log "VLC installed."
        )
    )
)

:: پاکسازی
title Cleaning Up ...
rd /s /q "%tmpDir%" >nul 2>&1
if exist "%tmpDir%" (
    echo Warning: Could not fully clean up temporary directory: %tmpDir%
    call :Log "WARNING: Temp dir not fully cleaned."
)
title Done
echo Installation completed successfully!
call :Log "Installation completed."
pause
