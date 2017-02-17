;---------------------------------------------------------------------------------------------------------
#NoEnv                        ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                         ;### Enable warnings to assist with detecting common errors.
SendMode Input                ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%   ;### Ensure a consistent starting directory.
SetBatchLines -1              ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------
global app_title        := "DIR2DAT Consolidator"
global DAT_path         := "C:\mamdedats"
global new_DAT_name     := "Consolidated Arcade Sets"
global new_DAT_filename := new_DAT_name . ".dat"
global new_DAT_version  := ""
FormatTime, new_DAT_version,, yyyy-MM-dd
global new_DAT_string   := ""
global hash_collisions  := ""

MsgBox,,%app_title%, Beginning DAT consolidation. `n`nThis window will close in 2 seconds., 2

Loop, Files, %DAT_path%\*.dat
{
	DAT_file          := ""
	DAT_string        := ""
	DAT_contents      := Object()
	
	if (True) {
	    MsgBox,,%app_title%, Now processing %A_LoopFileName%.`n`nThis window will close in 2 seconds., 2
	}	

	DAT_file     := FileOpen((DAT_path . "\" . A_LoopFileName),"r")
	DAT_string   := DAT_file.Read()
	DAT_file.Close()

	scanning_pos := 0
	Loop {
		scanning_pos++
        scanning_pos := InStr(DAT_string, "game (`n",, scanning_pos)
		if(!scanning_pos) {
			break
		}
		record_end    := InStr(DAT_string, ")`n)`n`n",, scanning_pos)
		record_string := SubStr(DAT_string, scanning_pos, (record_end - scanning_pos)) . ")`n)`n`n"
        record_CRC    := SubStr(record_string, (InStr(record_string, "crc")), 12)
		record_SHA1   := SubStr(record_string, (InStr(record_string, "sha1")), 45)
		
        if(InStr(new_DAT_string, record_CRC)) { ;### exactly matching SHA1 -- do not add again
            hash_collisions .= record_string
;            MsgBox, %record_string%
			continue
		}
	  	new_DAT_string .= record_string
	}
}

new_DAT_file := FileOpen(new_DAT_filename,"w") ;### deletes any existing file
new_DAT_file.Write("clrmamepro (`n")
new_DAT_file.Write("	name """ . new_dat_name . """`n")
new_DAT_file.Write("	version " . new_DAT_version . "`n")
new_DAT_file.Write(")`n`n")
new_DAT_file.Write(new_DAT_string)

hash_collisions_file := FileOpen("hash_collisions.dat","w") ;### deletes any existing file
hash_collisions_file.Write("clrmamepro (`n")
hash_collisions_file.Write("	name """ . new_dat_name . " - Hash Collisions""`n")
hash_collisions_file.Write("	version " . new_DAT_version . "`n")
hash_collisions_file.Write(")`n`n")
hash_collisions_file.Write(hash_collisions)

MsgBox,,%app_title%,DAT consolidation complete. Click OK to exit. 
