;### AUTOHOTKEY SCRIPT TO GENERATE MAME PLAYLIST FOR LAKKA/RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv                          ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input                  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%      ; Ensures a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

playlistname = FB Alpha - Arcade Games.lpl
;### Local path to output the playlist file.
;### Should include the .lpl extension.
;### NOTE: THIS SCRIPT WILL DELETE ANY EXISTING FILE WITH THIS NAME
;### As of 5/2016 using the name "MAME.lpl" results in icons appearing for
;### MAME and its playlist entries in Lakka. Other file names may require 
;### adding icons or copying the MAME set.
;### Default: MAME.lpl

dat = FB Alpha v0.2.97.38 (ClrMame Pro XML - Arcade ROMs and Samples).dat
;### Example: C:\MAME\dats\MAME 078.dat
;### local path to a MAME ROM database file

windowsroms = D:\Emulation\Original ROM Sets\FB Alpha 0.2.97.38 Non-Merged\FB Alpha 0.2.97.38\roms
;### Example: C:\MAME 0.78 Non-Merged\roms
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### This path is a MAME ROMs folder accessible to THIS WINDOWS HOST. These 
;### ROMs should be the same set that will be used in Lakka
;### and should be of the same MAME version as the datfile.

lakkaroms = /storage/roms/FB Alpha 0.2.97.38
;### Example: /storage/roms/MAME 0.78
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### MAME ROMs folder on the destination Lakka installation
;### You do not need to have access to these files on the machine which
;### is running this script. The path must accurately point to the location
;### of a copy of the the same ROM set used in the Windows path above.

core = /tmp/cores/fba_libretro.so
;### Example: /tmp/cores/mame2003_libretro.so
;### full path to the MAME core which will be executing this playlist

FileRead, dat, %dat%
FileDelete, %A_ScriptDir%\%playlistname%  		;### Clears old MAME.lpl file if present 
playlistfile := FileOpen(playlistname,"a")  	;### Creates new playlist in 'append' mode

ROMFileList :=  ; Initialize to be blank.
Loop, Files, %windowsroms%\*.zip 
{
    ROMFileList = %ROMFileList%%A_LoopFileName%`n
}
Sort, ROMFileList

Loop, Parse, ROMFileList, `n 
{	
			
	if A_LoopField = 
		continue 	;### continue on blank line (sometimes the last line in the file list)
	if A_LoopField in (neogeo.zip,awbios.zip,cpzn2.zip)
		continue    ;### manually skip these bios files. you can add names of other files to skip

	SplitPath, A_LoopField,,,,filename	 ;### trim the file extension from the name
	
	filter1 = <game name=.%filename%. (isbios|isdevice)
	if RegExMatch(dat, filter1)
		continue                    ;### skip if the file listed as a BIOS or device in the dat
    
    needle = <game name=.%filename%.(?:| ismechanical=.*)(?:| sourcefile=.*)(?:| cloneof=.*)(?:| romof=.*)>\R\s*<description>(.*)</description>
    RegExMatch(dat, needle, datname)

	fancyname := datname1	;### extract match #1 from the RegExMatch result
    if !fancyname
        fancyname := filename   ;### the file is not matched in the dat file, use the filename instead
        
    ;### Replace characters unsafe for cross-platform filenames with underscore, 
    ;### per RetroArch thumbnail/playlist convention
    fancyname := StrReplace(fancyname, "&apos;", "'")
    fancyname := StrReplace(fancyname, "&amp;", "_")
    fancyname := StrReplace(fancyname, "&", "_")
    fancyname := StrReplace(fancyname, "\", "_")
    fancyname := StrReplace(fancyname, "/", "_")
    fancyname := StrReplace(fancyname, "?", "_")
    fancyname := StrReplace(fancyname, ":", "_")
    fancyname := StrReplace(fancyname, "``", "_")    
    fancyname := StrReplace(fancyname, "<", "_")
    fancyname := StrReplace(fancyname, ">", "_")
    fancyname := StrReplace(fancyname, "*", "_")
    fancyname := StrReplace(fancyname, "|", "_")
	
	playlistentry = %lakkaroms%/%filename%.zip`n%fancyname%`n%core%`nDETECT`nDETECT`n%playlistname%`n
	playlistfile.Write(playlistentry)
}

playlistfile.Close()		;## close and flush the new playlist file


;## EOF
