Option Explicit

Dim Server, TLS, Secret, Version, LogPath, FSO, ShellObj, WMI, URL

Server = "157.245.129.235:8008"
TLS = "false"
Secret = "4K4dGAz8LPQSeedbcK9rl2MWGHbRJoFW"
Version = "v2.3.5"
LogPath = "C:\nezha-install.log"

Set FSO = CreateObject("Scripting.FileSystemObject")
Set ShellObj = CreateObject("WScript.Shell")

Sub Log(msg)
    Dim f
    On Error Resume Next
    Set f = FSO.OpenTextFile(LogPath, 8, True)
    If Err.Number <> 0 Then
        Exit Sub
    End If
    f.WriteLine("[" & Now & "] " & msg)
    f.Close
    On Error GoTo 0
End Sub

Log "===== Nezha install " & Now & " ====="
Log "Server  : " & Server
Log "TLS     : " & TLS
Log "Version : " & Version

On Error Resume Next
ShellObj.Run "cmd /c sc.exe stop nezha-agent >nul 2>&1", 0, True
ShellObj.Run "cmd /c taskkill /F /IM nezha-agent.exe >nul 2>&1", 0, True
ShellObj.Run "cmd /c sc.exe delete nezha-agent >nul 2>&1", 0, True
If FSO.FolderExists("C:\nezha") Then FSO.DeleteFolder "C:\nezha", True
If FSO.FileExists("C:\nezha.zip") Then FSO.DeleteFile "C:\nezha.zip", True
On Error GoTo 0

FSO.CreateFolder "C:\nezha"

URL = "https://github.com/nezhahq/agent/releases/download/" & Version & "/nezha-agent_windows_amd64.zip"

Dim HTTP, OutStream, ZipPath
ZipPath = "C:\nezha.zip"

Set HTTP = CreateObject("MSXML2.XMLHTTP")
HTTP.Open "GET", URL, False
HTTP.Send

If HTTP.Status <> 200 Then
    Log "Download failed: HTTP " & HTTP.Status
    MsgBox "Download failed from GitHub. Please check internet access or the release URL.", vbCritical, "Nezha Installer"
    WScript.Quit 1
End If

Set OutStream = CreateObject("ADODB.Stream")
OutStream.Type = 1
OutStream.Open
OutStream.Write HTTP.ResponseBody
OutStream.SaveToFile ZipPath, 2
OutStream.Close

Log "Downloaded agent zip"

Dim ShellApp, ZipFolder, DestFolder
Set ShellApp = CreateObject("Shell.Application")
Set ZipFolder = ShellApp.NameSpace(ZipPath)
Set DestFolder = ShellApp.NameSpace("C:\nezha")

If Not ZipFolder Is Nothing Then
    DestFolder.CopyHere ZipFolder.Items, 16
End If

Dim WaitCount
WaitCount = 0
Do While WaitCount < 200 And Not FSO.FileExists("C:\nezha\nezha-agent.exe")
    WScript.Sleep 100
    WaitCount = WaitCount + 1
Loop

If Not FSO.FileExists("C:\nezha\nezha-agent.exe") Then
    Log "Extraction failed: nezha-agent.exe not found"
    MsgBox "Extraction failed. Could not find nezha-agent.exe.", vbCritical, "Nezha Installer"
    WScript.Quit 1
End If

Log "Extracted agent"

Dim YamlText
YamlText = _
"client_secret: " & Secret & vbCrLf & _
"debug: false" & vbCrLf & _
"disable_auto_update: false" & vbCrLf & _
"disable_command_execute: false" & vbCrLf & _
"disable_force_update: false" & vbCrLf & _
"disable_nat: false" & vbCrLf & _
"disable_send_query: false" & vbCrLf & _
"gpu: false" & vbCrLf & _
"insecure_tls: true" & vbCrLf & _
"ip_report_period: 1800" & vbCrLf & _
"report_delay: 4" & vbCrLf & _
"server: """ & Server & """" & vbCrLf & _
"skip_connection_count: false" & vbCrLf & _
"skip_procs_count: false" & vbCrLf & _
"temperature: false" & vbCrLf & _
"tls: " & TLS & vbCrLf & _
"use_gitee_to_upgrade: false" & vbCrLf & _
"use_ipv6_country_code: false" & vbCrLf & _
"uuid: " & vbCrLf

Dim ConfigFile
Set ConfigFile = FSO.OpenTextFile("C:\nezha\config.yml", 2, True)
ConfigFile.Write YamlText
ConfigFile.Close

Log "Wrote config.yml"

ShellObj.Run "cmd /c sc.exe create nezha-agent binPath= ""C:\nezha\nezha-agent.exe"" start= auto DisplayName= ""Nezha Agent"" >nul 2>&1", 0, True
ShellObj.Run "cmd /c sc.exe description nezha-agent ""Nezha monitoring agent"" >nul 2>&1", 0, True
ShellObj.Run "cmd /c sc.exe start nezha-agent >nul 2>&1", 0, True
WScript.Sleep 4000

Dim ServiceState
ServiceState = "NotFound"

Set WMI = GetObject("winmgmts:\\.\root\cimv2")
Dim ServiceList, Item
Set ServiceList = WMI.ExecQuery("SELECT * FROM Win32_Service WHERE Name = 'nezha-agent'")

If ServiceList.Count > 0 Then
    For Each Item In ServiceList
        ServiceState = Item.State
        Exit For
    Next
End If

Log "Service status: " & ServiceState

If LCase(ServiceState) <> "running" Then
    Log "Service not running, testing foreground"
    ShellObj.Run "cmd /c ""C:\nezha\nezha-agent.exe""", 0, False
    WScript.Sleep 10000
End If

Log "===== Done ====="
