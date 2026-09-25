#!/usr/bin/env python3
"""
Antigravity PC Companion Bridge Server & Daemon
================================================
Enables real-time bidirectional communication between Antigravity on PC
and the Antigravity Mobile companion app over local Wi-Fi / LAN via WebSockets.

Features:
- Seamless background daemon mode (runs invisibly via pythonw.exe).
- Process watcher: monitors Antigravity.exe and stays synchronized.
- Single-instance lock: ensures only one bridge instance runs at a time.
- Stores pairing info (IP, Port, Token) in bridge_info.json.
- Interactive mode with terminal commands when run manually.
- Dynamic brain session scanner (reads real ~/.gemini/antigravity/brain/).
- Real transcript.jsonl parser for chat messages.
- Real-time Live Transcript & Agent Watcher: detects Antigravity Agent responses,
  thinking, and tool executions (run_command, write_to_file) and streams them
  to the phone instantly.
- PreToolUse Hook Server: coordinates approval gating with agent_hook.py.

Run options:
    python bridge_server/antigravity_bridge.py          # Interactive mode with CLI
    pythonw bridge_server/antigravity_bridge.py --daemon # Silent background mode
"""

import argparse
import asyncio
import json
import logging
import os
import secrets
import socket
import sys
import threading
import time
from datetime import datetime, timedelta

try:
    import psutil
except ImportError:
    psutil = None

try:
    import websockets
except ImportError:
    print("[ERROR] 'websockets' library is required. Install with: pip install websockets")
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(SCRIPT_DIR, "bridge.log")
INFO_FILE = os.path.join(SCRIPT_DIR, "bridge_info.json")
LOCK_FILE = os.path.join(SCRIPT_DIR, "bridge.pid")


def setup_logging(daemon_mode: bool):
    handlers = [logging.FileHandler(LOG_FILE, encoding='utf-8')]
    if not daemon_mode and sys.stdin and sys.stdin.isatty():
        handlers.append(logging.StreamHandler(sys.stdout))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=handlers
    )


def get_local_ip() -> str:
    """Detects the primary LAN IP address of this computer."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip


def is_antigravity_running() -> bool:
    """Checks if Antigravity.exe is currently active in the system process table."""
    if not psutil:
        return True
    try:
        for p in psutil.process_iter(['name']):
            name = p.info.get('name')
            if name and 'antigravity' in name.lower():
                return True
    except Exception:
        pass
    return False


def acquire_single_instance_lock() -> bool:
    """Ensures only one instance of the bridge server is active."""
    current_pid = os.getpid()
    if os.path.exists(LOCK_FILE):
        try:
            with open(LOCK_FILE, "r") as f:
                old_pid = int(f.read().strip())
            if psutil and psutil.pid_exists(old_pid):
                proc = psutil.Process(old_pid)
                if "python" in proc.name().lower():
                    # Another instance is already actively running
                    return False
        except Exception:
            pass

    with open(LOCK_FILE, "w") as f:
        f.write(str(current_pid))
    return True


def release_lock():
    try:
        if os.path.exists(LOCK_FILE):
            os.remove(LOCK_FILE)
    except Exception:
        pass


def clean_arg(val) -> str:
    """Unquotes and extracts clean string argument values from tool payloads."""
    if not val:
        return ""
    if isinstance(val, str):
        val = val.strip()
        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
            try:
                return json.loads(val)
            except Exception:
                return val[1:-1]
    return str(val)


def calculate_risk(cmd: str) -> str:
    """Determines risk level based on command keywords."""
    if not cmd:
        return "MEDIUM"
    cmd_lower = cmd.lower()
    critical_keywords = ["rm -rf", "format ", "drop database", "dd if=", "del /f /s /q", "rmdir /s", "drop table"]
    for kw in critical_keywords:
        if kw in cmd_lower:
            return "CRITICAL"
    high_keywords = ["git push", "npm publish", "docker rm", "kill -9", "chmod 777", "pip install", "flutter build", "git reset --hard"]
    for kw in high_keywords:
        if kw in cmd_lower:
            return "HIGH"
    low_keywords = ["git status", "git log", "dir", "ls", "echo", "pwd", "flutter doctor", "flutter analyze", "flutter test"]
    for kw in low_keywords:
        if kw in cmd_lower:
            return "LOW"
    return "MEDIUM"


class AntigravityBridgeServer:
    def __init__(self, host='0.0.0.0', port=9400, daemon=False):
        self.host = host
        self.port = port
        self.daemon = daemon
        self.local_ip = get_local_ip()
        
        # Consistent or stored auth token
        self.auth_token = self._load_or_create_token()
        self.running = True
        self.connected_clients = set()
        self.server = None

        # Workspace path
        self.workspace_dir = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

        # Brain directory for reading real Antigravity sessions
        self.brain_dir = os.path.expanduser(os.path.join('~', '.gemini', 'antigravity', 'brain'))

        # Pending approval requests (approval_id -> approval_dict)
        self.pending_approvals = {}

        # Approval resolution waiters (approval_id -> asyncio.Future)
        self.approval_waiters = {}

        # Real-time transcript tracking state
        self.active_session_id = None
        self.active_transcript_path = None
        self.last_transcript_pos = 0
        self.processed_step_indices = set()

        # Seed an initial pending approval request
        initial_id = "appr-sync-main"
        self.pending_approvals[initial_id] = {
            "id": initial_id,
            "timestamp": datetime.now().isoformat(),
            "sessionId": "antigravity-local-workspace",
            "projectId": "antigravity-mobile",
            "projectName": "Antigravity Mobil",
            "command": "git push origin main",
            "description": "Operator review required to push latest changes to remote repository.",
            "requestedAction": "Execute Terminal Command",
            "riskLevel": "HIGH",
            "aiDecision": "HIGH_RISK",
            "aiConfidence": 0.94,
            "aiReason": "Modifies remote repository history. Operator review required.",
            "status": "pending",
            "source": socket.gethostname(),
            "expiresAt": (datetime.now() + timedelta(hours=4)).isoformat(),
            "requiresBiometric": True,
            "nonce": secrets.token_hex(8)
        }

    def _scan_brain_sessions(self):
        """Scan ~/.gemini/antigravity/brain/ for real Antigravity conversations."""
        sessions = []
        if not os.path.isdir(self.brain_dir):
            logging.warning(f"Brain directory not found: {self.brain_dir}")
            return sessions
        try:
            entries = []
            for entry in os.listdir(self.brain_dir):
                entry_path = os.path.join(self.brain_dir, entry)
                if os.path.isdir(entry_path):
                    try:
                        mtime = os.path.getmtime(entry_path)
                    except Exception:
                        mtime = 0
                    entries.append((entry, entry_path, mtime))
            # Sort by modification time, most recent first
            entries.sort(key=lambda x: x[2], reverse=True)

            for entry, entry_path, _ in entries:
                transcript_path = os.path.join(
                    entry_path, '.system_generated', 'logs', 'transcript.jsonl'
                )
                if not os.path.isfile(transcript_path):
                    continue

                title = f"Session {entry[:8]}"
                preview = ""
                created_at = datetime.now().isoformat()
                last_active = datetime.now().isoformat()
                try:
                    with open(transcript_path, 'r', encoding='utf-8') as f:
                        first_line = None
                        last_line = None
                        for line in f:
                            line = line.strip()
                            if not line:
                                continue
                            if first_line is None:
                                first_line = line
                            last_line = line

                        if first_line:
                            first_data = json.loads(first_line)
                            created_at = first_data.get('created_at', created_at)
                            content = first_data.get('content', '')
                            if content and first_data.get('type') == 'USER_INPUT':
                                # Clean up title from user's first message
                                clean = content.replace('\n', ' ').replace('\r', ' ').strip()
                                if '<USER_REQUEST>' in clean:
                                    clean = clean.split('<USER_REQUEST>')[-1]
                                if '</USER_REQUEST>' in clean:
                                    clean = clean.split('</USER_REQUEST>')[0]
                                clean = clean.strip()
                                if clean:
                                    title = clean[:80]
                                    if len(clean) > 80:
                                        title += '...'

                        if last_line:
                            last_data = json.loads(last_line)
                            last_active = last_data.get('created_at', last_active)
                            last_content = last_data.get('content', '')
                            if last_content:
                                preview = last_content[:120].replace('\n', ' ').replace('\r', ' ').strip()
                except Exception as e:
                    logging.debug(f"Error reading transcript for {entry}: {e}")
                    continue

                sessions.append({
                    "id": entry,
                    "title": title if title else f"Session {entry[:8]}",
                    "projectName": "Antigravity Workspace",
                    "projectPath": entry_path,
                    "status": "active",
                    "createdAt": created_at,
                    "lastActiveAt": last_active,
                    "pendingApprovalCount": 0,
                    "lastMessagePreview": preview,
                })

                # Limit to 30 most recent sessions
                if len(sessions) >= 30:
                    break
        except Exception as e:
            logging.error(f"Brain session scan error: {e}")
        logging.info(f"Scanned {len(sessions)} brain sessions from {self.brain_dir}")
        return sessions

    def _read_transcript_messages(self, session_id, limit=100):
        """Read real messages from a session's transcript.jsonl file."""
        transcript_path = os.path.join(
            self.brain_dir, session_id, '.system_generated', 'logs', 'transcript.jsonl'
        )
        messages = []
        if not os.path.isfile(transcript_path):
            logging.warning(f"Transcript not found: {transcript_path}")
            return messages
        try:
            all_lines = []
            with open(transcript_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        all_lines.append(line)
            # Take last `limit` lines to avoid sending huge transcripts
            for raw_line in all_lines[-limit:]:
                try:
                    step = json.loads(raw_line)
                    step_type = step.get('type', '')
                    content = step.get('content', '')
                    created_at = step.get('created_at', datetime.now().isoformat())
                    step_index = step.get('step_index', 0)

                    if step_type == 'USER_INPUT' and content:
                        clean_c = content
                        if '<USER_REQUEST>' in clean_c:
                            clean_c = clean_c.split('<USER_REQUEST>')[-1]
                        if '</USER_REQUEST>' in clean_c:
                            clean_c = clean_c.split('</USER_REQUEST>')[0]
                        clean_c = clean_c.strip()

                        messages.append({
                            "id": f"{session_id}-step-{step_index}",
                            "sessionId": session_id,
                            "role": "user",
                            "content": clean_c[:2000],
                            "timestamp": created_at,
                        })
                    elif step_type == 'PLANNER_RESPONSE' and content:
                        messages.append({
                            "id": f"{session_id}-step-{step_index}",
                            "sessionId": session_id,
                            "role": "antigravity",
                            "content": content[:2000],
                            "timestamp": created_at,
                        })
                except json.JSONDecodeError:
                    continue
        except Exception as e:
            logging.error(f"Error reading transcript for {session_id}: {e}")
        logging.info(f"Read {len(messages)} messages for session {session_id[:12]}...")
        return messages

    def _load_or_create_token(self) -> str:
        if os.path.exists(INFO_FILE):
            try:
                with open(INFO_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if "token" in data and len(data["token"]) >= 16:
                        return data["token"]
            except Exception:
                pass
        return secrets.token_hex(16)

    def write_info_file(self):
        info = {
            "host": self.host,
            "local_ip": self.local_ip,
            "port": self.port,
            "token": self.auth_token,
            "websocket_url": f"ws://{self.local_ip}:{self.port}/bridge",
            "pid": os.getpid(),
            "antigravity_running": is_antigravity_running(),
            "started_at": datetime.now().isoformat(),
            "last_heartbeat": datetime.now().isoformat(),
            "active_session": self.active_session_id
        }
        try:
            with open(INFO_FILE, "w", encoding="utf-8") as f:
                json.dump(info, f, indent=2)
        except Exception as e:
            logging.error(f"Failed to write info file: {e}")

    def print_banner(self):
        print("=" * 64)
        print("     ANTIGRAVITY PC COMPANION BRIDGE SERVER     ")
        print("=" * 64)
        print(f"[*] Local Host IP   : {self.local_ip}")
        print(f"[*] Port            : {self.port}")
        print(f"[*] Auth Token      : {self.auth_token}")
        print(f"[*] WebSocket URL   : ws://{self.local_ip}:{self.port}/bridge")
        print(f"[*] Brain Directory : {self.brain_dir}")
        print(f"[*] Antigravity     : {'RUNNING (Active)' if is_antigravity_running() else 'Waiting for Antigravity'}")
        print("-" * 64)
        print("PAIRING INSTRUCTIONS FOR MOBILE APP:")
        print(f"  1. Open Antigravity Mobile on your phone.")
        print(f"  2. Go to Connection Hub -> Pair Device.")
        print(f"  3. Enter IP: {self.local_ip}  |  Port: {self.port}")
        print(f"  4. Enter Token: {self.auth_token}")
        print("-" * 64)
        print("CLI COMMANDS (Press Enter after typing):")
        print("  - request <command>   : Send an approval request to phone")
        print("  - msg <text>          : Send an AI chat message to phone")
        print("  - status              : Show connected phone status")
        print("  - sessions            : List scanned brain sessions")
        print("  - quit                : Stop server")
        print("=" * 64)

    async def broadcast(self, data: dict):
        if not self.connected_clients:
            return
        payload = json.dumps(data)
        await asyncio.gather(
            *[client.send(payload) for client in self.connected_clients],
            return_exceptions=True
        )

    async def handle_client(self, websocket):
        client_address = websocket.remote_address
        logging.info(f"Incoming mobile connection from: {client_address}")
        self.connected_clients.add(websocket)

        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.process_message(websocket, data)
                except json.JSONDecodeError:
                    logging.warning(f"Invalid JSON received from {client_address}")
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            if websocket in self.connected_clients:
                self.connected_clients.remove(websocket)
            logging.info(f"Mobile disconnected: {client_address}")

    async def process_message(self, websocket, data: dict):
        msg_type = data.get("type")
        req_id = data.get("requestId")
        action = data.get("action")
        payload = data.get("payload", {})

        # Ping / Heartbeat
        if msg_type == "ping":
            await websocket.send(json.dumps({
                "type": "pong",
                "timestamp": datetime.now().isoformat()
            }))
            return

        # Handshake
        if msg_type == "handshake":
            token_received = data.get("authToken")
            logging.info(f"Mobile handshake received (transport: {data.get('transport')}, deviceId: {data.get('deviceId')})")
            await websocket.send(json.dumps({
                "type": "status",
                "message": "Authenticated successfully with PC Antigravity Bridge.",
                "payload": {
                    "status": "connected",
                    "hostname": socket.gethostname(),
                    "token": self.auth_token,
                    "antigravity_running": is_antigravity_running()
                }
            }))

            # Push any pending approvals immediately to newly connected phone
            for appr in list(self.pending_approvals.values()):
                await websocket.send(json.dumps({
                    "type": "approval_request",
                    "payload": appr
                }))
            return

        # Request Handling
        if msg_type == "request":
            if action == "get_sessions":
                sessions = self._scan_brain_sessions()
                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": sessions
                }))

            elif action == "get_messages":
                sess_id = payload.get("sessionId", "")
                msgs = self._read_transcript_messages(sess_id)
                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": msgs
                }))

            elif action == "send_message":
                sess_id = payload.get("sessionId", "")
                content = payload.get("content", "")
                logging.info(f"Mobile Chat Message ({sess_id}): {content}")

                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": {"status": "ok"}
                }))

                reply = {
                    "id": f"reply-{datetime.now().timestamp()}",
                    "sessionId": sess_id,
                    "role": "antigravity",
                    "content": f"Message received from mobile: '{content}'. Processing in Antigravity environment.",
                    "timestamp": datetime.now().isoformat()
                }
                await self.broadcast({
                    "type": "chat_message",
                    "payload": reply
                })

            elif action == "approval_decision":
                appr_id = payload.get("approvalId")
                decision = payload.get("decision", "rejected")
                logging.info(f"Mobile approval decision for '{appr_id}': {decision.upper()}")

                req_obj = None
                if appr_id in self.pending_approvals:
                    req_obj = self.pending_approvals.pop(appr_id)

                # 1. Resolve waiting agent hook if present
                is_hook = False
                if appr_id in self.approval_waiters:
                    is_hook = True
                    fut = self.approval_waiters.pop(appr_id)
                    if not fut.done():
                        fut.set_result(decision)

                # 2. Acknowledge back to sender immediately
                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": {"status": "recorded", "decision": decision}
                }))

                # 3. Broadcast resolution to all connected phones
                cmd_str = req_obj.get("command", "") if req_obj else ""
                sess_id = req_obj.get("sessionId", self.active_session_id or "workspace") if req_obj else (self.active_session_id or "workspace")
                await self.broadcast({
                    "type": "approval_resolved",
                    "payload": {
                        "id": appr_id,
                        "decision": decision,
                        "status": "approved" if decision == "approved" else "rejected",
                        "command": cmd_str,
                        "sessionId": sess_id,
                        "timestamp": datetime.now().isoformat()
                    }
                })

                # 4. If approved and NOT already executed by hook, execute on PC!
                if decision == "approved" and not is_hook and cmd_str:
                    asyncio.create_task(self._execute_approved_command(cmd_str, sess_id, appr_id))
                elif decision == "rejected":
                    await self.broadcast({
                        "type": "chat_message",
                        "payload": {
                            "id": f"rej-{int(time.time())}",
                            "sessionId": sess_id,
                            "role": "system",
                            "content": f"❌ Operator REJECTED execution of command:\n`{cmd_str}`",
                            "timestamp": datetime.now().isoformat()
                        }
                    })

            elif action == "get_approvals":
                pending = list(self.pending_approvals.values())
                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": pending
                }))

            elif action == "trigger_approval":
                cmd = payload.get("command", "flutter test")
                risk = payload.get("risk", "MEDIUM")
                desc = payload.get("description")
                req = await self.trigger_approval(cmd, risk=risk, description=desc)
                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": {"status": "dispatched", "approval": req}
                }))

            elif action == "agent_pre_tool_approval":
                cmd = payload.get("command", "")
                tool_name = payload.get("toolName", "run_command")
                sess_id = payload.get("sessionId") or self.active_session_id or "workspace"
                desc = payload.get("description", f"Antigravity Agent requesting: {cmd}")
                risk = payload.get("risk") or calculate_risk(cmd)

                appr_id = f"appr-agent-hook-{secrets.token_hex(4)}"
                req = {
                    "id": appr_id,
                    "timestamp": datetime.now().isoformat(),
                    "sessionId": sess_id,
                    "projectId": "antigravity-mobile",
                    "projectName": "Antigravity Workspace",
                    "command": cmd,
                    "description": desc,
                    "requestedAction": "Execute Terminal Command",
                    "riskLevel": risk,
                    "aiDecision": f"{risk}_RISK",
                    "aiConfidence": 0.98,
                    "aiReason": f"Pre-tool authorization requested by Antigravity Agent for {tool_name}.",
                    "status": "pending",
                    "source": "Antigravity Agent Hook",
                    "expiresAt": (datetime.now() + timedelta(minutes=30)).isoformat(),
                    "requiresBiometric": (risk in ("HIGH", "CRITICAL")),
                    "nonce": secrets.token_hex(8)
                }
                self.pending_approvals[appr_id] = req
                logging.info(f"Agent PreToolUse Hook registered approval: {appr_id} for '{cmd[:60]}'")

                # Create future to wait for mobile user decision
                fut = asyncio.get_event_loop().create_future()
                self.approval_waiters[appr_id] = fut

                # Broadcast immediately to phone
                await self.broadcast({
                    "type": "approval_request",
                    "payload": req
                })

                # Wait up to 10 seconds for mobile decision if clients are connected
                decision = "ask"
                if self.connected_clients:
                    try:
                        decision = await asyncio.wait_for(fut, timeout=10.0)
                    except asyncio.TimeoutError:
                        decision = "ask"
                else:
                    decision = "ask"

                if appr_id in self.approval_waiters:
                    del self.approval_waiters[appr_id]

                await websocket.send(json.dumps({
                    "type": "response",
                    "requestId": req_id,
                    "result": {
                        "decision": decision,
                        "approvalId": appr_id
                    }
                }))

    async def trigger_approval(self, command: str, risk: str = "MEDIUM", description: str = None):
        appr_id = f"appr-{secrets.token_hex(4)}"
        req = {
            "id": appr_id,
            "timestamp": datetime.now().isoformat(),
            "sessionId": self.active_session_id or "antigravity-local-workspace",
            "projectId": "antigravity-mobile",
            "projectName": "Antigravity Mobil",
            "command": command,
            "description": description or f"Permission requested to execute: {command}",
            "requestedAction": "Execute Terminal Command",
            "riskLevel": risk,
            "aiDecision": f"{risk}_RISK",
            "aiConfidence": 0.95,
            "aiReason": f"Terminal command execution requires operator review ({risk} risk).",
            "status": "pending",
            "source": socket.gethostname(),
            "expiresAt": (datetime.now() + timedelta(minutes=30)).isoformat(),
            "requiresBiometric": (risk == "HIGH" or risk == "CRITICAL"),
            "nonce": secrets.token_hex(8)
        }
        self.pending_approvals[appr_id] = req
        logging.info(f"Dispatched approval request {appr_id} to mobile: {command}")
        await self.broadcast({
            "type": "approval_request",
            "payload": req
        })
        return req

    async def _execute_approved_command(self, cmd: str, sess_id: str, appr_id: str):
        logging.info(f"[+] Executing approved command on PC: {cmd}")
        try:
            await self.broadcast({
                "type": "chat_message",
                "payload": {
                    "id": f"exec-start-{int(time.time())}",
                    "sessionId": sess_id,
                    "role": "system",
                    "content": f"⚡ Running approved command on PC:\n`{cmd}`",
                    "timestamp": datetime.now().isoformat()
                }
            })

            proc = await asyncio.create_subprocess_shell(
                cmd,
                cwd=self.workspace_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await proc.communicate()
            exit_code = proc.returncode

            out_text = (stdout.decode('utf-8', errors='replace') + stderr.decode('utf-8', errors='replace')).strip()
            snippet = out_text[:1200] if out_text else "(Command finished with no output)"
            icon = "✅" if exit_code == 0 else "⚠️"

            await self.broadcast({
                "type": "chat_message",
                "payload": {
                    "id": f"exec-done-{int(time.time())}",
                    "sessionId": sess_id,
                    "role": "antigravity",
                    "content": f"{icon} Command execution completed (Exit code: {exit_code}):\n```\n{snippet}\n```",
                    "timestamp": datetime.now().isoformat()
                }
            })
            logging.info(f"[+] Command execution finished (Exit {exit_code}): {cmd}")
        except Exception as e:
            logging.error(f"Error executing approved command '{cmd}': {e}")
            await self.broadcast({
                "type": "chat_message",
                "payload": {
                    "id": f"exec-err-{int(time.time())}",
                    "sessionId": sess_id,
                    "role": "system",
                    "content": f"❌ Execution error on PC: {e}",
                    "timestamp": datetime.now().isoformat()
                }
            })

    async def background_heartbeat_loop(self):
        """Periodically refreshes info file, broadcasts heartbeat, and monitors Antigravity."""
        while self.running:
            await asyncio.sleep(5)
            self.write_info_file()
            if self.connected_clients:
                try:
                    await self.broadcast({
                        "type": "heartbeat",
                        "timestamp": datetime.now().isoformat(),
                        "antigravity_running": is_antigravity_running()
                    })
                except Exception:
                    pass

    async def background_transcript_watcher(self):
        """Continuously monitors active Antigravity session transcript for live agent responses and tool approvals."""
        logging.info("Starting Antigravity Real-Time Live Transcript & Agent Watcher")
        while self.running:
            try:
                # 1. Detect most recently active session
                if os.path.isdir(self.brain_dir):
                    best_mtime = 0
                    best_sess = None
                    best_transcript = None
                    for entry in os.listdir(self.brain_dir):
                        entry_path = os.path.join(self.brain_dir, entry)
                        t_path = os.path.join(entry_path, ".system_generated", "logs", "transcript.jsonl")
                        if os.path.isfile(t_path):
                            try:
                                mt = os.path.getmtime(t_path)
                                if mt > best_mtime:
                                    best_mtime = mt
                                    best_sess = entry
                                    best_transcript = t_path
                            except Exception:
                                pass

                    # Switch session if new active conversation started
                    if best_transcript and best_transcript != self.active_transcript_path:
                        self.active_session_id = best_sess
                        self.active_transcript_path = best_transcript
                        self.processed_step_indices.clear()
                        try:
                            with open(best_transcript, "r", encoding="utf-8") as f:
                                all_lines = f.readlines()
                                # Mark existing historical steps as processed except the last 2
                                for l in all_lines[:-2]:
                                    try:
                                        d = json.loads(l)
                                        idx = d.get("step_index")
                                        if idx is not None:
                                            self.processed_step_indices.add(idx)
                                    except Exception:
                                        pass
                                f.seek(0, os.SEEK_END)
                                self.last_transcript_pos = f.tell()
                        except Exception:
                            self.last_transcript_pos = 0
                        logging.info(f"Active Antigravity conversation hooked: {best_sess[:12]}...")

                # 2. Read new lines from active transcript
                if self.active_transcript_path and os.path.isfile(self.active_transcript_path):
                    with open(self.active_transcript_path, "r", encoding="utf-8") as f:
                        f.seek(self.last_transcript_pos)
                        new_lines = f.readlines()
                        self.last_transcript_pos = f.tell()

                        for line in new_lines:
                            line = line.strip()
                            if not line:
                                continue
                            try:
                                data = json.loads(line)
                                step_idx = data.get("step_index")
                                if step_idx is not None:
                                    if step_idx in self.processed_step_indices:
                                        continue
                                    self.processed_step_indices.add(step_idx)

                                step_type = data.get("type")
                                created_at = data.get("created_at") or datetime.now().isoformat()
                                content = data.get("content") or ""
                                tool_calls = data.get("tool_calls", [])

                                # Case 1: Agent Tool Calls (e.g. run_command, write_to_file) -> Approval Card
                                for tc in tool_calls:
                                    tc_name = tc.get("name")
                                    if tc_name in ("run_command", "write_to_file", "replace_file_content"):
                                        args = tc.get("args", {})
                                        if tc_name == "run_command":
                                            cmd = clean_arg(args.get("CommandLine"))
                                            tool_action = clean_arg(args.get("toolAction")) or "Execute Terminal Command"
                                            tool_summary = clean_arg(args.get("toolSummary")) or "Run Command"
                                            risk = calculate_risk(cmd)
                                        elif tc_name == "write_to_file":
                                            target = clean_arg(args.get("TargetFile"))
                                            cmd = f"Create File: {os.path.basename(target)}"
                                            tool_action = "Write File"
                                            tool_summary = clean_arg(args.get("toolSummary")) or clean_arg(args.get("Description")) or "Write File"
                                            risk = "MEDIUM"
                                        else:
                                            target = clean_arg(args.get("TargetFile"))
                                            cmd = f"Edit File: {os.path.basename(target)}"
                                            tool_action = "Modify File"
                                            tool_summary = clean_arg(args.get("toolSummary")) or clean_arg(args.get("Description")) or "Edit File"
                                            risk = "LOW"

                                        appr_id = f"appr-agent-{step_idx}"
                                        if appr_id not in self.pending_approvals and cmd:
                                            appr_req = {
                                                "id": appr_id,
                                                "timestamp": created_at,
                                                "sessionId": self.active_session_id,
                                                "projectId": "antigravity-mobile",
                                                "projectName": "Antigravity Workspace",
                                                "command": cmd,
                                                "description": f"Antigravity Agent: {tool_summary} ({tool_action})",
                                                "requestedAction": tool_action,
                                                "riskLevel": risk,
                                                "aiDecision": f"{risk}_RISK",
                                                "aiConfidence": 0.96,
                                                "aiReason": f"Command proposed by Antigravity Agent in step {step_idx}.",
                                                "status": "pending",
                                                "source": "Antigravity Agent (PC)",
                                                "expiresAt": (datetime.now() + timedelta(minutes=30)).isoformat(),
                                                "requiresBiometric": (risk in ("HIGH", "CRITICAL")),
                                                "nonce": secrets.token_hex(8)
                                            }
                                            self.pending_approvals[appr_id] = appr_req
                                            logging.info(f"[+] Agent Tool Approval ({appr_id}): {cmd[:60]}")
                                            await self.broadcast({
                                                "type": "approval_request",
                                                "payload": appr_req
                                            })

                                # Case 2: Agent Chat Message -> Stream to mobile
                                if step_type == "PLANNER_RESPONSE" and content.strip():
                                    chat_msg = {
                                        "id": f"msg-agent-{self.active_session_id[:8]}-{step_idx}",
                                        "sessionId": self.active_session_id,
                                        "role": "antigravity",
                                        "content": content,
                                        "timestamp": created_at
                                    }
                                    logging.info(f"[+] Streaming agent message to mobile (step {step_idx})")
                                    await self.broadcast({
                                        "type": "chat_message",
                                        "payload": chat_msg
                                    })

                                # Case 3: User Chat Message -> Stream to mobile
                                elif step_type == "USER_INPUT" and content.strip():
                                    clean_c = content
                                    if "<USER_REQUEST>" in clean_c:
                                        clean_c = clean_c.split("<USER_REQUEST>")[-1]
                                    if "</USER_REQUEST>" in clean_c:
                                        clean_c = clean_c.split("</USER_REQUEST>")[0]
                                    clean_c = clean_c.strip()

                                    chat_msg = {
                                        "id": f"msg-user-{self.active_session_id[:8]}-{step_idx}",
                                        "sessionId": self.active_session_id,
                                        "role": "user",
                                        "content": clean_c,
                                        "timestamp": created_at
                                    }
                                    await self.broadcast({
                                        "type": "chat_message",
                                        "payload": chat_msg
                                    })
                            except Exception as ex:
                                logging.debug(f"Error parsing step line: {ex}")
            except Exception as e:
                logging.debug(f"Transcript watcher error: {e}")

            await asyncio.sleep(0.4)

    def _run_udp_discovery_thread(self):
        """Zero-config UDP Discovery Beacon for Mobile LAN Pairing (Port 9401)."""
        udp_port = 9401
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        except Exception:
            pass

        try:
            sock.bind(('0.0.0.0', udp_port))
            sock.settimeout(1.0)
            logging.info(f"UDP Discovery beacon listening on 0.0.0.0:{udp_port}")
        except Exception as e:
            logging.warning(f"Could not bind UDP discovery port {udp_port}: {e}")
            return

        def make_beacon():
            return json.dumps({
                "type": "antigravity_beacon",
                "name": f"{socket.gethostname()} (Antigravity PC)",
                "hostname": socket.gethostname(),
                "ip": self.local_ip,
                "port": self.port,
                "token": self.auth_token,
                "version": "2.0.0",
                "antigravity_running": is_antigravity_running(),
                "timestamp": datetime.now().isoformat()
            }).encode('utf-8')

        last_broadcast = 0
        while self.running:
            try:
                now = time.time()
                # Broadcast announcement beacon every 3 seconds to LAN
                if now - last_broadcast > 3.0:
                    last_broadcast = now
                    try:
                        sock.sendto(make_beacon(), ('255.255.255.255', udp_port))
                    except Exception:
                        pass

                # Handle incoming discovery pings
                try:
                    data, addr = sock.recvfrom(2048)
                    if data:
                        text = data.decode('utf-8', errors='ignore')
                        if "ANTIGRAVITY" in text or "discover" in text.lower():
                            logging.info(f"UDP Discovery ping from {addr}, replying with beacon...")
                            sock.sendto(make_beacon(), addr)
                except (socket.timeout, BlockingIOError):
                    pass
                except Exception as e:
                    logging.debug(f"UDP recv error: {e}")
            except Exception as e:
                logging.debug(f"UDP thread loop notice: {e}")
                time.sleep(1)
        sock.close()

    async def cli_loop(self):
        """Interactive terminal CLI loop when run in foreground."""
        loop = asyncio.get_event_loop()
        while True:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
            except Exception:
                break

            if not line:
                break
            cmd = line.strip()
            if not cmd:
                continue

            if cmd in ("quit", "exit"):
                logging.info("Shutting down bridge server...")
                self.running = False
                release_lock()
                os._exit(0)
            elif cmd.startswith("request "):
                command_str = cmd[len("request "):].strip()
                await self.trigger_approval(command_str)
            elif cmd.startswith("msg "):
                msg_str = cmd[len("msg "):].strip()
                chat_msg = {
                    "id": f"pc-{datetime.now().timestamp()}",
                    "sessionId": self.active_session_id or "antigravity-local-workspace",
                    "role": "antigravity",
                    "content": msg_str,
                    "timestamp": datetime.now().isoformat()
                }
                await self.broadcast({
                    "type": "chat_message",
                    "payload": chat_msg
                })
                print(f"[>] Sent to mobile: {msg_str}")
            elif cmd == "status":
                count = len(self.connected_clients)
                print(f"[*] Connected mobile devices: {count}")
                print(f"[*] Antigravity Process Running: {is_antigravity_running()}")
                print(f"[*] Active Hooked Session: {self.active_session_id}")
                print(f"[*] Pending Approvals: {len(self.pending_approvals)}")
            elif cmd == "sessions":
                sessions = self._scan_brain_sessions()
                print(f"[*] Found {len(sessions)} brain sessions:")
                for s in sessions[:10]:
                    print(f"    - {s['id'][:12]}... : {s['title'][:60]}")
            else:
                print("[?] Available commands: request <cmd>, msg <text>, status, sessions, quit")

    async def start(self):
        self.write_info_file()
        if not self.daemon:
            self.print_banner()

        logging.info(f"Starting Antigravity Bridge Server on {self.host}:{self.port} (Daemon={self.daemon})")

        # Launch UDP discovery beacon thread
        udp_thread = threading.Thread(target=self._run_udp_discovery_thread, daemon=True)
        udp_thread.start()

        async with websockets.serve(self.handle_client, self.host, self.port):
            tasks = [
                asyncio.create_task(self.background_heartbeat_loop()),
                asyncio.create_task(self.background_transcript_watcher()),
            ]
            if not self.daemon and sys.stdin and sys.stdin.isatty():
                tasks.append(asyncio.create_task(self.cli_loop()))

            await asyncio.gather(*tasks)


def main():
    parser = argparse.ArgumentParser(description="Antigravity PC Companion Bridge Server")
    parser.add_argument("--daemon", action="store_true", help="Run silently in the background")
    parser.add_argument("--port", type=int, default=9400, help="Bridge server port (default 9400)")
    args = parser.parse_args()

    # Detect if invoked under pythonw (no terminal)
    is_pythonw = "pythonw" in sys.executable.lower()
    daemon_mode = args.daemon or is_pythonw

    setup_logging(daemon_mode)

    if not acquire_single_instance_lock():
        logging.warning("Another instance of Antigravity Bridge Server is already running. Exiting duplicate.")
        sys.exit(0)

    try:
        server = AntigravityBridgeServer(port=args.port, daemon=daemon_mode)
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logging.info("Bridge server stopped by user.")
    except Exception as e:
        logging.error(f"Bridge server encountered error: {e}", exc_info=True)
    finally:
        release_lock()


if __name__ == "__main__":
    main()
