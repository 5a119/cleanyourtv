# LG webOS launcher

A clean LG TV home screen with a static blue/teal background, purple accents,
YouTube, iPhone Screen Mirroring (AirPlay), and an Apps shortcut. Other installed
apps can be shown by editing `app/config.js`.

This folder adapts [OmkarK97/webos-vibehack](https://github.com/OmkarK97/webos-vibehack),
the webOS port of [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv).
The parent repository's Android APK and ADB debloat tools do not apply to LG webOS.
No root, firmware modification, or system-package disabling is performed here.

Verified on an LG 75QNED90UQA, webOS SDK 7.6.0, firmware 04.60.90.
Later firmware may behave differently.

## Requirements

- LG TV with Developer Mode enabled and its session kept valid.
- A computer on the same local network; wired Ethernet on the TV works.
- Node.js/npm and Python 3. Install dependencies inside a local virtual environment.
- For Home-button and wake redirection, the computer must remain awake and connected.

**Keep Developer Mode on.** LG removes developer-installed apps when Developer Mode
is disabled. Extend its session before expiry in the Developer Mode app. See
[LG's instructions](https://webostv.developer.lge.com/develop/getting-started/developer-mode-app).

## Windows setup

Open PowerShell in this `webos` folder:

```powershell
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
$env:TV_HOST = Read-Host 'TV IP address'
npx.cmd -y -p @webos-tools/cli ares-setup-device -a lgtv -i "{'host':'$env:TV_HOST','port':'9922','username':'prisoner'}"
npx.cmd -y -p @webos-tools/cli ares-novacom --device lgtv --getkey
```

Enable Key Server in the TV's Developer Mode app before getting the key. Enter its
passphrase when prompted. If ares reports authentication failure, configure the
device profile's private key (`lgtv_webos`) and passphrase using `ares-setup-device`.
Keep those credentials in the CLI's local device profile, outside this repository.

Install and open the launcher:

```powershell
.\install.ps1 -TvHost $env:TV_HOST
```

Accept the TV's remote-control pairing prompt on the first app sync. Re-run the
installer after adding or removing TV apps. It reads the app inventory, downloads
icons, creates the launcher icons, builds an IPK, installs it, and opens the launcher.
AirPlay is included from the native app inventory even though LG hides its launch
point. It uses a bundled SVG icon because its native icon URL can return HTTP 404.

## Home button and wake-up

webOS retains LG's own Home button. The companion watcher subscribes to foreground
and power-state events and opens the launcher after LG Home appears or the TV wakes.
It cannot redirect Home while the companion computer is asleep or disconnected.

```powershell
.\home-watch-windows.ps1 -Mode Install -TvHost $env:TV_HOST
.\home-watch-windows.ps1 -Mode Status
```

`Install` starts the watcher hidden and adds a Windows sign-in entry for this user.
`Run` starts it without adding a sign-in entry. Press Home twice within three seconds
to remain on LG Home. For a remote-only shortcut, open the launcher and hold a number
key to assign Quick Access.

Stop the watcher and remove the sign-in entry:

```powershell
.\home-watch-windows.ps1 -Mode Uninstall
```

This does not uninstall the TV app or change TV privacy settings. Logs remain local
in `.home-watch.log` and `.home-watch.error.log`.

This folder contains the Windows installation helper. For the original macOS
helpers, use the upstream webOS port linked above.

## TV privacy and standby settings

Follow the [CleanYourTV LG guide](https://cleanyour.tv/not-android#lg). These settings
are changed on the TV with its remote, not by the install scripts:

- Turn off Live Plus, Live Promotion, Home Promotion, Content Recommendation, and
  Screen Saver Promotion where available.
- Turn on Limit AD Tracking and Do Not Sell My Personal Information.
- Withdraw optional viewing, voice, advertising, and marketing consents. Preserve
  required Terms of Use and Privacy Policy so smart apps remain available.
- Turn off Smart Tips and Next Picks under AI Service > AI Recommendation.

For standby resume, enable Quick Start+ and, if supported, Always Ready with
"Use Always Ready without wallpaper" selected. Set Power On Screen to Recent Input
to skip LG Home; the companion watcher opens the clean launcher when the TV wakes.
These options use more standby power. They do not guarantee instant wake-up or
faster app performance. No before/after startup benchmark was performed.

These settings do not block ads inside YouTube. DNS filtering and guest-network
isolation are optional separate tasks. Do not block LG's update or app-store services.
An isolated network must still allow the companion's local connection for redirection.

## iPhone mirroring

Open the iPhone Screen Mirroring tile. AirPlay must be On in its settings. On an
iPhone on the same local network, open Control Center > Screen Mirroring and select
the TV. Enter the TV's displayed code if prompted. A wired TV can share the network
with a Wi-Fi iPhone. The iPhone initiates mirroring; the tile opens the receiver screen.

## Local data and credits

Pairing keys, virtual environments, generated app inventories, downloaded TV icons,
IPKs, logs, and IDE settings are ignored by Git. Do not force-add them. TV privacy
settings and Windows startup entries are local state, not settings applied by Git.

The original webOS port, design, layout, and app icon retain their MIT attribution
in `LICENSE`. The Outfit font is under the SIL Open Font License in `app/fonts/OFL.txt`.
