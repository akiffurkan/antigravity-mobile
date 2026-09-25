Set WshShell = CreateObject("WScript.Shell")
strPath = "C:\Users\akiff\AppData\Local\Programs\Python\Python312\pythonw.exe ""c:\Users\akiff\Desktop\Antigravity Mobil\bridge_server\antigravity_bridge.py"" --daemon"
WshShell.Run strPath, 0, False
