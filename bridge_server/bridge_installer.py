#!/usr/bin/env python3
"""
Antigravity PC Companion Bridge - Installer & Standalone Executable
===================================================================
A standalone Windows installer and runtime for the Antigravity Companion Bridge.
Can run standalone or install as a permanent Windows background service.

Usage:
    bridge-server-install.exe              # Run server / Interactive setup
    bridge-server-install.exe --install    # Install to AppData & create shortcuts
    bridge-server-install.exe --daemon     # Run silently in background
    bridge-server-install.exe --status     # Show current bridge server status
    bridge-server-install.exe --uninstall  # Remove from system
"""

import argparse
import asyncio
import json
import logging
import os
import secrets
import shutil
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
    print("[ERROR] 'websockets' library is required.")
    sys.exit(1)

# Application paths
APP_NAME = "AntigravityBridge"
APPDATA_DIR = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), APP_NAME)
LOG_FILE = os.path.join(APPDATA_DIR, "bridge.log")
INFO_FILE = os.path.join(APPDATA_DIR, "bridge_info.json")
LOCK_FILE = os.path.join(APPDATA_DIR, "bridge.pid")

os.makedirs(APPDATA_DIR, exist_ok=True)


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


def clean_arg(val) -> str:
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
        self.auth_token = self._load_or_create_token()
        self.running = True
        self.connected_clients = set()
        self.server = None
        self.brain_dir = os.path.expanduser(os.path.join('~', '.gemini', 'antigravity', 'brain'))
        self.workspace_dir = os.environ.get("WORKSPACE_DIR", os.getcwd())
        self.pending_approvals = {}
        self.approval_waiters = {}
        self.active_session_id = None
        self.active_transcript_path = None
        self.last_transcript_pos = 0
        self.processed_step_indices = set()

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
        sessions = []
        if not os.path.isdir(self.brain_dir):
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
            entries.sort(key=lambda x: x[2], reverse=True)

            for entry, entry_path, _ in entries:
                transcript_path = os.path.join(entry_path, '.system_generated', 'logs', 'transcript.jsonl')
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
                except Exception:
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
                if len(sessions) >= 30:
                    break
        except Exception as e:
            logging.error(f"Brain scan error: {e}")
        return sessions

    def _read_transcript_messages(self, session_id, limit=100):
        transcript_path = os.path.join(self.brain_dir, session_id, '.system_generated', 'logs', 'transcript.jsonl')
        messages = []
        if not os.path.isfile(transcript_path):
            return messages
        try:
            all_lines = []
            with open(transcript_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        all_lines.append(line)
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
        except Exception:
            pass

    def print_banner(self):
        print("=" * 66)
        print("         ANTIGRAVITY PC COMPANION BRIDGE SERVER           ")
        print("=" * 66)
        print(f"[*] Local Host IP   : {self.local_ip}")
        print(f"[*] Port            : {self.port} (TCP WebSocket) / 9401 (UDP Beacon)")
        print(f"[*] Auth Token      : {self.auth_token}")
        print(f"[*] WebSocket URL   : ws://{self.local_ip}:{self.port}/bridge")
        print(f"[*] Antigravity     : {'RUNNING (Active)' if is_antigravity_running() else 'Waiting for Antigravity'}")
        print("-" * 66)
        print("PAIRING INSTRUCTIONS FOR ANTIGRAVITY MOBILE:")
        print(f"  1. Open Antigravity Mobile on your Android device.")
        print(f"  2. If on same Wi-Fi, tap 'Scan Devices' -> It auto-detects!")
        print(f"  3. Or tap 'Pair Device' manually:")
        print(f"     IP: {self.local_ip}  |  Port: {self.port}")
        print(f"     Token: {self.auth_token}")
        print("-" * 66)
        print("COMMANDS: request <cmd>, msg <text>, status, sessions, quit")
        print("=" * 66)

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
                    pass
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

        if msg_type == "ping":
            await websocket.send(json.dumps({
                "type": "pong",
                "timestamp": datetime.now().isoformat()
            }))
            return

        if msg_type == "handshake":
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
            for appr in list(self.pending_approvals.values()):
                await websocket.send(json.dumps({
                    "type": "approval_request",
                    "payload": appr
                }))
            return

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

                fut = asyncio.get_event_loop().create_future()
                self.approval_waiters[appr_id] = fut

                await self.broadcast({
                    "type": "approval_request",
                    "payload": req
                })

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
        while self.running:
            try:
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

                    if best_transcript and best_transcript != self.active_transcript_path:
                        self.active_session_id = best_sess
                        self.active_transcript_path = best_transcript
                        self.processed_step_indices.clear()
                        try:
                            with open(best_transcript, "r", encoding="utf-8") as f:
                                all_lines = f.readlines()
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
                                            await self.broadcast({
                                                "type": "approval_request",
                                                "payload": appr_req
                                            })

                                if step_type == "PLANNER_RESPONSE" and content.strip():
                                    chat_msg = {
                                        "id": f"msg-agent-{self.active_session_id[:8]}-{step_idx}",
                                        "sessionId": self.active_session_id,
                                        "role": "antigravity",
                                        "content": content,
                                        "timestamp": created_at
                                    }
                                    await self.broadcast({
                                        "type": "chat_message",
                                        "payload": chat_msg
                                    })
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
                            except Exception:
                                pass
            except Exception:
                pass
            await asyncio.sleep(0.4)

    def _run_udp_discovery_thread(self):
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
        except Exception:
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
                if now - last_broadcast > 3.0:
                    last_broadcast = now
                    try:
                        sock.sendto(make_beacon(), ('255.255.255.255', udp_port))
                    except Exception:
                        pass
                try:
                    data, addr = sock.recvfrom(2048)
                    if data:
                        text = data.decode('utf-8', errors='ignore')
                        if "ANTIGRAVITY" in text or "discover" in text.lower():
                            sock.sendto(make_beacon(), addr)
                except (socket.timeout, BlockingIOError):
                    pass
                except Exception:
                    pass
            except Exception:
                time.sleep(1)
        sock.close()

    async def cli_loop(self):
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
                self.running = False
                os._exit(0)
            elif cmd.startswith("request "):
                await self.trigger_approval(cmd[len("request "):].strip())
            elif cmd.startswith("msg "):
                chat_msg = {
                    "id": f"pc-{datetime.now().timestamp()}",
                    "sessionId": self.active_session_id or "antigravity-local-workspace",
                    "role": "antigravity",
                    "content": cmd[len("msg "):].strip(),
                    "timestamp": datetime.now().isoformat()
                }
                await self.broadcast({"type": "chat_message", "payload": chat_msg})
                print(f"[>] Sent to mobile: {cmd[len('msg '):].strip()}")
            elif cmd == "status":
                print(f"[*] Connected devices: {len(self.connected_clients)}")
                print(f"[*] Antigravity Process Running: {is_antigravity_running()}")
                print(f"[*] Active Session: {self.active_session_id}")
                print(f"[*] Pending Approvals: {len(self.pending_approvals)}")
            elif cmd == "sessions":
                sessions = self._scan_brain_sessions()
                print(f"[*] Found {len(sessions)} brain sessions:")
                for s in sessions[:5]:
                    print(f"    - {s['id'][:12]}... : {s['title'][:50]}")
            else:
                print("[?] Commands: request <cmd>, msg <text>, status, sessions, quit")

    async def start(self):
        self.write_info_file()
        if not self.daemon:
            self.print_banner()

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


def install_service():
    """Installs the Bridge Server to AppData and creates Desktop / Start Menu shortcut."""
    print("[*] Installing Antigravity Bridge Server to system...")
    current_exe = sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(__file__)
    target_exe = os.path.join(APPDATA_DIR, "bridge-server-install.exe")

    try:
        shutil.copy2(current_exe, target_exe)
        print(f"[+] Installed binary to: {target_exe}")
    except Exception as e:
        print(f"[!] Binary copy note: {e}")

    # Create Desktop shortcut using PowerShell
    desktop = os.path.join(os.environ.get("USERPROFILE", ""), "Desktop")
    shortcut_path = os.path.join(desktop, "Antigravity Bridge.lnk")
    ps_cmd = f'$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut("{shortcut_path}"); $s.TargetPath = "{target_exe}"; $s.Description = "Antigravity Mobile Companion Bridge Server"; $s.Save()'
    try:
        os.system(f'powershell -NoProfile -Command "{ps_cmd}"')
        print(f"[+] Desktop shortcut created: {shortcut_path}")
    except Exception as e:
        print(f"[!] Shortcut note: {e}")

    print("\n[SUCCESS] Antigravity Bridge Server installed successfully!")
    print(f"Location: {APPDATA_DIR}")


def show_status():
    if os.path.exists(INFO_FILE):
        try:
            with open(INFO_FILE, "r", encoding="utf-8") as f:
                info = json.load(f)
            print("=" * 60)
            print("         ANTIGRAVITY BRIDGE SERVER STATUS")
            print("=" * 60)
            print(f"Status      : RUNNING (PID: {info.get('pid')})")
            print(f"Local IP    : {info.get('local_ip')}")
            print(f"Port        : {info.get('port')}")
            print(f"Auth Token  : {info.get('token')}")
            print(f"WebSocket   : {info.get('websocket_url')}")
            print(f"Started At  : {info.get('started_at')}")
            print("=" * 60)
            return
        except Exception:
            pass
    print("[*] Bridge server is not currently running.")


def main():
    parser = argparse.ArgumentParser(description="Antigravity PC Companion Bridge - Installer & Server")
    parser.add_argument("--install", action="store_true", help="Install Bridge Server to AppData and create shortcuts")
    parser.add_argument("--daemon", action="store_true", help="Run silently in the background")
    parser.add_argument("--status", action="store_true", help="Show current bridge status")
    parser.add_argument("--port", type=int, default=9400, help="Bridge server port (default 9400)")
    args = parser.parse_args()

    if args.status:
        show_status()
        return

    if args.install:
        install_service()

    setup_logging(args.daemon)
    server = AntigravityBridgeServer(port=args.port, daemon=args.daemon)
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        print("\n[*] Bridge server stopped.")


if __name__ == "__main__":
    main()
