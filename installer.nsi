; DIS-PLAY — NSIS v3+ installer (MUI2)
!include "MUI2.nsh"

Name "DIS-PLAY"
OutFile "dis-play-setup.exe"
InstallDir "$PROGRAMFILES64\DIS-PLAY"
InstallDirRegKey HKCU "Software\DIS-PLAY" "InstallLocation"
RequestExecutionLevel admin
BrandingText "DIS-PLAY"

!define MUI_ABORTWARNING
!define MUI_UNINSTALLER
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "DIS-PLAY Core" SecCore
    SetOutPath "$INSTDIR"

    ; The built tray app
    File "product\target\release\dis-play.exe"

    ; Start-menu shortcuts (launch the tray app; uninstall entry)
    CreateDirectory "$SMPROGRAMS\DIS-PLAY"
    CreateShortCut "$SMPROGRAMS\DIS-PLAY\DIS-PLAY Tray.lnk" "$INSTDIR\dis-play.exe" "tray"
    CreateShortCut "$SMPROGRAMS\DIS-PLAY\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

    ; Uninstaller + registry bookkeeping
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "DisplayName" "DIS-PLAY"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "DisplayIcon" "$INSTDIR\dis-play.exe"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "InstallLocation" "$INSTDIR"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY" "NoRepair" 1
    WriteRegStr HKCU "Software\DIS-PLAY" "InstallLocation" "$INSTDIR"
SectionEnd

Section "Uninstall"
    ; Remove start-menu entries
    Delete "$SMPROGRAMS\DIS-PLAY\DIS-PLAY Tray.lnk"
    Delete "$SMPROGRAMS\DIS-PLAY\Uninstall.lnk"
    RMDir "$SMPROGRAMS\DIS-PLAY"

    ; Remove the autostart Run key written by `autostart register` (D-126)
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "DisPlayTray"

    ; Remove registry bookkeeping
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DIS-PLAY"
    DeleteRegKey HKCU "Software\DIS-PLAY"

    ; Remove installed files
    Delete "$INSTDIR\dis-play.exe"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"
SectionEnd