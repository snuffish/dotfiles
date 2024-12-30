#Requires AutoHotkey v2.0+

CapsLock:: {
  Send "{Ctrl Down}"
}

CapsLock up:: {
  Send "{Ctrl Down}{Alt Down}{F5 Down}"
  Send "{Ctrl Up}{Alt Up}{F5 Up}"
}


