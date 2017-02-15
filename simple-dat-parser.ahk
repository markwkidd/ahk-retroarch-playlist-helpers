
;---------------------------------------------------------------------------------------------------------
#NoEnv                         ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                          ;### Enable warnings to assist with detecting common errors.
SendMode Input                 ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%    ;### Ensure a consistent starting directory.
SetBatchLines -1               ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------

global path_to_arcade_ROM_sets := "c:\roms\mame"
global path_to_arcade_dat      := "MAME 0.78 XML.dat"

#include retroarch-playlist-helper-lib.ahk

DAT_array := ""
BuildArcadeDATArray(path_to_arcade_dat, DAT_array, True) ;### DAT_array is now an associative array, indexed by the name of each romset

Loop, Files, %path_to_arcade_ROM_sets%\*.* ;### loop through each file. Could be changed to check only for .zip and/or.7z files
{
	SplitPath, A_LoopFileName,,,,filename_no_ext  ;### trim the file extension from the name to get the ROM set name
	
	ROM_set_details := DAT_array[filename_no_ext] ;### use the filename (no extension) to look up the details from the DAT
	
	ROM_set_information := "ROM set filename: " . A_LoopFileName . "`n"
	ROM_set_information .= "DAT details for: " . ROM_set_details.romset_name . "`n`n"
	ROM_set_information .= "Title: " . ROM_set_details.title . "`n"
	ROM_set_information .= "Needs CHD: " . (ROM_set_details.needs_CHD ? "True" : "False") . "`n"
	ROM_set_information .= "Is BIOS: " . (ROM_set_details.isbios ? "True" : "False") . "`n"
	ROM_set_information .= "Is Device: " . (ROM_set_details.isdevice ? "True" : "False") . "`n"
	ROM_set_information .= "Is Mechanical: " . (ROM_set_details.ismechanical ? "True" : "False") . "`n"
	ROM_set_information .= "Is a clone: " . (ROM_set_details.iscloneof ? "True" : "False") . "`n"
	ROM_set_information .= "Is 'romeof': " . (ROM_set_details.isromof ? "True" : "False") . "`n"
	ROM_set_information .= "Is runnable: " . (ROM_set_details.runnable ? "True" : "False") . "`n"
	ROM_set_information .= "Year: " . ((ROM_set_details.year != "") ? ROM_set_details.year : "Unknown") . "`n"
	ROM_set_information .= "Manufacturer: " ((ROM_set_details.manufacturer != "") ? ROM_set_details.manufacturer : "Unknown") . "`n"
	MsgBox, 1, Simple DAT Parser, %ROM_set_information%
	IfMsgBox, Cancel
	{
		ExitApp
	}
}


