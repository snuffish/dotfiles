﻿; Disable CapsLock
; When CapsLock is `Tap` pressed - invoke <Esc> key
; When CapsLock is `Held` pressed - invoke hold on <LCtrl> key

#Requires AutoHotkey v2.0+
#SingleInstance

SetCapsLockState "AlwaysOff"

ih := InputHook("B L1 T1", "{Esc}")

*CapsLock::
{
	ih.Start()
	reason := ih.Wait()
	if (reason = "Stopped") {
		Send "{Esc}"
	} else if (reason = "Max") {
		Send "{Blind}{Ctrl down}" ih.Input
	}
}

*CapsLock up::
{
	if (ih.InProgress) {
		ih.Stop()
	} else {
		Send "{Ctrl up}"
	}
}
