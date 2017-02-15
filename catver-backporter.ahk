;### KNOWN ISSUE - Strings get automatically cast as numbers when used as the key for an associative array
;### The only specific consquence is the "005" ROM set getting mangled because it's leading zeros are dropped
;### but all numeric strings are similarly converted.

;---------------------------------------------------------------------------------------------------------
#NoEnv                         ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                          ;### Enable warnings to assist with detecting common errors.
SendMode Input                 ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%    ;### Ensure a consistent starting directory.
SetBatchLines -1               ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------

#include retroarch-playlist-helper-lib.ahk

FileDelete, catver.ini

DAT_array := ""
BuildArcadeDATArray("MAME 0.37b5.dat", DAT_array)

For romset_index, romset_details in DAT_array
{
	ROM_entry_categories := ""
	current_rom_set_name := romset_details.romset_name
	
	IniRead, ROM_entry_categories, source_catver.ini, Category, %current_rom_set_name%, **Uncategorized**
	IniWrite, %ROM_entry_categories%, catver.ini, Category, %current_rom_set_name%
}

For romset_index, romset_details in DAT_array
{	
	current_rom_set_name := romset_details.romset_name

	ROM_added_version := ""
	IniRead, ROM_added_version, source_catver.ini, VerAdded, %current_rom_set_name%, **Uncategorized**
	IniWrite, %ROM_added_version%, catver.ini, VerAdded, %current_rom_set_name%
}
