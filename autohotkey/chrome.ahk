; Chrome hotkeys

#Requires AutoHotkey v2.0

#HotIf WinActive("ahk_exe chrome.exe")
^!c:: {
    MsgBox("This hotkey only works when Chrome is open!")
}

^!Left:: {
    Send "{Ctrl down}{Shift down}{Tab}"
}

^!Right:: {
    Send "{Ctrl down}{Tab}"
}

#HotIf