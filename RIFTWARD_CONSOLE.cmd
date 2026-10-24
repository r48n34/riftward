@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" -Console %*
