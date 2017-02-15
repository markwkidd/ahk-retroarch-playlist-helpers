;### AUTOHOTKEY SCRIPT TO GENERATE MAME PLAYLIST FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv                          ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input                  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%      ; Ensures a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

;### SETUP, ADD YOUR PATHS HERE
;### After the initial setup/run you'll only need to change the top 2 variables for subsequent runs

content = C:\MAME Roms\Fighting
;### Full path of a MAME ROMs folder. 
;### If you run this script multiple times with a different folder set here each time you can make 
;### multiple playlists. For ex., make folders for each genre of ROMs, populate them, and then run 
;### this script on each folder. Result: One RA playlist for each folder.

Playlist = Fighting
;### Name of playlist, no extension; this determines name of playlist file and name of related 
;### subfolder in RetroArch's thumbnails folder. Ex: Fighting   Ex: Driving   Ex: BeatEmUp
;### For instance, Fighting would result in a Fighting.lpl in \playlists and a subfolder called
;### \Fighting in \thumbnails

;### TIP: RA displays playlists in alphanumeric order. If you'd like to control the ordering,
;### prefix each playlist with a number. Ex: 01_Fighting  02_BeatEmUp  03_Action
;### This has the added bonus of making your icon image filenames conveniently cluster together.

MAMESnaps = C:\MAME Roms\~SnapsFriendly
;### Full path of MAME snap (gameplay) images with friendly names (generated with Tatsuya79's MAME 
;### image renaming script). This is optional; you only need this if you want gameplay images in RA)

MAMETitles = C:\MAME Roms\~TitlesFriendly
;### Full path of MAME title screen images with friendly names (generated with Tatsuya79's MAME 
;### image renaming script). This is optional; you only need this if you want title screen images in RA)

MAMEBoxarts = C:\MAME Roms\~BoxartsFriendly
;### Full path of MAME title screen images with friendly names (generated with Tatsuya79's MAME 
;### image renaming script). This is optional; you only need this if you want title screen images in RA)

RAPath = C:\Emulation\RetroArch
;### Full path of Retroarch root folder  Ex: C:\Emulation\RetroArch

RAPlayFold = playlists
;### Name (not full path) of desired RetroArch playlists folder  Ex: playlists  Ex: playlists MAME

RAThumbFold = thumbnails
;### Name (not full path) of desired RetroArch thumbnails folder  Ex: thumbnails  Ex: thumbnails MAME

dat = C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### path to a MAME ROM database file
;### example C:\files\MAME - ROMs (v0.164_XML).dat
;### get dat here http://www.emulab.it/rommanager/datfiles.php
;### or here http://www.progettosnaps.net/dats/

playlistfilename = %RAPath%\%RAPlayFold%\%Playlist%.lpl

FileSetAttrib, -R, %playlistfilename% ; remove read-only attrib from existing playlist file
FileDelete, %playlistfilename%        ; clear existing playlist file
FileCreateDir, %RAPath%\%RAThumbFold%\%Playlist%\Named_Snaps  ; create thumbnail folder
FileCreateDir, %RAPath%\%RAThumbFold%\%Playlist%\Named_Titles ; create thumbnail folder
FileCreateDir, %RAPath%\%RAThumbFold%\%Playlist%\Named_Boxarts ; create thumbnail folder
FileRead, dat, %dat%

playlistfile := FileOpen(playlistfilename,"a") ;### Creates new playlist in 'append' mode

ROMFileList :=  ; Initialize to be blank.
Loop, Files, %content%\*.zip 
{
    ROMFileList = %ROMFileList%%A_LoopFileName%`n	;### store list of ROMs in memory for searching
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
	fancyname := filename ;### the file is not matched in the dat file, use the filename instead
        
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

	playlistentry = %content%\%filename%.zip`r`n%fancyname%`r`nDETECT`r`nDETECT`r`nDETECT`r`n%Playlist%.lpl`r`n

	;MsgBox, %playlistentry% ;for troubleshooting
	
	playlistfile.Write(playlistentry)
	FileCopy, %MAMESnaps%\%datname1%.png, %RAPath%\%RAThumbFold%\%Playlist%\Named_Snaps
	FileCopy, %MAMETitles%\%datname1%.png, %RAPath%\%RAThumbFold%\%Playlist%\Named_Titles
	FileCopy, %MAMEBoxarts%\%datname1%.png, %RAPath%\%RAThumbFold%\%Playlist%\Named_Boxarts
}

playlistfile.Close()					;## close and flush the new playlist file
FileSetAttrib, +R, %playlistfilename%	;## add read-only attrib to playlist file
;## EOF
