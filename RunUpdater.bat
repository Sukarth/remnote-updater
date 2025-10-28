@echo off
:: RemNote Auto Updater Launcher
:: Runs the PowerShell script in hidden mode

powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0RemNoteUpdater.ps1"
