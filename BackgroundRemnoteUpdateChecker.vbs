Set objShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
cmdLine = "powershell.exe -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strPath & "\RemNoteUpdater.ps1"" -RunOnce"
objShell.Run cmdLine, 0, False