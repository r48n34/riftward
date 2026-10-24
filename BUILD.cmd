@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_export.ps1" %*
