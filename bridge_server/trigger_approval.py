#!/usr/bin/env python3
"""
Trigger Approval CLI for Antigravity Companion Bridge
======================================================
Sends an approval request to the running Bridge Server, which immediately
broadcasts it to connected mobile devices.

Usage:
    python trigger_approval.py "flutter test"
    python trigger_approval.py "git push origin main" --risk HIGH
    python trigger_approval.py "rm -rf build/" --risk CRITICAL --desc "Delete build output"
"""

import argparse
import asyncio
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INFO_FILE = os.path.join(SCRIPT_DIR, "bridge_info.json")

try:
    import websockets
except ImportError:
    print("[ERROR] 'websockets' library required. Install with: pip install websockets")
    sys.exit(1)


def get_bridge_info():
    if not os.path.exists(INFO_FILE):
        print("[ERROR] bridge_info.json not found. Is Antigravity Bridge running?")
        sys.exit(1)
    with open(INFO_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


async def send_approval(command: str, risk: str, description: str = None):
    info = get_bridge_info()
    port = info.get("port", 9400)
    token = info.get("token", "")
    uri = f"ws://127.0.0.1:{port}/bridge"

    print(f"Connecting to Bridge at {uri}...")
    try:
        async with websockets.connect(uri) as ws:
            # Handshake
            await ws.send(json.dumps({
                "type": "handshake",
                "authToken": token,
                "clientId": "cli-trigger",
                "transport": "wifi"
            }))
            await ws.recv()

            # Trigger approval
            payload = {
                "command": command,
                "risk": risk.upper(),
            }
            if description:
                payload["description"] = description

            await ws.send(json.dumps({
                "type": "request",
                "action": "trigger_approval",
                "requestId": "cli-appr-1",
                "payload": payload
            }))

            res = await asyncio.wait_for(ws.recv(), timeout=5.0)
            data = json.loads(res)
            appr = data.get("result", {}).get("approval", {})
            print(f"[SUCCESS] Approval request dispatched to mobile!")
            print(f"  ID      : {appr.get('id')}")
            print(f"  Command : {appr.get('command')}")
            print(f"  Risk    : {appr.get('riskLevel')}")
            print(f"  Expires : {appr.get('expiresAt')}")
    except Exception as e:
        print(f"[ERROR] Failed to send approval request: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Trigger an approval request to Antigravity Mobile")
    parser.add_argument("command", nargs="?", default="flutter test", help="The command requiring operator approval")
    parser.add_argument("--risk", default="MEDIUM", choices=["LOW", "MEDIUM", "HIGH", "CRITICAL"], help="Risk level")
    parser.add_argument("--desc", default=None, help="Optional custom description")
    args = parser.parse_args()

    asyncio.run(send_approval(args.command, args.risk, args.desc))


if __name__ == "__main__":
    main()
