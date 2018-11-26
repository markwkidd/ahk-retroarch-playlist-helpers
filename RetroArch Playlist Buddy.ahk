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

;### INITIALIZE GLOBAL VARIABLES
;### Leave blank to prompt for all values in GUI
;### Enter values in the script to serve as defaults in GUI

global base_rom_path                    := ""
global base_rom_path_label              := "Base ROM Path"
global base_rom_path_description        := "During the next step you can select subfolders to scan within this path. Ex: C:\roms"

;### If ROMs are in folders called C:\roms\Fighting and C:\roms\Driving, then the base ROM directory is c:\roms
global RA_core_path                     := "DETECT"
global RA_core_path_label               := "Playlist path to a RetroArch core (ends in .dll or .so)"

global output_path                      := ""
global output_path_config_label         := "Local destination path for playlists and thumbnails"
global output_path_config_description   := "For use on this PC, enter the local RetroArch path, such as c:\RetroArch"

global arcade_mode                      := True
global arcade_mode_label                := "Arcade Mode"
global arcade_mode_desc                 := "Search XML DAT specified below for titles rather than ROM filenames"
global dat_path                         := "" ;### path to an arcade XML DAT file
global dat_array            := "" ;### will store essential information from the DAT

global unix_playlist                    := False ;### Default to False
global unix_playlist_config_label       := "Use forward slashes in playlist paths for Android, Lakka, Linux, OS X"
global alternate_path_config_label      := "Use a different base ROM path in playlist than the local ROM path that is scanned. Helpful for Android, Lakka, Linux, OS X"
global use_alternate_rom_path           := False ;### Default to False
global alternate_rom_path               := "/storage/roms"
;### alternate_rom_path: Location of the base ROM folder for the RetroArch installation
;### where the playlist(s) will be used as opposed to the ROM path used to scan for ROMs

global local_art_path_label             := "You may find it helpful to <a href=""http://thumbnailpacks.libretro.com/"">download libretro thumbnail packs</a>."
global local_art_path_check_text        := "Use local thumbnail source images at the following base path:"
global local_art_path                   := "" ;### Can be left blank if not using a local thumbnail source.

global full_rom_subfolder_list          := "" ;### initalize as blank
global selected_rom_subfolder_list    := ""
global rom_subfolder_list_label         := "Select one or more ROM subfolders to process"

global thumb_processing_only            := False  ;### Enable to avoid creating or overwriting playlists
global thumb_processing_only_label      := "Do not generate playlists. Only process thumbnails."
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

Main()
ExitApp

Main() {

  GatherConfigData:
  PrimarySettingsGUI()                    ;### Prompt the user to enter the configuration 
  WinWaitClose

  if(unix_playlist) {
    playlist_path_delimiter = /
  }
  
  Trim(output_path)
  StripFinalSlash(output_path)           ;## Remove any trailing forward or back slashes from user-provided paths
  Trim(base_rom_path)
  StripFinalSlash(base_rom_path)
  Trim(local_art_path)
  StripFinalSlash(local_art_path)
  Trim(alternate_rom_path)
  StripFinalSlash(alternate_rom_path)  
  Trim(RA_core_path)

  if !FileExist(base_rom_path) {
    MsgBox,,Path Error!, Base ROM directory does not exist:`n%base_rom_path%
    Goto, GatherConfigData
  } else if ((arcade_mode) and (!FileExist(dat_path))) {
    MsgBox,,Path Error!, Arcade mode enabled, but DAT file not found:`n%dat_path%
    Goto, GatherConfigData
  } else if !FileExist(output_path) {
    MsgBox,,Path Error!, Thumbnail and playlist output directory does not exist:`n%output_path%
    Goto, GatherConfigData
  } else if (process_local_thumbs and (local_art_path = "" or !FileExist(local_art_path))) {
    MsgBox,,Path Error!, Local art directory was specified but does not exist:`n%local_art_path%
    Goto, GatherConfigData
  }

  full_rom_subfolder_list := ""          ;### reinitialize in case base directory has changed
  Loop, Files, %base_rom_path%\*.*, D     ;### Loop through base ROM folder, looking only for subfolders
  {
    full_rom_subfolder_list .= (A_LoopFileName . "|")
  }
  StringTrimRight, full_rom_subfolder_list, full_rom_subfolder_list, 1  ;### remove extra | pipe character at end. not elegant.

  ROMSubfolderSelectGUI()
  WinWaitClose
  
  if(!trigger_generation) {  ;### For example if the "Return" button or window close chrome has been used
    Goto, GatherConfigData
  }

  if(!thumb_processing_only) {
    FileCreateDir, %output_path%\playlists  ;### create playlists subfolder if it doesn't exist
  }
  if(process_local_thumbs || process_remote_thumbs) {
    FileCreateDir, %output_path%\thumbnails     ;### create main thumbnails folder if it doesn't exist
  }
  
  unmatched_thumb_log := ""
  if(audit_thumbnails) {
    FileDelete, %unmatched_thumb_log_filename%   ;### clear existing umatched thumbnaillog 
    unmatched_thumb_log := FileOpen(unmatched_thumb_log_filename,"a") ;### Creates new playlist in 'append' mode
  }
  
  DAT_array := ""
  if(arcade_mode) {
    BuildArcadeDATArray(dat_path, DAT_array, True)
  }
    
  Loop, Parse, selected_rom_subfolder_list, |
  {  
    ROM_file_array := Object() ;### Reinitialize file list for each subfolder loop
    playlist_name := A_LoopField
    
    Loop, Files, %base_rom_path%\%playlist_name%\*.*
    {
      SplitPath, A_LoopFileLongPath,,,,ROM_filename_no_ext
      ROM_details := DAT_array[ROM_filename_no_ext]
          
      if(arcade_mode && (MatchDATFilterCriteria(rom_details))) {
        continue ;### continue to next ROM
      } else if((ROM_details == "") || (ROM_details.title == "")) {
          ;### use filename in file name mode and also for arcade ROMs with no DAT title
        ROM_details := {Title:ROM_filename_no_ext} 
      }
      
      ROM_details.path                     := A_LoopFileLongPath
      ROM_file_array[ROM_filename_no_ext]  := ROM_details
    }
    
    if(!thumb_processing_only) {
      playlist_filename := output_path . "\playlists\" . playlist_name . ".lpl"  
      PlaylistGenerator(ROM_file_array, playlist_filename, playlist_name, (use_alternate_rom_path ? alternate_ROM_path : base_rom_path), playlist_path_delimiter, True)
    }
    
    if(process_local_thumbs || process_remote_thumbs) {  ;### create thumbnail subfolder
      Loop, Parse, thumbnail_category_list, |
      {
        thumbnail_category_name := A_LoopField
        FileCreateDir, %output_path%\thumbnails\%playlist_name%\%thumbnail_category_name%
      }
    }  
    
    unmatched_thumb_list := "`r`n`r`n[" . playlist_name . "]`r`n"
    ThumbnailProcessor(ROM_file_array, playlist_name, (audit_thumbnails ? unmatched_thumb_list : False))
    
    if(audit_thumbnails) {
      unmatched_thumb_log.Write(unmatched_thumb_list)
    }
  }

  if(audit_thumbnails) {
    unmatched_thumb_log.Close()  ;### close and flush the umatched thumbnail log
  }

  MsgBox,,%app_title%,Processing complete. Click OK to return to main menu.
  Goto, GatherConfigData
}

;---------------------------------------------------------------------------------------------------------

ThumbnailProcessor(ByRef ROM_file_array, playlist_name, ByRef unmatched_thumb_list:=False) {

  number_of_files      := NumGet(&ROM_file_array + 4*A_PtrSize)   ;### associative array size. voodoo from the AHK forums  
  current_ROM_count    := 0

  if(process_local_thumbs) {
    Progress, A M T, Processing thumbnails for:`n%playlist_name%, Local thumbnail repository`n, %app_title%
    current_ROM_count    := 0
    For ROM_name, ROM_details in ROM_file_array
    {
      current_ROM_count += 1
      percent_parsed := Round(100 * (current_ROM_count / number_of_files))
      Progress, %percent_parsed%        
      
      current_ROM_title := ROM_details.title
      sanitized_name := SanitizeFilename(current_ROM_title)
      
      Loop, Parse, thumbnail_category_list, |
      {
        local_image_path = %output_path%\thumbnails\%playlist_name%\%A_LoopField%\%sanitized_name%.png
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
          source_image_path = %local_art_path%\%playlist_name%\%A_LoopField%\%sanitized_name%.png        
        }
        FileCopy, %source_image_path%, %local_image_path%, 0     ;### Explicit 'do not overwrite' mode
      }
    }
    Progress, Off
  }
  
  if(process_remote_thumbs) {
    current_ROM_count  := 0
    download_error     := 0
    Progress, A M T, Processing thumbnails for:`n%playlist_name%, "Initalizing Download`n", %app_title%
    
    For ROM_name, ROM_details in ROM_file_array
    {
      current_ROM_count += 1
      current_ROM_title := ROM_details.title
      sanitized_name := SanitizeFilename(current_ROM_title)
      
      percent_parsed := Round(100 * (current_ROM_count / number_of_files))
      Progress, %percent_parsed%, Processing thumbnails for:`n%playlist_name%,Downloading images for:`n%current_ROM_title%,%app_title%
      
      Loop, Parse, thumbnail_category_list, |
      {
        local_image_path = %output_path%\thumbnails\%playlist_name%\%A_LoopField%\%sanitized_name%.png
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
          source_image_path = %remote_libretro_parent_repo%/%playlist_name%/%A_LoopField%/%sanitized_name%.png      
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
  
  if(unmatched_thumb_list != False){
    current_ROM_count    := 0
    For ROM_name, ROM_details in ROM_file_array
    {
      current_ROM_count += 1      
      current_ROM_title := ROM_details.title
      sanitized_name := SanitizeFilename(current_ROM_title)
      
      Loop, Parse, thumbnail_category_list, |
      {
        local_image_path = %output_path%\thumbnails\%playlist_name%\%A_LoopField%\%sanitized_name%.png
        if(!FileExist(local_image_path)) {
          unmatched_thumb_list .= playlist_name . "/" . A_LoopField . "=" . sanitized_name . ".png`r`n"
        }
      }
    }
  }

}

;---------------------------------------------------------------------------------------------------------

MatchDATFilterCriteria(dat_entry) {
  if(dat_entry.isbios) {
    Return True
  }
  if(dat_entry.isdevice) {
    Return True
  }
  if(dat_entry.ismechanical){
    Return True
  }
  if(!dat_entry.runnable){
    Return True
  }
  return False
}


;---------------------------------------------------------------------------------------------------------

PrimarySettingsGUI()
{
  DetectHiddenWindows, Off

  Gui, path_entry_window: new
  Gui, Default
  Gui, +LastFound
  
  ;### Primary options
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w640 h200 Section,Primary options

    ;### ROM storage location
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 ys22 w630, %base_rom_path_label%
    Gui, Font, s10 w400, Verdana
    Gui, Add, Text, xs8 y+0 w630, %base_rom_path_description%
    Gui, Add, edit, w400 xs8 y+2 vbase_rom_path, %base_rom_path%
    
    ;### RetroArch core path
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+6  w630, %RA_core_path_label%
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, edit, w400 xs8 y+0  vRA_core_path, %RA_core_path%

    ;### thumbnail and playlist output path
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+6  w630, %output_path_config_label%
    Gui, Font, s10 w400, Verdana
    Gui, Add, Text, xs8 y+0 w630, %output_path_config_description%
    Gui, Add, edit, w400 xs8 y+0 voutput_path, %output_path%

    
  ;### Arcade-specific options
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 y+14 w640 h75 Section, %arcade_mode_label%
    Gui, Font, s10 w700, Verdana  
    Gui, Add, Checkbox, xs8 ys24 w630 Checked%arcade_mode% varcade_mode, %arcade_mode_desc%
    
    ;### Arcade DAT file location
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, edit, w400 xs8 y+0 vdat_path, %dat_path%
    
  ;### Playlist settings
  Gui, Font, s12 w700, M
  Gui, Add, Groupbox, xm0 y+14 w640 h135 Section, Playlist settings
    
    Gui, Font, s10 w700, Verdana
    Gui, Add, Checkbox, xs8 ys+28 w630 Checked%thumb_processing_only% vthumb_processing_only, %thumb_processing_only_label%
    Gui, Font, s10 w400, Verdana
    Gui, Add, Checkbox, xs8 y+4 w630 Checked%unix_playlist% vunix_playlist, %unix_playlist_config_label%
    Gui, Add, Checkbox, xs8 y+4 w630 Checked%use_alternate_rom_path% vuse_alternate_rom_path, %alternate_path_config_label%
    Gui, Add, edit, w400 xs8 y+0 valternate_rom_path, %alternate_rom_path%

  ;### Thumbnail settings
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 y+14 w640 h115 Section, Thumbnail settings (optional)
    Gui, Font, s10 w400, Verdana
    Gui, Add, Link, xs8 ys24 w630, %local_art_path_label%
    Gui, Font, s10 w700, Verdana
    Gui, Add, Checkbox, xs8 y+6 w630 Checked%process_local_thumbs% vprocess_local_thumbs, %local_art_path_check_text%
    Gui, Font, s10 w400, Verdana    
    Gui, Add, Edit, w400 xs8 y+0 vlocal_art_path, %local_art_path%
    Gui, Font, s10 w700, Verdana    
    Gui, Add, Checkbox, xs8 y+4 w630 Checked%process_remote_thumbs% vprocess_remote_thumbs, %attempt_thumbnail_download_label%
    
  ;### Buttons
  Gui, Font, s10 w700, Verdana
  Gui, Add, button, w100 xp+350 y+18 gDone, Next Step
  Gui, Add, button, w100 xp+120 yp gExit, Exit

;### Donation link
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 y+14 w640 h68 Section, Donation link
    Gui, Font, s10 w400, Verdana
    Gui, Add, Link, xs8 ys24 w630, Donations are accepted via <a href="http://paypal.me/handbarrow">Handbarrow's PayPal.me account</a>. Please consider giving $5 to support the development of this tool. Thank you!
    
  Gui, show, w670, %app_title%
  return WinExist()

  Done:
  {
    Gui,submit,nohide
    Gui,destroy
    return
  }

  path_entry_windowGuiClose:
  Exit:
  {
    Gui path_entry_window:destroy
    ExitApp
  }
}

ROMSubfolderSelectGUI() {

  DetectHiddenWindows, Off
  Gui, subfolder_selection_window: new
  Gui, Default
  Gui, +LastFound
  logging_options_y_pos := "y+20" ;### default position for the playlist log options
  
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w580 Section xm0 ym0 h325,%rom_subfolder_list_label%
  Gui, Add, ListBox, 8 vselected_rom_subfolder_list xs9 ys25 w550 h300, %full_rom_subfolder_list%

  if(process_local_thumbs or process_remote_thumbs) {
    logging_options_y_pos := "ys200" ;### the thumbnail log GUI will be positioned with respect to the thumb scraping options 
    
    if(!arcade_mode) { ;### filename matching mode

      Gui, Font, s12 w700, Verdana
      Gui, Add, Groupbox, xm0 ys350 w580 h150 Section, Filename Matching Mode
      Gui, Font, s10 w700, Verdana
      Gui, Add, Text, xs8 ys24 w550, Search Path
      Gui, Font, s10 w400, Verdana

      if(process_local_thumbs) {
        Gui, Add, Link, xs8 y+8 w550 Border, Thumbnails will be matched locally within sufolders of %local_art_path% with the same name as the ROM subfolder(s) selected below.
      }
      if(process_remote_thumbs) {
        Gui, Add, Link, xs8 y+8 w550 Border, Thumbnails will be matched on the libretro server to images in subfolders at <a href=`"%remote_libretro_parent_repo%`">%remote_libretro_parent_repo%</a> with the same name as the ROM subfolder(s) selected below.
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

      Gui, Add, Groupbox, xm0 y+10 w580 h190  Section, Arcade Mode - Select thumbnail search path:
      Gui, Font, s10 w700, Verdana
      Gui, Add, Text, xs8 ys25 w550, %libretro_mame_radio_label%
      Gui, Add, Text, xs8 ys80 w550, %libretro_fba_radio_label%
      Gui, Add, Text, xs8 ys135 w550, %std_mame_radio_label%

      Gui, Font, s9 w400, Verdana
      ;### radio buttons have to be grouped together in the code, for AHK reasons
      Gui, Add, Radio, xs8 ys40 w560 vuse_libretro_mame_thumb Checked, %libretro_mame_radio_desc%
      Gui, Add, Radio, xs8 ys95 w560 vuse_libretro_fba_thumb, %libretro_fba_radio_desc%
      Gui, Add, Radio, xs8 ys150 w560 vuse_std_mame_thumb, %std_mame_radio_desc%            
    }    
  }

  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 w580 %logging_options_y_pos% h50 Section, Audit Thumbnails  
  Gui, Font, s10 w400, Verdana
  Gui, Add, Checkbox, xs8 ys24 vaudit_thumbnails Checked%audit_thumbnails%, Create unmatched thumbnails log: %unmatched_thumb_log_filename%

  ;### Buttons
  Gui, Font, s10 w700, Verdana
  Gui, Add, button, w100 xp+240 y+24 gGenerate, Generate
  Gui, Add, button, w100 xp+120 yp gExit_Subfolder_Select, Return

  Gui, show, w610, %app_title%
  return WinExist()

  Generate:
  {
    Gui,submit,nohide
    If (selected_rom_subfolder_list = "") {
      Return ;### no subfolders selected to process
    }
    trigger_generation := True
    Gui subfolder_selection_window:destroy
    Return
  }

  subfolder_selection_windowGuiClose:
  Exit_Subfolder_Select:
  {
    trigger_generation := False
    Gui subfolder_selection_window:destroy
    Return
  }
}
