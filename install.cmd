@echo off
powershell -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Monsuru12311/Install/main/Install-NezhaAgent.ps1' -OutFile 'C:\Temp\Install-NezhaAgent.ps1'; Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"C:\Temp\Install-NezhaAgent.ps1\"' -Verb RunAs"
