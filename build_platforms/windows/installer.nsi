; Songo #5 Windows installer (NSIS 3). build_windows.sh compiles it with
; makensis in Docker, defining:
;   SRC              folder with Songo5.exe, Songo5.pck, the engine DLL, LICENSE.txt
;   ICON             Songo's .ico
;   OUT_FILE         the installer to write
;   VERSION          eg: "v1.0.0 RC8"
;   NUMERIC_VERSION  eg: "1.0.0.0"
;
; Installs for the current user only, in %LOCALAPPDATA%\Programs\Songo5, so it
; needs no admin rights (like VS Code's user installer). Running a newer
; installer over it updates it in place. Uninstalling leaves Songo's own data
; (its library, settings and playlists in %APPDATA%\Godot\app_userdata) alone.

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!define APP_NAME "Songo #5"
!define APP_EXE "Songo5.exe"
!define ENGINE_DLL "libsongo_engine.windows.x86_64.dll"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Songo5"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Songo5"
InstallDirRegKey HKCU "Software\Songo5" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${APP_NAME} ${VERSION}"

VIProductVersion "${NUMERIC_VERSION}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${NUMERIC_VERSION}"
VIAddVersionKey "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey "LegalCopyright" "Licensed under the GNU GPL v3"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME}"
; The finish page's second checkbox, used for the desktop shortcut
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Create a desktop shortcut"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION CreateDesktopShortcut
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SRC}\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
	SetOutPath "$INSTDIR"
	; If Songo is running, NSIS asks to retry once it's closed
	File "${SRC}\${APP_EXE}"
	File "${SRC}\Songo5.pck"
	File "${SRC}\${ENGINE_DLL}"
	File "${SRC}\LICENSE.txt"
	File "/oname=songo.ico" "${ICON}"
	WriteUninstaller "$INSTDIR\Uninstall.exe"

	CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

	WriteRegStr HKCU "Software\Songo5" "InstallDir" "$INSTDIR"
	; Apps & features
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\songo.ico"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
	WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

Function CreateDesktopShortcut
	CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
FunctionEnd

Section "Uninstall"
	Delete "$INSTDIR\${APP_EXE}"
	Delete "$INSTDIR\Songo5.pck"
	Delete "$INSTDIR\${ENGINE_DLL}"
	Delete "$INSTDIR\LICENSE.txt"
	Delete "$INSTDIR\songo.ico"
	Delete "$INSTDIR\Uninstall.exe"
	RMDir "$INSTDIR"

	Delete "$SMPROGRAMS\${APP_NAME}.lnk"
	Delete "$DESKTOP\${APP_NAME}.lnk"

	DeleteRegKey HKCU "${UNINSTALL_KEY}"
	DeleteRegKey HKCU "Software\Songo5"
SectionEnd
