# Background: what Multiplicity is, and why it leaves residue

Knowing what the product installs is what makes a safe cleanup possible. This page is the research
behind the script — product, versions, on-disk architecture, network surface, and the specific
reasons an uninstall leaves things behind.

## The product

[Multiplicity](https://www.stardock.com/products/multiplicity/) is Stardock's KVM-style
input-sharing tool: **one keyboard and mouse across several PCs**, moving between machines by
pushing the cursor off the edge of the screen ("seamless"), plus a shared clipboard, audio
streaming from the secondary to the primary, file copy, and remote screen control. Current
marketing line: "Connect multiple PCs with one keyboard and mouse."

Two roles exist, and the distinction matters for cleanup:

| Role | What it does | Network behaviour |
|---|---|---|
| **Primary** | Owns the physical keyboard/mouse, pushes input to the others | listens; secondaries connect in |
| **Secondary** | Receives input; its screen/clipboard/audio are shared back | connects out to the primary |

A machine can be licensed and running a secondary with no primary present — which is exactly the
state that makes people wonder "am I even using this?"

## Version lines

- **Multiplicity 2 / 3** — the older line, originally from **EdgeRunner**. The installers and
  registry still carry `EdgeRunner\Multiplicity`, `EdgeRunner\Multiplicity2` paths and
  `ProgramData\EdgeRunner\MP2`, which is why a scrubber has to know both vendor names.
- **Multiplicity 4** — the current line (4.0.x, distributed on [Steam](https://www.stardock.com/blog/538320/multiplicity-4--now-available-on-steam)),
  rewritten around an **indirect display driver (IDD)**, per-user config, and a WPF configuration app.

Stardock's own [history wiki](https://wiki.stardocksoftware.com/index.php?title=Multiplicity_History)
is the canonical change log; the [Multiplicity 4 basics](https://www.stardock.com/news/531720/getting-started-with-multiplicity-4--the-basics)
article describes the current setup flow.

## What a Multiplicity 4 install actually puts on disk

Observed on a Windows 11 machine running **4.0.7.2** (`C:\Program Files (x86)\Stardock\Multiplicity`):

| Component | File | Role |
|---|---|---|
| Service | `MultiSrv64.exe` | The actual `Multiplicity` service (auto-start, `SERVICE_WIN32_OWN_PROCESS`) |
| Clipboard | `Multipl2_64.exe` | Clipboard sync between machines |
| Control/tray | `Mp2control_64.exe`, `MPBar.exe`, `MP32.exe`, `MP64.exe` | UI, hotkeys, screen-edge detection |
| Config UI | `MultiplicityConfig.exe` | WPF settings app (loads `Default.spak`) |
| Remote screen | `MPRDP*.exe`, `MPRDISP*.exe` | Remote desktop / screen-control feature |
| Display helper | `SdDisplay.exe` | Secondary display handling |
| Elevation | `DeElevate*.exe/.dll` | Runs user-facing parts unelevated |
| Virtual display | `MultiplicityIddDriver\` (+ `Driver64.exe`) | **Indirect display driver** installed at setup |
| Per-user data | `%LOCALAPPDATA%\Stardock\Multiplicity\SasLog.txt` | Stardock App Services log |
| Machine data | `C:\ProgramData\Stardock\Multiplicity\License.sig` | Signed licence |
| Session data | `C:\ProgramData\Stardock\MPsessionData.ini` | `RefCount` of active session |
| Config | `HKLM\Software\Stardock\Multiplicity2\MP\MP` | Flags incl. `Primary`, `InitialSetupDone` |

The `.tmp` files next to the binaries (`suf*.tmp`) are Stardock's self-updater staging leftovers.

## Network surface

Multiplicity binds five TCP ports. The firewall rule names make the mapping unambiguous
(verified with `Get-NetFirewallRule` on a live install):

| Port | Firewall rule | Purpose |
|---|---|---|
| **30564** | Multiplicity Service | Main control channel |
| **30565** | Multiplicity Clipboard | Clipboard sync |
| **30567** | Multiplicity Audio Service | Audio streaming |
| **30568** | Multiplicity Service | Secondary/alternate service channel |
| **30569** | Multiplicity Remote Screen Service | Remote screen control |

Stardock documents the port set in [Multiplicity Ports](https://support.stardock.com/space/SHC/1345028118/Multiplicity+Ports).
Each *feature* creates its own rule — and each reinstall tends to create another copy, which is why
a used machine can accumulate several duplicate `Multiplicity Application (main)` rules.

A live primary↔secondary session looks like this (`netstat -ano`, secondary side):

```
TCP  192.168.1.18:59754  192.168.1.13:30564  ESTABLISHED  Mp2control_64
TCP  192.168.1.18:30567  192.168.1.13:49225  ESTABLISHED  MultiSrv64
```

## Why an uninstall leaves residue

1. **The service is auto-start and self-protecting.** If the uninstaller fails to stop it, the
   running `MultiSrv64.exe` holds its own directory open — so `rmdir` fails, and the folder survives
   with the service binary inside.
2. **The IDD is a driver, not a file.** Driver packages are registered in the driver store, so
   deleting the folder leaves a registered package behind.
3. **Firewall rules are per install, per feature.** They are not named deterministically and are
   not all removed by the uninstaller.
4. **Ghost service keys.** `sc delete` can remove the service entry while
   `HKLM\SYSTEM\CurrentControlSet\Services\Multiplicity` remains, which makes later installers think
   the product is still present.
5. **Two vendor names.** Anything that searches only for "Stardock" misses `EdgeRunner`, and vice
   versa.

Stardock has a support article for the symptom this produces — the service failing or crashing
after an upgrade or partial uninstall ([service is failing / crashing](https://stardock.atlassian.net/wiki/exportword?pageId=1603633157)).

## Should you purge at all?

Run `purge-multiplicity.bat --status` first. It prints the version, service state, role flag, bound
ports, live peers, firewall rules and licence presence — read-only.

- **`Primary=0x1`** → this PC is a primary; other machines depend on it. Purging disconnects them.
- **`Primary=0x0` with an established peer on :30564** → this PC is a secondary currently driven by
  another machine. Purging kills that link mid-session.
- **`Primary=0x0` with no peers** → installed, licensed, idle. This is the case where a purge is a
  pure cleanup with no functional loss — and the case this tool was written for.

If you still use Multiplicity, **don't purge**. Uninstall from Settings → Apps first, reboot, then
purge only if leftovers remain.
