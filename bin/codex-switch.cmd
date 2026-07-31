@echo off
rem codex-switch launcher (Windows)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\src\codex-switch.ps1" %*
