;### RETROARCH PLAYLIST BUDDY - GENERATE PLAYLISTS AND THUMBNAILS
;### By markwkidd and inspired by work by libretro forum users roldmort, Tetsuya79, and Alexandra
;### Icon by Alexander Moore @ http://www.famfamfam.com/

;---------------------------------------------------------------------------------------------------------
#NoEnv                         ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                          ;### Enable warnings to assist with detecting common errors.
SendMode Input                 ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%    ;### Ensure a consistent starting directory.
SetBatchLines -1               ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------

#include retroarch-playlist-helper-lib.ahk

global app_title                         := "RetroArch Playlist Buddy"
global app_mode                          := 0 ;### Tracks user's choice for playlist generator versus playlist processor mode

;### INITIALIZE GLOBAL VARIABLES
;### Leave blank to prompt for all values in GUI
;### Enter values in the script to serve as defaults in GUI

global base_rom_path                    := ""
global base_rom_path_label              := "Base ROM Path"
global base_rom_path_description        := "During the next step you can select subfolders to scan within this path. Ex: C:\roms"

;### If ROMs are in folders called C:\roms\Fighting and C:\roms\Driving, then the base ROM directory is c:\roms
global RA_core_path                     := "DETECT"
global RA_core_path_label               := "Playlist path to a RetroArch core (ends in .dll or .so)"

global playlist_path                    := ""
global playlist_path_config_label       := "RetroArch playlist path"

global arcade_mode                      := False
global dat_path                         := "" ;### path to an arcade XML DAT file
global dat_array						:= "" ;### will store essential information from the DAT
global dat_config_desc                  := "<a href=""http://progettosnaps.net/dats"">Download MAME DATs</a> - "
                                         . "<a href=""https://github.com/libretro/fbalpha/tree/master/dats"">Download FB Alpha DATs</a>"

global unix_playlist                    := False ;### Default to False
global unix_playlist_config_label       := "Use forward slashes in playlist paths for Android, Lakka, Linux, OS X"
global alternate_path_config_label      := "Use a different base ROM path in playlist than the local ROM path that is scanned.`n"
                                         . "Intended for deploying playlists to a different Android, Lakka, Linux, or OS X system."
                                         
global use_alternate_rom_path           := False ;### Default to False
global alternate_rom_path               := "/storage/roms"
;### alternate_rom_path: Location of the base ROM folder for the RetroArch installation
;### where the playlist(s) will be used as opposed to the ROM path used to scan for ROMs

global local_art_path_label             := "You will need <a href=""http://thumbnailpacks.libretro.com/"">libretro thumbnail packs</a> or <a href=""http://www.progettosnaps.net/snapshots/"">conventional MAME thumbnail sets</a> for local scraping."
global local_art_path_check_text        := "Scrape local thumbnail source images at the following base path:"
global local_art_path                   := "" ;### Can be left blank if not using a local thumbnail source.

global full_rom_subfolder_list          := ""
global selected_rom_subfolder_list		:= ""
global full_playlist_list               := ""
global selected_playlist_list           := ""

global recurse_ROM_subfolders           := False
global ROM_inclusion_filter             := "*.*"

global reset_playlist_cores             := False
global process_local_thumbs             := False  ;### Default is False
global process_remote_thumbs            := False  ;### Default is False
global attempt_thumbnail_download_label := "[Experimental] Try to download individual thumbnails"

global use_libretro_mame_thumb          := False  ;### Default is False for arcade mode thumbnail setting
global use_libretro_fba_thumb           := False  ;### Default is False for arcade mode thumbnail setting 
global use_std_mame_thumb               := False  ;### Default is False for arcade mode thumbnail setting 

global remote_libretro_parent_repo      := "http://thumbnails.libretro.com"
global remote_libretro_mame_repo        := remote_libretro_parent_repo . "/MAME"
global remote_libretro_fba_repo         := remote_libretro_parent_repo . "/FB Alpha - Arcade Games"
global remote_std_mame_repo             := "http://adb.arcadeitalia.net/media/mame.current"

global thumbnail_category_list          := "Named_Boxarts|Named_Snaps|Named_Titles" ;### List of thumbnail subfolders to match
global trigger_generation               := False  ;### Control variable to indicate whether to proceed with final generation
global audit_thumbnails                 := False   ;### Create a log of unmatched thumbnails
global unmatched_thumb_log_filename      := "unmatched_thumbnails.log"

global eol_character                    := "`n" 
global playlist_path_delimiter          := "\"    ;### Default to Windows paths

;---------------------------------------------------------------------------------------------------------

;### GUI Configuration
global heading_font_config    := "s12 w700"
global subheading_font_config := "s10 w700"
global body_font_config       := "s10 w400"
global app_window_w           := 740
global box_w                  := app_window_w - 30
global groupbox_contents_w    := app_window_w - 60
global textbox_w              := Round(2 * (box_w / 3))
global prev_button_x          := box_w - 210
global next_button_x          := box_w - 100

;---------------------------------------------------------------------------------------------------------

Main()

;---------------------------------------------------------------------------------------------------------

Main() {
	app_mode := SelectAppModeGUI()
    if(app_mode == 0) {
        Generator()
        Return
    }
    if(app_mode == 1) {
        Processor()
        Return
    }
    if(app_mode == 3) {
        ExitApp
    }
}

;---------------------------------------------------------------------------------------------------------

Generator() {

    DAT_array           := ""
    
    PrimaryGeneratorGUI()                  ;### Prompt the user to enter the configuration 
    WinWaitClose

	full_rom_subfolder_list := ""          ;### reinitialize each time the first menu is closed, in case the base directory has changed
	if(unix_playlist) {
		playlist_path_delimiter = /
	}
	
	Trim(playlist_path)
	StripFinalSlash(playlist_path)         ;## Remove any trailing forward or back slashes from user-provided paths
	Trim(base_rom_path)
	StripFinalSlash(base_rom_path)
	Trim(alternate_rom_path)
	StripFinalSlash(alternate_rom_path)	
	Trim(RA_core_path)

	if !FileExist(base_rom_path) {
        MsgBox,,Path Error!, Base ROM directory does not exist:`n%base_rom_path%
        Generator()
        Return
	} else if ((arcade_mode) and (!FileExist(dat_path))) {
		MsgBox,,Path Error!, Arcade mode enabled, but DAT file not found:`n%dat_path%
        Generator()
        Return
	} else if !FileExist(playlist_path) {
		MsgBox,,Path Error!, Playlist path does not exist:`n%playlist_path%
        Generator()
        Return
    }

	Loop, Files, %base_rom_path%\*.*, D	   ;### Loop through base ROM folder, looking only for subfolders
	{
		full_rom_subfolder_list .= (A_LoopFileName . "|")
	}
	StringTrimRight, full_rom_subfolder_list, full_rom_subfolder_list, 1	;### remove extra | pipe character at end. not elegant.
    
    proceed := False
	SecondaryGeneratorGUI(proceed)
	WinWaitClose
    if(!proceed) {
        Generator()
        Return
    }

	if(arcade_mode) {
		BuildArcadeDATArray(dat_path, DAT_array, True)
	}
		
	Loop, Parse, selected_rom_subfolder_list, |
	{	
		ROM_file_array := Object() ;### Reinitialize file list for each subfolder loop
		playlist_name  := A_LoopField
		file_list      := ""
        
        if(recurse_ROM_subfolders) {
            Loop, Files, %base_rom_path%\%playlist_name%\%ROM_inclusion_filter%, R
            {
                file_list  .= A_LoopFileLongPath . "`n"
            }
            Trim(file_list)
        } else {
		    Loop, Files, %base_rom_path%\%playlist_name%\%ROM_inclusion_filter%
		    {
                file_list  .= A_LoopFileLongPath . "`n"
            }
            Trim(file_list)
        }
        
        Loop, Parse, file_list, `n
        {
			SplitPath, A_LoopField,,,,ROM_filename_no_ext
			ROM_details := DAT_array[ROM_filename_no_ext]
					
			if(arcade_mode && MatchDATFilterCriteria(rom_details)) {
				continue
			}
			if((ROM_details == "") || (ROM_details.title == "")) {
				ROM_details := {Title:ROM_filename_no_ext} 
			}
			
			ROM_details.path                     := A_LoopField
			ROM_file_array[ROM_filename_no_ext]  := ROM_details
		}
		
		playlist_filename := playlist_path . "\" . playlist_name . ".lpl"	
		PlaylistGenerator(ROM_file_array
                        , playlist_filename
                        , playlist_name
                        , (use_alternate_rom_path ? alternate_ROM_path : base_rom_path)
                        , playlist_path_delimiter, True)
		

	}

	MsgBox,,%app_title%,Playlist generation complete. Click OK to return to the generator menu.
    Generator() ;### return to first generator screen when complete
    Return
}

;---------------------------------------------------------------------------------------------------------

Processor() {

    unmatched_thumb_log  := ""
    unmatched_thumb_list := ""
    
    PrimaryProcessorGUI()             ;### Prompt the user to enter the configuration 
    WinWaitClose

	full_playlist_list := ""          ;### reinitialize each time the first menu is closed, in case the playlist directory has changed

	Trim(playlist_path)
	StripFinalSlash(playlist_path)    ;## Remove any trailing forward or back slashes from user-provided paths    
    Trim(local_art_path)
	StripFinalSlash(local_art_path)

    if !FileExist(playlist_path) {
		MsgBox,,Path Error!, Playlist path does not exist:`n%playlist_path%
        Processor()
        Return
    } else if (process_local_thumbs and (local_art_path = "" or !FileExist(local_art_path))) {
		MsgBox,,Path Error!, Local art directory was specified but does not exist:`n%local_art_path%
        Processor()
        Return
    }
    
	Loop, Files, %playlist_path%\*.lpl
	{
		full_playlist_list .= (A_LoopFileName . "|")
	}
	StringTrimRight, full_playlist_list, full_playlist_list, 1	;### remove extra | pipe character at end. not elegant.
    
    proceed := False
    SecondaryProcessorGUI(proceed)
	WinWaitClose
    if(!proceed) {
        Processor()
        Return
    }
	
	if(audit_thumbnails) {
		unmatched_thumb_log := FileOpen(unmatched_thumb_log_filename,"w") ;### Deletes any existing file
	}
  
	Loop, Parse, selected_playlist_list, |
	{	    
        SplitPath, A_LoopField,,,,playlist_file_no_ext
        playlist_filename        := playlist_path . "\" . A_LoopField
        MsgBox, playlsitfilename %playlist_filename%
        playlist_file            := FileOpen(playlist_filename,"r")
        playlist_string          := playlist_file.Read()
        playlist_line_count      := 0
        playlist_file.Close()        
        playlist_contents        := Object()
        new_playlist_string      := ""
 
 ; IS THIS REALLY NEEDED OR WOULD A COPIED FILE CREATE ANY NEEDED FOLDERS ABOVE IT?
 ;   	if(process_local_thumbs || process_remote_thumbs) {	;### create thumbnail subfolder
 ;           Loop, Parse, thumbnail_category_list, |
 ;           {
 ;               thumbnail_category_name := A_LoopField
 ;               FileCreateDir, %playlist_path%\..\thumbnails\%playlist_file_no_ext%\%thumbnail_category_name%
 ;           }
 ;       }
 
        Loop, Parse, playlist_string, `n, `r
        {
            playlist_line_count        := A_Index
            playlist_contents[A_Index] := A_LoopField
        }
 
		if(process_local_thumbs) {
            Progress, A M T, Processing thumbnails for:`n%playlist_file_no_ext%, Local thumbnail repository`n, %app_title%
            line_index := 1
            while (line_index < playlist_line_count)
            {
                percent_parsed := Round(100 * (line_index / playlist_line_count))
                Progress, %percent_parsed%				
                
                title := Trim(playlist_contents[line_index+1])
                sanitized_name := SanitizeFilename(title)
                
                Loop, Parse, thumbnail_category_list, |
                {
                    local_image_path = %playlist_path%\..\thumbnails\%playlist_file_no_ext%\%A_LoopField%\%sanitized_name%.png
                    source_image_path  := ""

                    if(arcade_mode && use_libretro_mame_thumb) {
                        source_image_path = %local_art_path%\MAME\%A_LoopField%\%sanitized_name%.png
                        
                    } else if(arcade_mode && use_libretro_fba_thumb) {
                        source_image_path = %local_art_path%\FB Alpha - Arcade Games\%A_LoopField%\%sanitized_name%.png
                        
                    } else if(arcade_mode && use_std_mame_thumb) {
                        ;### 'traditional' MAME thumbnail sets, based on ROM filename
                        std_mame_image_subfolder := ""
                        if(A_LoopField = "Named_Boxarts") {
                            std_mame_image_subfolder := "flyers"
                        } else if (A_LoopField = "Named_Snaps") {
                            std_mame_image_subfolder := "snap"					
                        } else if (A_LoopField = "Named_Titles") {
                            std_mame_image_subfolder := "titles"					
                        }
                        source_image_path = %local_art_path%\%std_mame_image_subfolder%\%ROM_name%.png
                        
                    } else { ;### filename matching mode - use corresponding folder in source
                        source_image_path = %local_art_path%\%playlist_file_no_ext%\%A_LoopField%\%sanitized_name%.png				
                    }
                    FileCopy, %source_image_path%, %local_image_path%, 0     ;### Explicit 'do not overwrite' mode
                }               
                line_index += 6							   
            }

            Progress, Off
        }
        
        if(process_remote_thumbs) {

            download_error     := 0
            Progress, A M T, Processing thumbnails for:`n%playlist_file_no_ext%, "Initalizing Download`n", %app_title%
            
            line_index := 1
            while (line_index < playlist_line_count)
            {
                percent_parsed := Round(100 * (line_index / playlist_line_count))
                Progress, %percent_parsed%			
                
                title := Trim(playlist_contents[line_index+1])
                sanitized_name := SanitizeFilename(title)
                               
                Loop, Parse, thumbnail_category_list, |
                {
                    local_image_path = %playlist_path%\..\thumbnails\%playlist_file_no_ext%\%A_LoopField%\%sanitized_name%.png
                    source_image_path  := ""
                    if(arcade_mode && use_libretro_mame_thumb) {
                        source_image_path = %remote_libretro_mame_repo%/%A_LoopField%/%sanitized_name%.png	
                        
                    } else if(arcade_mode && use_libretro_fba_thumb) {
                        source_image_path = %remote_libretro_fba_repo%/%A_LoopField%/%sanitized_name%.png
                        
                    } else if(arcade_mode && use_std_mame_thumb) {
                        ;### 'traditional' MAME thumbnail sets, based on ROM filename
                        std_mame_image_subfolder := ""
                        if(A_LoopField = "Named_Boxarts") {
                            std_mame_image_subfolder := "flyers"
                        } else if (A_LoopField = "Named_Snaps") {
                            std_mame_image_subfolder := "ingames"					
                        } else if (A_LoopField = "Named_Titles") {
                            std_mame_image_subfolder := "titles"					
                        }
                        source_image_path = %remote_std_mame_repo%/%std_mame_image_subfolder%/%ROM_name%.png
                        
                    } else { ;### filename matching mode - use corresponding folder in source
                        source_image_path = %remote_libretro_parent_repo%/%playlist_file_no_ext%/%A_LoopField%/%sanitized_name%.png			
                    }

                    try { ;### Do not overwrite existing files, do not display individual download progress bar
                        DownloadFile(source_image_path, local_image_path, False, False)
                    }
                    Catch e {
                        download_error += 1
                        Results := ""
                        if(download_error >= 3) { ;### give up after three attempts to download
                            For Each, Line in StrSplit(e.Message, "`n", "`r")
                            {
                                Results := InStr(Line, "Description:") 
                                    ? StrReplace(Line, "Description:")
                                    : ""
                                Results := Trim(Results)
                                If (Results != "") {
                                    Break
                                }
                            }
                            MsgBox ,, Download error, %Results%
                            process_remote_thumbs := False ;### turn off downloading after catching the exception
                            Return
                        }
                    }
                }
            }
            Progress, Off
        }
        
        if(reset_playlist_cores) {
            line_index          := 1
            new_playlist_string := ""
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
            MsgBox, %A_LoopField% play`n %playlist_path%\%A_LoopField%`n%new_playlist_string%
            playlist_file := FileOpen(playlist_filename,"w")
            playlist_file.Write(new_playlist_string)
            playlist_file.Close()
        }
        
        if(audit_thumbnails){
            unmatched_thumb_list .= "`r`n`r`n[" . playlist_file_no_ext . "]`r`n"

            line_index := 0
            while (line_index < playlist_line_count)
            {
                title := Trim(playlist_contents[line_index+1])
                sanitized_name := SanitizeFilename(title)
                
                Loop, Parse, thumbnail_category_list, |
                {
                    local_image_path = %playlist_path%\..\thumbnails\%playlist_file_no_ext%\%A_LoopField%\%sanitized_name%.png
                    if(!FileExist(local_image_path)) {
                        unmatched_thumb_list .= playlist_file_no_ext . "/" . A_LoopField . "=" . sanitized_name . ".png`r`n"
                    }
                }
            }
        }
	}
    
	if(audit_thumbnails) {
		unmatched_thumb_log.Write(unmatched_thumb_list)
	}
    
    MsgBox,, %app_title%, Playlist processing complete. Click OK to return to the Processor menu.
    
    Processor() ;### return to first processor screen after complete
    Return
}

;---------------------------------------------------------------------------------------------------------
SelectAppModeGUI() {

	SetTimer, ChangeButtonNames, 1
	MsgBox, 3, %app_title% - Mode Select, Please choose an operational mode:`n`n"Generator" creates new playlists.`n"Processor" modifies existing playlists and scrapes thumbnails for playlists.

	IfMsgBox, Yes 
	{
		return 0
	}
	IfMsgBox, No
	{
		return 1
	}
	IfMsgBox, Cancel
	{
		ExitApp
	}

	ChangeButtonNames: ;### using the MsgBox like this is hacky. Should be redone with a proper Gui
	IfWinNotExist, %app_title% - Mode Select
		return  ; Keep waiting.
	SetTimer, ChangeButtonNames, off 
	WinActivate 
	ControlSetText, Button1, &Generator
	ControlSetText, Button2, &Processor 
	ControlSetText, Button3, &Exit 
	return
}

;---------------------------------------------------------------------------------------------------------

PrimaryGeneratorGUI()
{
    DetectHiddenWindows, Off
    Gui, primary_generator_window: new
    Gui, Default
    Gui, +LastFound

    ;### Primary options
    Gui, Font, %heading_font_config%,    Verdana
    Gui, Add, Groupbox, w%box_w% h160 Section,                Primary options

    ;### ROM storage location
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Text, xs8 ys24 w%groupbox_contents_w%,          %base_rom_path_label%
    Gui, Font, %body_font_config%,       Verdana
    Gui, Add, Text, xs8 y+0 w%groupbox_contents_w%,           %base_rom_path_description%
    Gui, Add, Edit, xs8 y+2 w%textbox_w% vbase_rom_path,      %base_rom_path%

    ;### playlist path
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Text, xs8 y+8  w%groupbox_contents_w%,          %playlist_path_config_label%
    Gui, Font, %body_font_config%,       Verdana
    Gui, Add, Text, xs8 y+0 w%groupbox_contents_w%,           For use on this PC, enter your configured RetroArch playlist path, such as c:\RetroArch\playlists
    Gui, Add, edit, xs8 y+0 w%textbox_w% vplaylist_path,      %playlist_path%

    Gui, Font, %heading_font_config%,    Verdana
    Gui, Add, Groupbox, xm0 y+24 w%box_w% h160 Section,       Playlist options

    ;### RetroArch core path
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Text, xs8 ys24  w%groupbox_contents_w%,         %RA_core_path_label%
    Gui, Font, %body_font_config%,       Verdana
    Gui, Add, Edit, xs8 y+0 w%textbox_w%  vRA_core_path,      %RA_core_path%
    
    Gui, Add, Checkbox, xs8 y+4 w%groupbox_contents_w% Checked%unix_playlist% vunix_playlist
                                                            , %unix_playlist_config_label%
                                                                       
    Gui, Add, Checkbox, xs8 y+4 w%groupbox_contents_w% Checked%use_alternate_rom_path% vuse_alternate_rom_path
                                                            , %alternate_path_config_label%
                                                                       
    Gui, Add, Edit, xs8 y+0 w%textbox_w% valternate_rom_path, %alternate_rom_path%
        
    ;### Arcade-specific options
    Gui, Font, %heading_font_config%,    Verdana
    Gui, Add, Groupbox, xm0 y+24 w%box_w% h95 Section,       Arcade DAT Scanner
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Checkbox, xs8 ys24 w%groupbox_contents_w% Checked%arcade_mode% varcade_mode
                                                            , Parse the XML DAT specified below for titles rather than using filenames for the title	
    ;### Arcade DAT file location
    Gui, Font, %body_font_config%,       Verdana
    Gui, Add, Edit, xs8 y+0 w%textbox_w% vdat_path,           %dat_path%
    Gui, Add, Link, xs8 y+0,                                  %dat_config_desc%
		
	;### Buttons
    Gui, Font, %subheading_font_config%, Verdana
	Gui, Add, Button, w100 xs%prev_button_x% y+24 gPrimaryGeneratorPrevious, Previous
	Gui, Add, Button, w100 xs%next_button_x% yp   gPrimaryGeneratorNextStep, Next Step

	Gui, Show, w%app_window_w%, %app_title% - Generator
	Return WinExist()

	PrimaryGeneratorNextStep:
	{
		Gui,Submit,Nohide
		Gui primary_generator_window:Destroy
		Return
	}
	primary_generator_windowGuiClose:
	PrimaryGeneratorPrevious:
	{
		Gui primary_generator_window:Destroy
		Main()
        Return
    }
}

SecondaryGeneratorGUI(ByRef proceed) {

	DetectHiddenWindows, Off
	Gui, subfolder_selection_window: new
	Gui, Default
	Gui, +LastFound
	
	Gui, Font, %heading_font_config%,    Verdana
	Gui, Add, Groupbox, w%box_w% Section xm0 ym0 h325,               Select one or more ROM subfolders to process
    Gui, Font, s12 w400, Verdana   
	Gui, Add, ListBox, 8 vselected_rom_subfolder_list xs9 ys25 w%groupbox_contents_w% h300, %full_rom_subfolder_list%
    
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Checkbox, xs8 y+16 w%groupbox_contents_w% Checked%recurse_ROM_subfolders% vrecurse_ROM_subfolders
                                                                   , Recurse through subfolders of the folders selected above
    Gui, Add, Text, xs8 y+8 w%groupbox_contents_w%,                  Inclusion filter: only include files with this extension (ex: *.zip or *.cue)
    Gui, Font, %body_font_config%,       Verdana                                                                
    Gui, Add, Edit, xs8 y+0 w%textbox_w% vROM_inclusion_filter,      %ROM_inclusion_filter%                                                           
    ;### Buttons
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, button, w100 xs%prev_button_x% y+24 gSecondaryGeneratorPrevious, Previous
	Gui, Add, button, w100 xs%next_button_x% yp   gGenerate,                   Generate

	Gui, show, w%app_window_w%, %app_title% - Generator
	return WinExist()

	Generate:
	{
		Gui,Submit,Nohide
		If (selected_rom_subfolder_list = "") {
			Return ;### no subfolders selected to process
		}
		Gui subfolder_selection_window:Destroy
		proceed := True
        Return
	}

	subfolder_selection_windowGuiClose:
 	SecondaryGeneratorPrevious:
	{
        Gui subfolder_selection_window:Destroy
        proceed := False
        Return
	}
}

;---------------------------------------------------------------------------------------------------------

PrimaryProcessorGUI() {

	DetectHiddenWindows, Off
	Gui, primary_processor_window: new
	Gui, Default
	Gui, +LastFound
    
    playlist_path_description  := "For use on this PC, enter your configured RetroArch playlist path, such as c:\RetroArch\playlists."
    thumbnail_path_description := "Any thumbnails that are scraped will be placed in a folder called thumbnails within the same parent folder as the playlist folder."
	
	;### Primary options
	Gui, Font, %heading_font_config%,    Verdana
	Gui, Add, Groupbox, xm0 w%box_w% h120 Section,                   Primary options
    
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, Text, xs8 ys24 w%groupbox_contents_w%,                 %playlist_path_config_label%
    Gui, Font, %body_font_config%,       Verdana
    Gui, Add, Text, xs8 y+0 w%groupbox_contents_w%,                  %playlist_path_description%
    Gui, Add, Edit, xs8 y+0 w%textbox_w% vplaylist_path,             %playlist_path%
    Gui, Add, Text, xs8 y+0 w%groupbox_contents_w%,                  %thumbnail_path_description%

	Gui, Font, %heading_font_config%,    Verdana
	Gui, Add, Groupbox, xm0 y+24 w%box_w% h135 Section,              Thumbnail scraping
    
	Gui, Font, %body_font_config%,       Verdana
	Gui, Add, Link, xs8 ys24 w%groupbox_contents_w%,                 %local_art_path_label%
	Gui, Font, %subheading_font_config%, Verdana
	Gui, Add, Checkbox, xs8 y+8 w%groupbox_contents_w% Checked%process_local_thumbs% vprocess_local_thumbs
                                                                   , %local_art_path_check_text%
    
    Gui, Add, Checkbox, xs8 ys24 w%groupbox_contents_w% Checked%arcade_mode% varcade_mode
                                                                            
    Gui, Font, %body_font_config%,        Verdana
    Gui, Add, Edit, xs8 w%textbox_w% y+0 vlocal_art_path,           %local_art_path%
    Gui, Font, %subheading_font_config%,  Verdana
    Gui, Add, Checkbox, xs8 y+8 w%groupbox_contents_w% Checked%process_remote_thumbs% vprocess_remote_thumbs
                                                                   , %attempt_thumbnail_download_label%				
	Gui, Font, %heading_font_config%,    Verdana
	Gui, Add, Groupbox, xm0 w%box_w% y+24 h50 Section,              Audit Thumbnails	
    Gui, Font, %body_font_config%,        Verdana    
	Gui, Add, Checkbox, xs8 ys24 w%groupbox_contents_w% vaudit_thumbnails Checked%audit_thumbnails%
                                                                   , Create %unmatched_thumb_log_filename%
 	Gui, Font, %heading_font_config%,    Verdana
	Gui, Add, Groupbox, xm0 y+24 w%box_w% h50 Section,              Playlist modification 
    Gui, Font, %body_font_config%,        Verdana    
    Gui, Add, Checkbox, xs8 ys24 w%groupbox_contents_w% Checked%reset_playlist_cores% vreset_playlist_cores
                                                                   , Reset libretro core name and path to "DETECT"
                                                                   
    ;### Buttons
	Gui, Font, %subheading_font_config%,  Verdana
    
	Gui, Add, button, w100 xs%prev_button_x% y+24 gPrimaryProcessorPrevious,   Previous
	Gui, Add, button, w100 xs%next_button_x% yp   gPrimaryProcessorNextStep,   Next Step

	Gui, Show, w%app_window_w%, %app_title%
	Return WinExist()

	PrimaryProcessorNextStep:
	{
		Gui, Submit, Nohide
 		Gui primary_processor_window:destroy
		Return
	}
	primary_processor_windowGuiClose:
	PrimaryProcessorPrevious:
	{
		Gui primary_processor_window:destroy
        Main()
		Return
	}
}

SecondaryProcessorGUI(ByRef proceed) {

	DetectHiddenWindows, Off
	Gui, playlist_selection_window: new
	Gui, Default
	Gui, +LastFound
	logging_options_y_pos := "y+20" ;### default position for the playlist log options
	
	Gui, Font, s12 w700, Verdana
	Gui, Add, Groupbox, w%box_w% Section xm0 ym0 h325,                        Select one or more playlists to process
    Gui, Font, s12 w400, Verdana
	Gui, Add, ListBox, 8 vselected_playlist_list xs9 ys25 w%groupbox_contents_w% h300, %full_playlist_list%

	if(process_local_thumbs or process_remote_thumbs) {
		logging_options_y_pos := "ys200" ;### the thumbnail log GUI will be positioned with respect to the thumb scraping options 
		
		if(!arcade_mode) { ;### filename matching mode

			Gui, Font, s12 w700, Verdana
			Gui, Add, Groupbox, xm0 ys350 w%box_w% h150 Section, Filename Matching Mode
		    Gui, Font, %subheading_font_config%, Verdana
			Gui, Add, Text, xs8 ys24 w%groupbox_contents_w%, Search Path
			Gui, Font, %body_font_config%,        Verdana

			if(process_local_thumbs) {
				Gui, Add, Link, xs8 y+8 w%groupbox_contents_w% Border, Thumbnails will be matched locally within sufolders of %local_art_path% with the same name as the ROM subfolder(s) selected below.
			}
			if(process_remote_thumbs) {
				Gui, Add, Link, xs8 y+8 w%groupbox_contents_w% Border, Thumbnails will be matched on the libretro server to images in subfolders at <a href=`"%remote_libretro_parent_repo%`">%remote_libretro_parent_repo%</a> with the same name as the ROM subfolder(s) selected below.
			}
            
		} else if(arcade_mode) {

			libretro_mame_radio_label := "Libretro MAME thumbnail repository"
			libretro_fba_radio_label  := "Libretro FB Alpha thumbnail repository"
			std_mame_radio_label      := "Standard MAME image repository (flyers, snap, titles)"
			libretro_mame_radio_desc  := ""
			libretro_fba_radio_desc   := ""
			std_mame_radio_desc       := ""
			
			if(process_local_thumbs) {
				libretro_mame_radio_desc .= "Local: " . local_art_path . "\MAME "
				libretro_fba_radio_desc  .= "Local: " . local_art_path . "\FB Alpha - Arcade Games "
				std_mame_radio_desc      .= "Local: " . local_art_path . " "			
			}
			if(process_local_thumbs and process_remote_thumbs) {
				libretro_mame_radio_desc .= "`n"
				libretro_fba_radio_desc  .= "`n"
				std_mame_radio_desc      .= "`n"
			}			
			if(process_remote_thumbs) {
				libretro_mame_radio_desc .= "Remote: " . remote_libretro_mame_repo
				libretro_fba_radio_desc  .= "Remote: " . remote_libretro_fba_repo
				std_mame_radio_desc      .= "Remote (arcadeitalia.net): " . remote_std_mame_repo			
			}

			Gui, Add, Groupbox, xm0 y+10 w%box_w% h190  Section, Arcade Mode - Select thumbnail search path:
			Gui, Font, s10 w700, Verdana
			Gui, Add, Text, xs8 ys25 w%groupbox_contents_w%, %libretro_mame_radio_label%
			Gui, Add, Text, xs8 ys80 w%groupbox_contents_w%, %libretro_fba_radio_label%
			Gui, Add, Text, xs8 ys135 w%groupbox_contents_w%, %std_mame_radio_label%

			Gui, Font, s9 w400, Verdana
			;### radio buttons have to be grouped together in the code, for AHK reasons
			Gui, Add, Radio, xs8 ys40 w%groupbox_contents_w% vuse_libretro_mame_thumb Checked, %libretro_mame_radio_desc%
			Gui, Add, Radio, xs8 ys95 w%groupbox_contents_w% vuse_libretro_fba_thumb, %libretro_fba_radio_desc%
			Gui, Add, Radio, xs8 ys150 w%groupbox_contents_w% vuse_std_mame_thumb, %std_mame_radio_desc%						
		}		
	}

	;### Buttons
    Gui, Font, %subheading_font_config%, Verdana
    Gui, Add, button, w100 xs%prev_button_x% y+24 gSecondaryProcessorPrevious, Previous
	Gui, Add, button, w100 xs%next_button_x% yp   gProcess,                    Process

	Gui, show, w%app_window_w%, %app_title% - Processor
	return WinExist()

	Process:
	{
		Gui,Submit,Nohide
		If (selected_playlist_list = "") {
			Return ;### no subfolders selected to process
		}
		Gui playlist_selection_window:Destroy
		proceed := True ;### return true to go forward
        Return
	}

	playlist_selection_windowGuiClose:
 	SecondaryProcessorPrevious:
	{
        Gui playlist_selection_window:Destroy
        proceed := False ;### return false to go back
        Return
	}
}

;---------------------------------------------------------------------------------------------------------

MatchDATFilterCriteria(dat_entry) {

	if(dat_entry.is_BIOS) {
		Return True
	}
	if(dat_entry.is_device) {
		Return True
	}
	if(dat_entry.is_mechanical) {
		Return True
	}
	if(!dat_entry.runnable) {
		Return True
	}
	return False
}