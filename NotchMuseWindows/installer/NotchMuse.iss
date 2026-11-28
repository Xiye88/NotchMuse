#define MyAppName "NotchMuse"
#define MyAppVersion "0.9.0"
#define MyAppPublisher "NotchMuse"
#define MyAppExeName "NotchMuse-Windows-win-x64-portable.exe"

[Setup]
AppId={{C5A9D0F4-9D5D-4F04-BE7F-5D0AF15C8B4A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\NotchMuse
DefaultGroupName=NotchMuse
OutputDir=..\artifacts\release
OutputBaseFilename=NotchMuse-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=..\assets\NotchMuse.ico
UninstallDisplayIcon={app}\NotchMuse-Windows-win-x64-portable.exe
WizardStyle=modern
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式 (Create a desktop shortcut)"; GroupDescription: "附加任务 (Additional icons):"

[Files]
Source: "..\artifacts\release\NotchMuse-Windows-win-x64-portable.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\NotchMuse"; Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"; IconFilename: "{app}\NotchMuse-Windows-win-x64-portable.exe"
Name: "{autodesktop}\NotchMuse"; Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"; IconFilename: "{app}\NotchMuse-Windows-win-x64-portable.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"; Description: "立即启动 NotchMuse (Launch NotchMuse)"; Flags: nowait postinstall skipifsilent
