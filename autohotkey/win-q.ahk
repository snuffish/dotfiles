; Invoke Alt+F4 when Win+q is pressed

#Requires AutoHotkey v2.0+
#SingleInstance

#q::
{
    Send "{Alt down}{F4}"
    Send "{Alt up}"
}
