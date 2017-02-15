;### AUTOHOTKEY SCRIPT TO RENAME ARCADE THUMBNAILS FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv  			; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  				; Enable warnings to assist with detecting common errors.
SendMode Input  		; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  	; Ensures a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

;### SETUP: ADD YOUR PATHS HERE

artsource = C:\MAME 0.78 images\titles
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the source thumbnails folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example: C:\MAME 0.78 images\titles

processed = C:\MAME 0.78 images\Named_Titles
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the destination thumbnail folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example C:\MAME 0.78 images\Named_Titles

dat = C:\MAME\dats\MAME 078.dat
;### Example: C:\MAME\dats\MAME 078.dat
;### local path to a MAME ROM database file

if !FileExist(dat) or !FileExist(artsource) or !FileExist(processed)
	return 	;### If any of these files and folders desn't exist, exit the script

FileDelete, Unmatched Thumbnails - %dat%.log	;### Delete old 'ummatched' log file, if it exists

FileRead, datcontents, %dat%

rawcounter = 0
A_Loop_File_Name = 0

Loop, %artsource%\*.png {
 
	SplitPath, A_LoopFileName,,,,filename	;### trim the file extension from the name

	needle = <game name=.%filename%.(?:| ismechanical=.*)(?:| sourcefile=.*)(?:| cloneof=.*)(?:| romof=.*)>\R\s*<description>(.*)</description>
	RegExMatch(datcontents, needle, datname)
	fancyname := datname1	;### extract match #1 from the RegExMatch result
	
	if !fancyname
	{
        fancyname := filename   		;### the image filename/rom name is not matched in the dat file
 		FileAppend, Unmatched Source %artsource%\%filename%.png`n`n, %processed%\Unmatched Thumbnails.log  ;### for error checking
		continue 			;### then skip to the next image
	}
    
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

	destinationfile := processed . "`\" . fancyname . ".png"
;	if FileExist(destinationfile)
;	{ 
;	continue	;### skip onward if this file already exists
;	}	
	FileCopy, %artsource%\%filename%.png, %destinationfile% , 1
}
