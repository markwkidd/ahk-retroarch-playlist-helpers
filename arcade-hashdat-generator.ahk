
;---------------------------------------------------------------------------------------------------------
#NoEnv                         ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                          ;### Enable warnings to assist with detecting common errors.
SendMode Input                 ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%    ;### Ensure a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

#include retroarch-playlist-helper-lib.ahk

global source_DAT         := "MAME 078.dat"
;### Example: C:\MAME\dats\MAME 078.dat
;### local path to a MAME ROM database file

global new_DAT_name       := "MAME 0.78 Split TorrentZipped (No BIOS)"
global new_DAT_filename   := new_dat_name . ".dat"
global new_DAT_version    := ""
FormatTime, new_DAT_version,, yyyy-MM-dd
;### NOTE: THIS SCRIPT WILL DELETE ANY EXISTING FILE WITH THIS NAME

global windowsroms        := "d:\emulation\original rom sets\mame 0.78 split\roms"
;### Example: C:\MAME 0.78 Non-Merged\roms
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### This path is a MAME ROMs folder accessible to THIS WINDOWS HOST. These 
;### ROMs should be of the same MAME version as the datfile.

global DAT_array          := ""
BuildArcadeDATArray(source_dat, DAT_array, True)

Main()

source_DAT         := "MAME 0.139.dat"
new_DAT_name       := "MAME 0.139 Non-Merged TorrentZipped (No BIOS)"
new_DAT_filename   := new_dat_name . ".dat"
FormatTime, new_DAT_version,, yyyy-MM-dd
windowsroms        := "d:\emulation\original rom sets\mame 0.139 non-merged\roms"
global DAT_array          := ""
BuildArcadeDATArray(source_dat, DAT_array, True)

Main()

source_DAT         := "MAME 159.dat"
new_DAT_name       := "MAME 0.159 Non-Merged TorrentZipped (No BIOS, Device, Mechanical)"
new_DAT_filename   := new_dat_name . ".dat"
FormatTime, new_DAT_version,, yyyy-MM-dd
windowsroms        := "d:\emulation\original rom sets\mame 0.159 non-merged\roms"
global DAT_array          := ""
BuildArcadeDATArray(source_dat, DAT_array, True)

Main()

Main() {
	FileDelete, %new_DAT_filename%  		            ;### Clears old file if present 
	new_DAT_file := FileOpen(new_DAT_filename,"a")  	;### Creates new playlist in 'append' mode

	new_DAT_file.Write("clrmamepro (`n")
	new_DAT_file.Write("	name """ . new_dat_name . """`n")
	new_DAT_file.Write("	version " . new_DAT_version . "`n")
	new_DAT_file.Write(")`n`n")

	ROM_file_list  :=  "" ;### Initialize to be blank.
	file_list_size := 0
	Loop, Files, %windowsroms%\*.zip 
	{
		ROM_file_list    .= A_LoopFileName . "`n"
		file_list_size := A_Index
	}
	Sort, ROM_file_list

	Progress, 0, Calculating checksums, , DIR2DAT
	percent_parsed := 0
	Progress, percent_parsed

	Loop, Parse, ROM_file_list, `n 
	{
		if(A_LoopField == "") { ;### catch that parser returns the last, blank line in the list.
			break
		}
		
		percent_parsed := Round(100 * (A_index / file_list_size))
		Progress, %percent_parsed%
		SplitPath, A_LoopField,filename_with_ext,,,filename_no_ext	 ;### trim the file extension from the name
			
		DAT_entry := DAT_array[filename_no_ext]
		
		if(MatchDATFilterCriteria(DAT_entry)) {
			continue
		}		
		
		fancyname := DAT_entry.title
		year      := DAT_entry.year
		developer := DAT_entry.manufacturer
		
		
		full_cksum_command := "crc32.exe """ . windowsroms . "\" . filename_with_ext . """ -nf"
		cksum_raw_out := RunWaitOne(full_cksum_command)
		
		parse_result_1 := ""
		parse_result_2 := ""
		Loop, Parse, cksum_raw_out, `n, `r
		{
			parse_result_%A_Index% := A_LoopField
			StringLower, parse_result_%A_Index%, parse_result_%A_Index%
			Trim(parse_result_%A_Index%, " `t`n`r")
		}
		
		crc_value := parse_result_1
		filesize  := parse_result_2

		full_cksum_command := "CertUtil -hashfile """ . (windowsroms . "\" . filename_with_ext) . """ MD5"

		cksum_raw_out := RunWaitOne(full_cksum_command)
		Loop, Parse, cksum_raw_out, `n, `r
		{
			if(A_Index == 2) {
				md5_value := StrReplace(A_LoopField, " ")
				md5_vlaue := Trim(md5_value, " `t`n`r")
			}
		}
		
		full_cksum_command := "CertUtil -hashfile """ . (windowsroms . "\" . filename_with_ext) . """ SHA1"	
		cksum_raw_out := RunWaitOne(full_cksum_command)
		Loop, Parse, cksum_raw_out, `n, `r
		{
			if(A_Index == 2) {
				sha1_value := StrReplace(A_LoopField, " ")
				sha1_value := Trim(sha1_value, " `t`n`r")
			}
		}
		
		DAT_entry := "game (`n"
		DAT_entry .= "`tname """ . fancyname . """`n"
		DAT_entry .= (year      != "") ? "`tyear """ . year . """`n" : ""
		DAT_entry .= (developer != "") ? "`tdeveloper """ . developer . """`n" : ""
		DAT_entry .= "`trom ( name " . filename_with_ext . " size " . filesize . " crc " . crc_value . " md5 " . md5_value . " sha1 " . sha1_value . " )"
		DAT_entry .= "`n)`n`n"
		
		new_DAT_file.Write(DAT_entry)
	}

	new_DAT_file.Close()		;## close and flush the new playlist file
	Progress, Off
}

;---------------------------------------------------------------------------------------------------------

MatchDATFilterCriteria(ByRef DAT_entry) {

	If(DAT_entry.isbios) {
		Return True
	}
	if(DAT_entry.isdevice) {
		Return True
	}
	if(DAT_entry.ismechanical) {
		Return True
	}
	return False
}

;---------------------------------------------------------------------------------------------------------

RunWaitOne(command) {
    ; WshShell object: http://msdn.microsoft.com/en-us/library/aew9yb99
    shell := ComObjCreate("WScript.Shell")
    ; Execute a single command via cmd.exe
    exec := shell.Exec(ComSpec " /C " command)
    ; Read and return the command's output
    return exec.StdOut.ReadAll()
}
