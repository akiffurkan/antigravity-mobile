#!/usr/bin/env python3
"""
Antigravity Agent Lifecycle Hook: PreToolUse Safety & Mobile Gate
==================================================================
Invoked by Antigravity before executing tools (e.g. run_command).
Connects to the local Antigravity Bridge Server over WebSocket,
dispatches an approval card to the Antigravity Mobile phone app,
and returns the decision (allow/deny/ask) based on the operator's response.
"""

import asyncio
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INFO_FILE = os.path.join(SCRIPT_DIR, "bridge_info.json")

try:
    import websockets
except ImportError:
    print(json.dumps({"decision": "ask", "reason": "websockets module not available in Python environment"}))
    sys.exit(0)


async def check_approval():
    if not os.path.exists(INFO_FILE):
        return {"decision": "ask", "reason": "Antigravity Bridge server not active."}

    # Read Antigravity context from stdin
    try:
        raw_in = sys.stdin.read()
        hook_input = json.loads(raw_in) if raw_in else {}
    except Exception:
        hook_input = {}

    tool_call = hook_input.get("toolCall", {})
    tool_name = tool_call.get("name", "run_command")
    args = tool_call.get("args", {})
    cmd = args.get("CommandLine", "")
    conv_id = hook_input.get("conversationId", "")
    tool_action = args.get("toolAction") or args.get("toolSummary") or tool_name

    try:
        with open(INFO_FILE, "r", encoding="utf-8") as f:
            info = json.load(f)
    except Exception:
        return {"decision": "ask", "reason": "Failed to read bridge_info.json."}

    port = info.get("port", 9400)
    token = info.get("token", "")
    uri = f"ws://127.0.0.1:{port}/bridge"

    try:
        async with websockets.connect(uri) as ws:
            # 1. Authenticate with local bridge
            await ws.send(json.dumps({
                "type": "handshake",
                "authToken": token,
                "clientId": "agent-pretool-hook",
                "transport": "local"
            }))
            await asyncio.wait_for(ws.recv(), timeout=3.0)

            # 2. Dispatch pre-tool approval request to mobile
            req_id = "agent_hook_req"
            await ws.send(json.dumps({
                "type": "request",
                "action": "agent_pre_tool_approval",
                "requestId": req_id,
                "payload": {
                    "toolName": tool_name,
                    "command": cmd,
                    "sessionId": conv_id,
                    "description": f"Antigravity Agent: {tool_action}"
                }
            }))

            # 3. Wait for decision from bridge server (up to 12s)
            res = await asyncio.wait_for(ws.recv(), timeout=12.0)
            data = json.loads(res)
            decision = data.get("result", {}).get("decision", "ask")

            if decision == "approved":
                return {
                    "decision": "allow",
                    "reason": "Approved by operator via Antigravity Mobile companion app."
                }
            elif decision == "rejected":
                return {
                    "decision": "deny",
                    "reason": "Rejected by operator via Antigravity Mobile companion app."
                }
            else:
                return {
                    "decision": "ask",
                    "reason": "Antigravity Mobile companion notified. Prompting operator for confirmation."
                }
    except Exception as e:
        return {
            "decision": "ask",
            "reason": f"Mobile gate fallback to IDE: {e}"
        }


def main():
    result = asyncio.run(check_approval())
    print(json.dumps(result))


if __name__ == "__main__":
    main()
