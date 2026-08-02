@echo off
rem codex-swap launcher (Windows)
where pwsh >nul 2>&1
if not errorlevel 1 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\src\codex-swap.ps1" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\src\codex-swap.ps1" %*
)
