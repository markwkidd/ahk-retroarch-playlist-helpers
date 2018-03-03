;---------------------------------------------------------------------------------------------------------
#NoEnv                        ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                         ;### Enable warnings to assist with detecting common errors.
SendMode Input                ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%   ;### Ensure a consistent starting directory.
SetBatchLines -1              ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------
global app_title                        := "AHK RetroArch Playlist Core Reset"
global eol_character                    := "`n" ;### determines endline for playlists after processing
debug_mode								:= false

MsgBox,,%app_title%, Beginning core reset. `n`nThis window will close in 2 seconds., 2

Loop, Files, *.lpl
{
	playlist_file            := ""
	playlist_string          := ""
	playlist_contents        := Object()
	new_playlist_string      := ""
	
	if (debug_mode = true) {
	    MsgBox,,%app_title%, Now processing %A_LoopFileName%.`n`nThis window will close in 2 seconds., 2
	}	

	playlist_file     := FileOpen(A_LoopFileName,"r")
	playlist_string   := playlist_file.Read()
	playlist_file.Close()

	Loop, Parse, playlist_string, `n, `r
	{
		playlist_line_count        := A_Index
		playlist_contents[A_Index] := A_LoopField	 
	}
	
	line_index := 1
	while (line_index < playlist_line_count)
	{
	  	new_playlist_string   .= (playlist_contents[line_index])   . eol_character
                               . (playlist_contents[line_index+1]) . eol_character 
                               . "DETECT" . eol_character
                               . "DETECT" . eol_character 
                               . (playlist_contents[line_index+4]) . eol_character
                               . (playlist_contents[line_index+5]) . eol_character
        line_index += 6							   
	}

	FileDelete, %A_LoopFileName%
	playlist_file := FileOpen(A_LoopFileName,"a")
	playlist_file.Write(new_playlist_string)
  	playlist_file.Close()
}

MsgBox,,%app_title%,Playlist core reset done. Click OK to exit. 