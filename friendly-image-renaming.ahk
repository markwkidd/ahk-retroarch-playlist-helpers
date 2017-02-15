;### AUTOHOTKEY SCRIPT TO RENAME ARCADE THUMBNAILS FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv  			; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  				; Enable warnings to assist with detecting common errors.
SendMode Input  		; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  	; Ensures a consistent starting directory.
SetBatchLines -1		; Never yield the CPU to other processes. Comment this line out if there are CPU utilization issues
;---------------------------------------------------------------------------------------------------------

;### SETUP: ADD YOUR PATHS HERE

artsource = C:\MAME Roms\~Snaps
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the source thumbnails folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example: C:\MAME 0.78 images\titles

destinationfolder = C:\MAME Roms\~SnapsFriendly
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the destination thumbnail folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example C:\MAME 0.78 images\Named_Titles

dat = C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### Example: C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### local path to a MAME ROM database file
;### The most recent MAME DAT can be found here  http://www.emulab.it/rommanager/datfiles.php
;### DAT files for current and past MAME releases are available at http://www.progettosnaps.net/dats/

;### TIP: If you're renaming Snaps, Titles, and Boxart thumbnails, it is possible to make three copies of this script,
;### point the folder paths at the other image types, and run all at once.

if !FileExist(dat) or !FileExist(artsource) or !FileExist(destinationfolder)
	return 	;### If any of these files and folders desn't exist, exit the script

slimdat := 	;### Initialize to eliminate warning

FileRead, datcontents, %dat%
Loop, Parse, datcontents, `n, `r
 If (InStr(A_LoopField, "<game name=") or InStr(A_LoopField, "<description>"))  ;only keep relevant lines
 slimdat .= A_LoopField "`n"
datcontents := slimdat

ThumbnailFileList :=  ; Initialize to be blank.
Loop, Files, %artsource%\*.png
{
	;### Skip known dummy images
	;57825 bytes mechanical
	;56475 bytes device
	;56467 bytes device
	;53461 bytes screenless system
	;53466 bytes screenless system
	;53472 bytes screenless system
	;53474 bytes screenless system
	;9970 bytes screenless system
	;55932 bytes device
	;57281 bytes mechanical
	FileGetSize, s, % A_LoopFileFullPath
	if (s==57825) or (s==56475) or (s==56467) or (s==53466) or (s==9970) or (s==53472) or (s==55932) or (s==57281) or (s==53474) or (s==53461)
	 	continue
    	ThumbnailFileList = %ThumbnailFileList%%A_LoopFileName%`n	;### store list of ROMs in memory for searching
}
Sort, ThumbnailFileList

posi = 1
needle = <description>(.*)</description>

Loop, Parse, ThumbnailFileList, `n, `r
{
if A_LoopField =
    continue
SplitPath, A_LoopField,,,,filename     					;### trim the file extension from the name
posi := InStr(datcontents, "game name=""" filename """",false,posi)     ;### find the filename's position in datcontents
if !posi
 posi := InStr(datcontents, "game name=""" filename """")
if !posi
 continue
RegExMatch(datcontents,"U)" needle, datname, posi) 			;### start regex from filename position
if !datname1
 continue
fancyname := character_sanitize(datname1)
FileCopy, %artsource%\%filename%.png, %destinationfolder%\%fancyname%.png, 1
}

character_sanitize(x) {						;## fix forbidden chars for multi-platform use
	x := StrReplace(x, "&apos;", "'")
	x := StrReplace(x, "&amp;", "_")
	x := StrReplace(x, "&", "_")
	x := StrReplace(x, "\", "_")
	x := StrReplace(x, "/", "_")
	x := StrReplace(x, "?", "_")
	x := StrReplace(x, ":", "_")
	x := StrReplace(x, "``", "_")	
	x := StrReplace(x, "<", "_")
	x := StrReplace(x, ">", "_")
	x := StrReplace(x, "*", "_")
	x := StrReplace(x, "|", "_")
	return x
}
