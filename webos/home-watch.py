#!/usr/bin/env python3
"""Make the Home button open the launcher instead of LG's home.

webOS does not let an app replace Home, or even see which app is in front, so this runs on
another always-on device on the same network (a Mac, a Raspberry Pi, a phone in Termux). It
watches the foreground app over the TV's remote-control service and, the moment LG's home
appears, launches the launcher on top. LG's home shows for about half a second.

It also opens the launcher when the TV wakes, so Power On Screen can stay on Recent Input.
Press Home twice within ESCAPE_SECONDS to stay on LG's home (for its menus).

    python3 home-watch.py 192.168.1.50

Needs: pip install websockets. Pair once first (sync-apps.py does it).
"""
import asyncio
import json
import os
import sys
import time

import lgtv

LAUNCHER = "com.gathin.tvhome"
LG_HOME = "com.webos.app.home"
ESCAPE_SECONDS = 3.0


def log(*args):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *args, flush=True)


async def watch(host):
    ws = await lgtv.session(host, ping_interval=5, ping_timeout=5, open_timeout=3)
    log("connected to", host)
    last_redirect = 0.0
    last_launch = 0.0
    boot_pending = True
    try:
        await ws.send(json.dumps({"type": "subscribe", "id": "fg",
                                  "uri": "ssap://com.webos.applicationManager/getForegroundAppInfo",
                                  "payload": {}}))
        await ws.send(json.dumps({"type": "subscribe", "id": "power",
                                  "uri": "ssap://com.webos.service.tvpower/power/getPowerState",
                                  "payload": {}}))
        async for raw in ws:
            msg = json.loads(raw)
            if msg.get("id") == "power":
                state = msg.get("payload", {}).get("state")
                if state in ("Suspend", "Active Standby", "Standby", "Power Off", "Screen Off"):
                    boot_pending = True
                elif state == "Active" and boot_pending:
                    boot_pending = False
                    now = time.monotonic()
                    # The initial foreground subscription may already have redirected Home.
                    if now - last_launch >= 2.0:
                        await ws.send(json.dumps({"type": "request", "id": "launch",
                                                  "uri": "ssap://system.launcher/launch",
                                                  "payload": {"id": LAUNCHER}}))
                        last_launch = now
                        log("TV awake -> launcher")
                continue
            if msg.get("id") == "launch":
                if msg.get("type") == "error" or msg.get("payload", {}).get("returnValue") is False:
                    log("launcher request failed:", msg.get("error") or msg.get("payload"))
                continue
            if msg.get("id") != "fg":
                continue
            app = msg.get("payload", {}).get("appId")
            if app != LG_HOME:
                continue
            now = time.monotonic()
            if now - last_redirect < ESCAPE_SECONDS:
                log("Home pressed twice: staying on LG home")
                last_redirect = 0.0
                continue
            last_redirect = now
            await ws.send(json.dumps({"type": "request", "id": "launch", "uri": "ssap://system.launcher/launch",
                                      "payload": {"id": LAUNCHER}}))
            last_launch = now
            log("LG home -> launcher")
    finally:
        await ws.close()


async def main(host):
    delay = 1
    while True:
        try:
            await watch(host)
            delay = 1
        except (OSError, asyncio.TimeoutError, lgtv.websockets.WebSocketException) as e:
            # TV off, in standby or off the network: keep trying, but back off.
            log("not connected:", type(e).__name__, e)
            delay = min(delay * 2, 3)
        await asyncio.sleep(delay)


if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("TV_HOST")
    if not host:
        sys.exit("usage: home-watch.py <TV IP>")
    try:
        asyncio.run(main(host))
    except KeyboardInterrupt:
        pass
