@echo off
setlocal EnableExtensions EnableDelayedExpansion
title multiplicity-purge

:: ===========================================================================
::  multiplicity-purge  -  unofficial cleaner for Stardock / EdgeRunner
::                         Multiplicity 2 / 3 / 4 leftovers
::
::  Author : miztizm
::  License: MIT
::  Source : https://github.com/miztizm/multiplicity-purge
::
::  Why this exists: the official uninstaller regularly leaves the service,
::  ghost registry keys, firewall rules and ProgramData behind. This removes
::  those leftovers. Every destructive action goes through one guarded helper,
::  so --dry-run can never touch the machine.
::
::  Usage: multiplicity-purge.bat [--dry-run] [--status] [--yes] [--no-pause] [--log PATH]
::         multiplicity-purge.bat --help
:: ===========================================================================

set "APP=multiplicity-purge"
set "VER=2.1.0"
set "AUTHOR=miztizm"

set "DRY=0"
set "ASSUME=0"
set "NOPAUSE=0"
set "STATUS=0"
set "REBOOT_PROMPT=1"
set "LOG=%TEMP%\multiplicity-purge.log"
set "REMOVED=0"
set "SKIPPED=0"
set "FAILED=0"
set "LOGWRITTEN=0"

:: ---------------------------------------------------------------- arguments
:parse
if "%~1"=="" goto args_done
if /I "%~1"=="--help"      goto usage
if /I "%~1"=="-h"          goto usage
if /I "%~1"=="/?"          goto usage
if /I "%~1"=="--dry-run"   ( set "DRY=1" & shift & goto parse )
if /I "%~1"=="-n"          ( set "DRY=1" & shift & goto parse )
if /I "%~1"=="--status"    ( set "STATUS=1" & shift & goto parse )
if /I "%~1"=="-s"          ( set "STATUS=1" & shift & goto parse )
if /I "%~1"=="--yes"       ( set "ASSUME=1" & shift & goto parse )
if /I "%~1"=="-y"          ( set "ASSUME=1" & shift & goto parse )
if /I "%~1"=="--no-pause"  ( set "NOPAUSE=1" & set "REBOOT_PROMPT=0" & shift & goto parse )
if /I "%~1"=="--no-reboot" ( set "REBOOT_PROMPT=0" & shift & goto parse )
if /I "%~1"=="--log"       ( set "LOG=%~2" & shift & shift & goto parse )
echo Unknown option: %~1
echo.
goto usage

:args_done
if "%LOG%"=="" set "LOG=%TEMP%\multiplicity-purge.log"
if "%STATUS%"=="1" goto status_mode

:: ------------------------------------------------------------------ startup
echo ===========================================================================
echo  %APP% v%VER%   by %AUTHOR%
echo  Unofficial. Not affiliated with Stardock or EdgeRunner.
echo ===========================================================================
echo.

if "%DRY%"=="1" (
  echo  MODE: DRY RUN - nothing will be changed, stopped or deleted.
) else (
  echo  MODE: LIVE - services, files and registry keys will be removed.
)
echo.

:: --------------------------------------------------------------- elevation
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  if "%DRY%"=="1" (
    echo  Note: not elevated. A dry run does not need admin rights.
  ) else (
    echo  Admin rights are required for the live run. Relaunching elevated...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
      echo  Elevation was refused or failed. Aborting.
      if "%NOPAUSE%"=="0" pause
      exit /b 2
    )
    exit /b 0
  )
)

call :log "=== %APP% v%VER% started ==="
call :log "mode: DRY=%DRY% ASSUME=%ASSUME%"

:: ------------------------------------------------------------- confirmation
if "%DRY%"=="1" goto confirm_skipped
if "%ASSUME%"=="1" goto confirm_skipped

echo  This will remove, if present:
echo    - the Multiplicity services and their driver entries
echo    - running Multiplicity processes
echo    - scheduled tasks whose name contains "Multiplicity"
echo    - Program Files / ProgramData / AppData folders left behind
echo    - Multiplicity registry keys, including the Uninstall entries
echo    - Multiplicity firewall rules
echo.
echo  There is no undo. Create a restore point first if you are unsure.
echo  Tip: run with --dry-run to see the exact list without changing anything.
echo.
set "CONFIRM="
set /p "CONFIRM=Type PURGE to continue, or press Enter to abort: "
if /I not "%CONFIRM%"=="PURGE" goto confirm_abort
echo.
goto confirm_done

:confirm_abort
echo.
echo  Aborted. Nothing was changed.
if "%NOPAUSE%"=="0" pause
exit /b 1

:confirm_skipped
:confirm_done

:: =============================================================== the purge
echo [1/9] Stopping services...
for %%S in (
  "SDMultiplicityService" "Multiplicity" "MultiSrv" "MultiSrv64" "SdDisplay"
  "Stardock Multiplicity Service" "Stardock Multiplicity Audio Service"
) do call :StopService %%S

echo [2/9] Ending processes...
for %%P in (
  multipl.exe multipl2.exe Multipl2_64.exe Multipl2_A64.exe MultiPLV64.exe MultiPLVA64.exe
  MP2Drag.exe MP2Control.exe Mp2control_64.exe Mp2control_A64.exe MPBar.exe MP32.exe MP64.exe
  MultiplicityConfig.exe EventFilter.exe
  MultiSrv.exe MultiSrv32.exe MultiSrv64.exe MultiSrvA64.exe
  MPRDP.exe MPRDP64.exe MPRDISP.exe MPRDISP64.exe
  SdDisplay.exe DeElevate.exe DeElevate64.exe Multiplicity.exe
) do call :KillProc %%P

echo [3/9] Removing scheduled tasks...
for %%T in ("Multiplicity" "Stardock Multiplicity" "SD Multiplicity") do call :DelTasksMatching %%T

echo [4/9] Running legacy service uninstallers (if present)...
for %%D in (
  "C:\Program Files (x86)\EdgeRunner\Multiplicity"
  "C:\Program Files\EdgeRunner\Multiplicity"
  "C:\Program Files (x86)\EdgeRunner\Multiplicity2"
  "C:\Program Files\EdgeRunner\Multiplicity2"
  "C:\Program Files (x86)\Stardock\Multiplicity"
  "C:\Program Files\Stardock\Multiplicity"
  "C:\Program Files (x86)\Stardock\Multiplicity2"
  "C:\Program Files\Stardock\Multiplicity2"
) do (
  call :RunUninstaller "%%~D\Multisrv64.exe"
  call :RunUninstaller "%%~D\Multisrv.exe"
)

echo [5/9] Deleting service entries...
for %%S in (
  "SDMultiplicityService" "Multiplicity" "MultiSrv" "MultiSrv64" "SdDisplay"
) do call :DelService %%S

echo [6/9] Removing directories...
for %%D in (
  "C:\Program Files (x86)\EdgeRunner\Multiplicity"
  "C:\Program Files\EdgeRunner\Multiplicity"
  "C:\Program Files (x86)\EdgeRunner\Multiplicity2"
  "C:\Program Files\EdgeRunner\Multiplicity2"
  "C:\Program Files (x86)\Stardock\Multiplicity"
  "C:\Program Files\Stardock\Multiplicity"
  "C:\Program Files (x86)\Stardock\Multiplicity2"
  "C:\Program Files\Stardock\Multiplicity2"
  "C:\Program Files (x86)\Stardock\Multiplicity4"
  "C:\Program Files\Stardock\Multiplicity4"
  "C:\ProgramData\EdgeRunner\MP2"
  "C:\ProgramData\Stardock\MP2"
  "C:\ProgramData\EdgeRunner\Multiplicity"
  "C:\ProgramData\EdgeRunner\Multiplicity3"
  "C:\ProgramData\Multiplicity3"
  "C:\ProgramData\MultiplicityTemp2"
  "%LocalAppData%\Stardock\Multiplicity"
  "%LocalAppData%\Stardock\Multiplicity2"
  "%LocalAppData%\Stardock\Multiplicity3"
  "%LocalAppData%\EdgeRunner\Multiplicity"
  "%LocalAppData%\EdgeRunner\Multiplicity2"
  "%LocalAppData%\EdgeRunner\Multiplicity3"
  "%AppData%\Stardock\Multiplicity"
  "%AppData%\Stardock\Multiplicity2"
  "%AppData%\Stardock\Multiplicity3"
  "%AppData%\EdgeRunner\Multiplicity"
  "%AppData%\EdgeRunner\Multiplicity2"
  "%AppData%\EdgeRunner\Multiplicity3"
) do call :RmDir "%%~D"

call :DelFile "%ProgramData%\EdgeRunner\MPsessionData.ini"
for %%M in (
  "C:\ProgramData\EdgeRunner\Registrations\mp2sig*.bin"
  "%ProgramData%\Stardock\Registrations\mp*.*"
  "%ProgramData%\EdgeRunner\Registrations\Multiplicity*.bin"
  "%ProgramData%\EdgeRunner\Registrations\MP3*.bin"
) do call :DelMask %%M

echo [7/9] Cleaning registry...
for %%K in (
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\RemoteAudio"
  "HKEY_CURRENT_USER\Software\Stardock\Multiplicity2"
  "HKEY_LOCAL_MACHINE\Software\Stardock\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\Misc\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\ThinkDesk\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Stardock\Multiplicity2"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\Misc\Multiplicity2"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\Multiplicity2"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\ThinkDesk\Multiplicity2"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Stardock\Misc\Multiplicity3"
  "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity 4"
  "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity3"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity 4"
  "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Multiplicity3"
  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SDMultiplicityService"
  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Multiplicity"
  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SdDisplay"
  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MultiSrv"
  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MultiSrv64"
) do call :RegDel %%K

echo [8/9] Removing firewall rules...
for %%R in (
  "Stardock Multiplicity 2"
  "Stardock Multiplicity 3"
  "Stardock Multiplicity 4"
  "Stardock Multiplicity Application"
  "Stardock Multiplicity Application (clipboard)"
  "Stardock Multiplicity Audio Service"
  "Stardock Multiplicity Clipboard"
  "Stardock Multiplicity Service"
  "Multiplicity Application (clipboard)"
  "Multiplicity Application (Remote screen control)"
  "Multiplicity Audio Service"
  "Multiplicity Clipboard"
  "Multiplicity Remote Screen Service"
  "Multiplicity Service"
) do call :DelFirewall %%R

echo [9/9] Verifying leftovers...
call :Verify

:: ------------------------------------------------------------------ summary
echo.
echo ---------------------------------------------------------------------------
if "%DRY%"=="1" goto summary_dry
echo  Done.  Removed: !REMOVED!   Skipped: !SKIPPED!   Failed: !FAILED!
goto summary_state_done
:summary_dry
echo  Dry run finished. Nothing was changed.
echo  Actions that WOULD run: !REMOVED!   Skipped: !SKIPPED!   Would fail: !FAILED!
:summary_state_done
echo  Log: "%LOG%"
echo ---------------------------------------------------------------------------
call :log "=== finished: removed=!REMOVED! skipped=!SKIPPED! failed=!FAILED! ==="

if not "%REBOOT_PROMPT%"=="1" goto no_reboot
if "%DRY%"=="1" goto reboot_skip
echo.
choice /C YN /N /M "  Reboot now to finish the purge? [Y/N] "
if errorlevel 2 goto reboot_skip
echo  Rebooting in 10 seconds. Run "shutdown /a" to cancel.
shutdown /r /t 10 /c "multiplicity-purge: finishing cleanup"
goto no_reboot

:reboot_skip
echo.
echo  Reboot skipped. Reboot manually to finish the purge.

:no_reboot

if "%NOPAUSE%"=="0" pause
if "!FAILED!"=="0" exit /b 0
exit /b 3

:: ============================================================ helpers ======
:: Every mutating action lives below. Each starts with the DRY guard, so a
:: dry run is structurally incapable of touching the machine.

:StopService
set "SVC=%~1"
sc.exe query "%SVC%" >nul 2>&1
if not "!errorlevel!"=="0" ( call :Skip "service %SVC% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "stop service %SVC%" & exit /b 0 )
echo   stopping service "%SVC%"
call :log "stop service %SVC%"
net stop "%SVC%" /y >>"%LOG%" 2>&1
sc.exe stop "%SVC%" >>"%LOG%" 2>&1
call :Count ok
exit /b 0

:DelService
set "SVC=%~1"
sc.exe query "%SVC%" >nul 2>&1
if not "!errorlevel!"=="0" ( call :Skip "service %SVC% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "delete service %SVC%" & exit /b 0 )
echo   deleting service "%SVC%"
call :log "sc delete %SVC%"
sc.exe delete "%SVC%" >>"%LOG%" 2>&1
if "!errorlevel!"=="0" ( call :Count ok ) else ( call :Count fail )
exit /b 0

:KillProc
set "PROC=%~1"
tasklist /FI "IMAGENAME eq %PROC%" 2>nul | find /I "%PROC%" >nul
if not "!errorlevel!"=="0" ( call :Skip "process %PROC% (not running)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "kill process %PROC%" & exit /b 0 )
echo   ending process "%PROC%"
call :log "taskkill %PROC%"
taskkill /F /T /IM "%PROC%" >>"%LOG%" 2>&1
if "!errorlevel!"=="0" ( call :Count ok ) else ( call :Count fail )
exit /b 0

:RunUninstaller
set "EXE=%~1"
if not exist "%EXE%" ( call :Skip "uninstaller %EXE% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "run %EXE% -uninstall" & exit /b 0 )
echo   running "%EXE%" -uninstall
call :log "run %EXE% -uninstall"
"%EXE%" -uninstall >>"%LOG%" 2>&1
call :Count ok
exit /b 0

:RmDir
set "DIR=%~1"
if not exist "%DIR%" ( call :Skip "dir %DIR% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "remove dir %DIR%" & exit /b 0 )
echo   removing "%DIR%"
call :log "rmdir /S /Q %DIR%"
rmdir /S /Q "%DIR%" >>"%LOG%" 2>&1
if exist "%DIR%" ( call :Count fail ) else ( call :Count ok )
exit /b 0

:DelFile
set "FILE=%~1"
if not exist "%FILE%" ( call :Skip "file %FILE% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "delete file %FILE%" & exit /b 0 )
echo   deleting "%FILE%"
call :log "del %FILE%"
del /F /Q "%FILE%" >>"%LOG%" 2>&1
if exist "%FILE%" ( call :Count fail ) else ( call :Count ok )
exit /b 0

:DelMask
set "MASK=%~1"
set "HIT=0"
for %%F in ("%MASK%") do (
  if exist "%%~fF" (
    set "HIT=1"
    if "%DRY%"=="1" (
      call :Would "delete file %%~fF"
    ) else (
      echo   deleting "%%~fF"
      call :log "del %%~fF"
      del /F /Q "%%~fF" >>"%LOG%" 2>&1
      if exist "%%~fF" ( call :Count fail ) else ( call :Count ok )
    )
  )
)
if "!HIT!"=="0" call :Skip "files %MASK% (none)"
exit /b 0

:RegDel
set "KEY=%~1"
reg query "!KEY!" >nul 2>&1
if not "!errorlevel!"=="0" ( call :Skip "reg !KEY! (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "delete reg !KEY!" & exit /b 0 )
echo   deleting reg "!KEY!"
call :log "reg delete !KEY!"
reg delete "!KEY!" /f >>"%LOG%" 2>&1
if "!errorlevel!"=="0" ( call :Count ok ) else ( call :Count fail )
exit /b 0

:DelTasksMatching
set "TOKEN=%~1"
set "FOUND=0"
:: CSV/NH gives one task per line, name as the first quoted field, so a space or
:: backslash inside a task path can never shift the parse. (The old /FO LIST
:: parse split on spaces and matched almost every Windows task.)
for /f "tokens=1 delims=," %%A in ('schtasks /Query /FO CSV /NH 2^>nul') do (
  set "TN=%%~A"
  if not "!TN!"=="" (
    echo(!TN!| findstr /I /C:"!TOKEN!" >nul
    if "!errorlevel!"=="0" (
      set "FOUND=1"
      if "%DRY%"=="1" (
        call :Would "delete scheduled task !TN!"
      ) else (
        echo   deleting task "!TN!"
        call :log "schtasks /Delete /TN !TN!"
        schtasks /Delete /TN "!TN!" /F >>"%LOG%" 2>&1
        if "!errorlevel!"=="0" ( call :Count ok ) else ( call :Count fail )
      )
    )
  )
)
if "!FOUND!"=="0" call :Skip "tasks matching %TOKEN% (none)"
exit /b 0

:DelFirewall
set "RULE=%~1"
netsh advfirewall firewall show rule name="%RULE%" >nul 2>&1
if not "!errorlevel!"=="0" ( call :Skip "firewall rule %RULE% (absent)" & exit /b 0 )
if "%DRY%"=="1" ( call :Would "delete firewall rule %RULE%" & exit /b 0 )
echo   removing firewall rule "%RULE%"
call :log "firewall delete %RULE%"
netsh advfirewall firewall delete rule name="%RULE%" >>"%LOG%" 2>&1
call :Count ok
exit /b 0

:: ------------------------------------------------------------- bookkeeping
:Would
set /a REMOVED+=1
echo   [dry-run] would %~1
call :log "[dry-run] would %~1"
exit /b 0

:Skip
set /a SKIPPED+=1
call :log "skip: %~1"
exit /b 0

:Count
if /I "%~1"=="ok" ( set /a REMOVED+=1 ) else ( set /a FAILED+=1 )
exit /b 0

:log
if "%LOG%"=="" exit /b 0
>>"%LOG%" echo [%DATE% %TIME%] %~1
exit /b 0

:Verify
set "LEFT=0"
for %%S in ("SDMultiplicityService" "Multiplicity" "MultiSrv" "MultiSrv64" "SdDisplay") do (
  sc.exe query %%~S >nul 2>&1
  if "!errorlevel!"=="0" (
    echo   checking service %%~S ... leftover
    set /a LEFT+=1
  )
)
for %%D in (
  "C:\Program Files (x86)\Stardock\Multiplicity"
  "C:\Program Files\Stardock\Multiplicity"
  "C:\Program Files (x86)\Stardock\Multiplicity2"
  "C:\Program Files\Stardock\Multiplicity2"
  "C:\ProgramData\Stardock\MP2"
  "C:\ProgramData\EdgeRunner\MP2"
) do (
  if exist "%%~D" (
    echo   checking dir %%~D ... leftover
    set /a LEFT+=1
  )
)
if "%DRY%"=="1" goto verify_dry
if "!LEFT!"=="0" goto verify_clean
echo   !LEFT! leftover(s) still present - a reboot may release locked files.
goto verify_done

:verify_clean
echo   no leftovers detected.
goto verify_done

:verify_dry
echo   verification is only meaningful after a live run.

:verify_done
call :log "verify leftovers=!LEFT!"
exit /b 0

:: ================================================================== status ==
:: Read-only. Answers: is it installed, and what is this PC doing with it?
:status_mode
echo.
echo  --- status ---------------------------------------------------------------
set "VERSTR=(not installed)"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Stardock Multiplicity" /v DisplayVersion 2^>nul ^| findstr /I "DisplayVersion"') do set "VERSTR=%%B"
echo   version     : !VERSTR!

sc.exe query Multiplicity >nul 2>&1
if not "!errorlevel!"=="0" goto status_nosvc
for /f "tokens=3,4" %%A in ('sc.exe query Multiplicity ^| findstr /I "STATE"') do echo   service     : %%B
echo   service exe : C:\Program Files (x86)\Stardock\Multiplicity\Multisrv64.exe
goto status_role

:status_nosvc
echo   service     : not present

:status_role
set "PRIM=(unknown)"
for /f "tokens=3" %%A in ('reg query "HKLM\Software\Stardock\Multiplicity2\MP\MP" /v Primary 2^>nul ^| findstr /I "Primary"') do set "PRIM=%%A"
echo   role flag   : Primary=!PRIM!
if /I "!PRIM!"=="0x0" echo   interpreted : SECONDARY - another PC drives this one's keyboard and mouse
if /I "!PRIM!"=="0x1" echo   interpreted : PRIMARY   - this PC shares its input out to secondary PCs

echo   listening   :
set "LSN=0"
for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr /R ":3056[0-9]" ^| findstr /I "LISTENING"') do (
  set "LSN=1"
  echo    %%L
)
if "!LSN!"=="0" echo    (none)

echo   peers       :
set "PEER=0"
for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr /R ":3056[0-9]" ^| findstr /I "ESTABLISHED"') do (
  set "PEER=1"
  echo    %%L
)
if "!PEER!"=="0" echo    (none - no peer connected right now)

set "FW=0"
for %%R in ("Multiplicity Service" "Multiplicity Clipboard" "Multiplicity Audio Service" "Multiplicity Remote Screen Service") do (
  netsh advfirewall firewall show rule name=%%R >nul 2>&1
  if "!errorlevel!"=="0" set /a FW+=1
)
echo   firewall    : !FW! of 4 feature rules present
echo   (service / clipboard / audio / remote-screen; absence means that feature is off)

set "LIC=absent"
if exist "C:\ProgramData\Stardock\Multiplicity\License.sig" set "LIC=present"
echo   license     : !LIC!
set "IDD=absent"
if exist "C:\Program Files (x86)\Stardock\Multiplicity\MultiplicityIddDriver" set "IDD=present"
echo   idd driver  : !IDD! (indirect display driver, MP4)
set "UNINST=absent"
if exist "C:\Program Files (x86)\Stardock\Multiplicity\uninstall.exe" set "UNINST=present"
echo   uninstaller : !UNINST!
echo ---------------------------------------------------------------------------
echo  Nothing was changed. Use --dry-run to see what a purge would remove.
exit /b 0

:usage
echo.
echo %APP% v%VER% - remove Stardock / EdgeRunner Multiplicity 2/3/4 leftovers
echo.
echo   multiplicity-purge.bat [options]
echo.
echo   --dry-run, -n    show what would be removed; change nothing (safe, no admin needed)
echo   --status, -s     report what is installed and how this PC is using it; change nothing
echo   --yes, -y        skip the interactive PURGE confirmation (for scripting)
echo   --no-pause       do not wait for a keypress at the end
echo   --no-reboot      do not offer to reboot at the end
echo   --log PATH       write the log somewhere else (default: %%TEMP%%\multiplicity-purge.log)
echo   --help, -h       this text
echo.
echo   Examples:
echo     multiplicity-purge.bat --dry-run
echo     multiplicity-purge.bat
echo     multiplicity-purge.bat --yes --no-reboot
echo.
echo   No undo. Create a restore point first. MIT licensed. Not affiliated with
echo   Stardock or EdgeRunner.
echo.
exit /b 0
