# Removal map

Exactly what `multiplicity-purge.bat` targets, and — just as important — what it refuses to touch.

## Services

| Service | Note |
|---|---|
| `SDMultiplicityService` | MP2/MP3 era service |
| `Multiplicity` | MP4-era service; this is the one that survives most uninstalls |
| `MultiSrv`, `MultiSrv64` | legacy service binaries |
| `SdDisplay` | display/remote-screen helper service |

Order matters: stop → kill processes → run vendor uninstaller if present → `sc delete` → clean keys.

## Processes killed first

`multipl.exe`, `multipl2.exe`, `MultiPLV64.exe`, `MP2Drag.exe`, `MP2Control.exe`, `MPBar.exe`,
`MultiplicityConfig.exe`, `MultiSrv.exe`, `MultiSrv64.exe`, `MPRDP64.exe`, `SdDisplay.exe`,
`DeElevate64.exe`, `Multiplicity.exe`.

They hold the service and the install directory open; deleting before killing them is why manual
cleanups usually fail halfway.

## Scheduled tasks

Any task whose **name contains** `Multiplicity`. Parsed from `schtasks /Query /FO CSV /NH` so that a
task path containing spaces or backslashes cannot be truncated into a false match.

## Directories

Under `Program Files`, `Program Files (x86)`, `ProgramData`, `%LOCALAPPDATA%` and `%APPDATA%`:

```
EdgeRunner\Multiplicity     EdgeRunner\Multiplicity2    EdgeRunner\Multiplicity3
Stardock\Multiplicity       Stardock\Multiplicity2      Stardock\Multiplicity3   Stardock\Multiplicity4
ProgramData\EdgeRunner\MP2  ProgramData\Stardock\MP2    ProgramData\Multiplicity3
ProgramData\MultiplicityTemp2
```

Plus two file-level cleanups inside Multiplicity's own data folder:

- `%ProgramData%\EdgeRunner\MPsessionData.ini`
- `Registrations\mp*.bin`, `Multiplicity*.bin`, `MP3*.bin` under `EdgeRunner\Registrations` and
  `Stardock\Registrations`

Only Multiplicity's own directories. A parent directory shared with other software (for example
`C:\Program Files (x86)\Stardock` itself) is **never** removed.

## Registry

Service keys (after `sc delete`, which can leave ghost entries):

```
HKLM\SYSTEM\CurrentControlSet\Services\{SDMultiplicityService,Multiplicity,SdDisplay,MultiSrv,MultiSrv64}
```

Product keys:

```
HKLM\Software\Stardock\Multiplicity        HKLM\Software\Stardock\Multiplicity2
HKLM\Software\Wow6432Node\Stardock\Multiplicity
HKLM\Software\Wow6432Node\Stardock\Multiplicity2
HKLM\Software\Wow6432Node\Stardock\Misc\Multiplicity
HKLM\Software\Wow6432Node\Stardock\Misc\Multiplicity2
HKLM\Software\Wow6432Node\Stardock\Misc\Multiplicity3
HKLM\Software\Wow6432Node\Stardock\ThinkDesk\Multiplicity
HKLM\Software\Wow6432Node\Stardock\ThinkDesk\Multiplicity2
HKLM\Software\Wow6432Node\Stardock\RemoteAudio
HKCU\Software\Stardock\Multiplicity2
```

Uninstall entries (their presence is what makes a reinstall think the product is still there):

```
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{Multiplicity,Multiplicity 4,Multiplicity3}
HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{Multiplicity,Multiplicity 4,Multiplicity3}
```

## Firewall rules

```
Stardock Multiplicity 2 / 3 / 4          Multiplicity Service
Stardock Multiplicity Application        Multiplicity Application (clipboard)
Stardock Multiplicity Application (clipboard)
Stardock Multiplicity Audio Service      Multiplicity Application (Remote screen control)
Stardock Multiplicity Clipboard          Multiplicity Audio Service
Stardock Multiplicity Service            Multiplicity Clipboard
                                         Multiplicity Remote Screen Service
```

## Deliberately NOT touched

| Thing | Why |
|---|---|
| `HKLM\SOFTWARE\Stardock` (the root) | Other Stardock products live there — Groupy, Fences, ObjectDock, Start11… Removing the root breaks them. |
| `HKLM\SOFTWARE\WOW6432Node\Stardock` (the root) | Same reason. |
| `HKCU\Software\Stardock` (the root) | Same reason. |
| Any other Stardock service or process | Out of scope by design. |
| Documents, downloads, licence files you own | Not ours to delete. |
| `C:\Program Files (x86)\Stardock` itself | Shared parent for other Stardock apps. |
| Network configuration, adapters, drivers | A remote-KVM product can leave driver-level traces; this script does not attempt driver surgery. |

If you also want the shared Stardock root gone, that is a manual decision — check what else is
installed first:

```cmd
reg query "HKLM\SOFTWARE\Stardock"
sc query type= service state= all | findstr /I stardock
```

## Planned, not implemented

- `--list-services` / `--list-tasks` machine-readable JSON output for provisioning pipelines.
- An MSI/EXE wrapper with a signed bundle, so it can run from Intune/SCCM.
- Windows 7/8 testing (untested; the script uses nothing newer than `sc.exe`/`schtasks`/`netsh`,
  so it will probably work, but "probably" is not a claim).
