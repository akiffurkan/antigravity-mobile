"""Antigravity Bridge Server - Controller (status, start, stop)."""
import sys
import os
import json
import time
import subprocess

try:
    import psutil
except ImportError:
    psutil = None

BRIDGE_DIR = os.path.dirname(os.path.abspath(__file__))
PID_FILE = os.path.join(BRIDGE_DIR, "bridge.pid")
INFO_FILE = os.path.join(BRIDGE_DIR, "bridge_info.json")
BRIDGE_SCRIPT = os.path.join(BRIDGE_DIR, "antigravity_bridge.py")

def get_running_pid():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            if psutil and psutil.pid_exists(pid):
                return pid
            elif not psutil:
                return pid
        except Exception:
            pass
    return None

def status():
    pid = get_running_pid()
    print("=" * 60)
    print("         ANTIGRAVITY BRIDGE SERVER STATUS")
    print("=" * 60)
    if pid and os.path.exists(INFO_FILE):
        try:
            with open(INFO_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            print(f"Status          : RUNNING (PID: {pid})")
            print(f"Local IP        : {data.get('local_ip')}")
            print(f"Port            : {data.get('port')}")
            print(f"Auth Token      : {data.get('token')}")
            print(f"WebSocket URL   : {data.get('websocket_url')}")
            antigravity_stat = "Running" if data.get("antigravity_running") else "Not Detected"
            print(f"Antigravity App : {antigravity_stat}")
            print(f"Started At      : {data.get('started_at')}")
        except Exception as e:
            print(f"Status          : RUNNING (PID: {pid})")
            print(f"Error reading info: {e}")
    else:
        print("Status          : STOPPED / NOT RUNNING")
        print("To start run    : double-click start_bridge.bat or run_bridge_silent.vbs")
    print("=" * 60)

def stop():
    print("Stopping Antigravity Bridge Server...")
    pid = get_running_pid()
    if pid:
        try:
            if psutil:
                p = psutil.Process(pid)
                p.terminate()
                p.wait(timeout=3)
            else:
                os.system(f"taskkill /F /PID {pid} >nul 2>&1")
            print(f"Successfully stopped Bridge Server (PID: {pid}).")
        except Exception as e:
            print(f"Bridge process terminated: {e}")
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
    else:
        print("No active Bridge Server process found.")

def start():
    pid = get_running_pid()
    if pid:
        print(f"Bridge Server is ALREADY running (PID: {pid}).")
        return
    python_dir = os.path.dirname(sys.executable)
    pythonw = os.path.join(python_dir, "pythonw.exe")
    if not os.path.exists(pythonw):
        pythonw = "pythonw"
    
    # 0x08000000 = CREATE_NO_WINDOW
    subprocess.Popen([pythonw, BRIDGE_SCRIPT, "--daemon"], creationflags=0x08000000)
    time.sleep(1)
    new_pid = get_running_pid()
    if new_pid:
        print(f"Bridge Server started in background (PID: {new_pid}).")
    else:
        print("Bridge Server started.")

if __name__ == "__main__":
    action = sys.argv[1].lower() if len(sys.argv) > 1 else "status"
    if action == "status":
        status()
    elif action == "stop":
        stop()
    elif action == "start":
        start()
    else:
        print(f"Unknown action: {action}. Usage: bridge_control.py [status|start|stop]")
