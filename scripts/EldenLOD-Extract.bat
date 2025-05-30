@echo off
powershell -Verbose -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
