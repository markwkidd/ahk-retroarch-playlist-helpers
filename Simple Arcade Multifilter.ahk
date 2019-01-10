;### AUTOHOTKEY SCRIPT TO SORT MAME ROMS BY GENRE
;### By markwkidd and based on work by libretro forum users roldmort, Tetsuya79, and Alexandra
;### Icon by Alexander Moore @ http://www.famfamfam.com/

;---------------------------------------------------------------------------------------------------------
#NoEnv                         ;### Recommended by AutoHotKey for performance and compatibility.
#Warn                          ;### Enable warnings to assist with detecting common errors.
SendMode Input                 ;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%    ;### Ensure a consistent starting directory.
SetBatchLines -1               ;### Don't yield CPU to other processes (remove if there are CPU issues).
;---------------------------------------------------------------------------------------------------------

#include retroarch-playlist-helper-lib.ahk

global app_title                         := "Simple Arcade Multifilter"

;### INITIALIZE GLOBAL VARIABLES
;### Leave blank to prompt for all values in GUI
;### Enter values in the script to serve as defaults in GUI

global rom_path                         := ""
global rom_path_label                   := "Local Arcade ROMset path"

global MAME_version_reminder            := "The XML DAT and catver.ini should have a version number that matches the ROMset version."

global output_path                      := ""
global output_path_config_label         := "Local destination path for copied ROM sets"
global output_path_config_desc          := "Will not output to the 'root folder' of a drive (e.g. c:\)"

global dat_path                         := "" ;### path to an arcade XML DAT file

global catver_path_label                := "Local path to catver.ini"
global catver_path                      := ""

global category_list                    := "" ;### eventually populated with catver data

global include_filter                   := ""
global include_list_label               := "Select one or more catver.ini categories to include"
global manual_include_filter_label      := "Enter a manual inclusion filter (overrides selection box)"
global manual_include_filter_desc       := "Categories should be separated by a pipe character, for example:`nShooter|Flying Horizontal|Maze"
global manual_include_filter            := ""

global exclude_filter                   := ""
global exclude_list_label               := "Select one or more categories to exclude (optional)"
global manual_exclude_filter_label      := "Enter a manual exclusion filter (overrides selection box)"
global manual_exclude_filter_desc       := "Categories should be separated by a pipe character, for example:`nShooter|Flying Horizontal|Maze"
global manual_exclude_filter            := ""

global bundle_bios_files                := True   ;### always include BIOS files **as designated in the DAT**
global bundle_device_files              := True
global bundle_mature_files              := False
global exclude_bios_files               := False
global exclude_device_files             := False
global exclude_mechanical_files         := False
global exclude_mature_titles            := False
global exclude_CHD_titles               := False
global exclude_non_running_titles       := False

global eol_character                    := "`n"   ;### RetroArch default is UNIX end of line although Windows style works
global path_delimiter                   := "\"    ;### Default to Windows paths
global trigger_generation               := False
;---------------------------------------------------------------------------------------------------------

Main()
ExitApp

Main() {
  GatherConfigData:
  PrimarySettingsGUI()        ;### Prompt the user to enter the configuration
  WinWaitClose

  StripFinalSlash(rom_path)   ;## Remove any trailing forward or back slashes from user-provided paths

  ;### Exit if these files/folders don't exist or are set incorrectly
  if !FileExist(rom_path)
  {
    MsgBox,,Path Error!, ROM directory does not exist:`n%rom_path%
    Goto, GatherConfigData
  }
  else if (!FileExist(catver_path))
  {
    MsgBox,,Path Error!,catver.ini file not found:`n%catver_path%
    Goto, GatherConfigData
  }
  else if (!FileExist(dat_path))
  {
    MsgBox,,Path Error!, DAT file not found:`n%dat_path%
    Goto, GatherConfigData
  }

  ROMFileList    := "" ;### (re)initialize - user may have returned to this point in the process
  category_list  := "" ;### (re)initialize
  number_of_roms := 0  ;### (re)initialize

  Loop, Files, %rom_path%\*.*, DF
  { ;### just count the files and folders for progress bar use
    number_of_roms := A_index
  }

  DAT_array := ""
  BuildArcadeDATArray(dat_path, DAT_array, true)

  Progress, A M T, Parsing catver.ini and ROM folder., , %app_title%
  Progress, 0

  ;### store list of ROMs with full path, dat modifiers, and categories in a new array


  parsed_ROM_array := Object()

  Loop, Files, %rom_path%\*.*, F ;### only loop through files
  {
    SplitPath, A_LoopFileName,,,,ROM_filename_no_ext
    romset_entry := DAT_array[ROM_filename_no_ext].clone()
    parsed_ROM_array[ROM_filename_no_ext] := romset_entry
  }
  Loop, Files, %rom_path%\*.*, D ;### only loop through subdirectories, looking for CHD only sets
  {
    SplitPath, A_LoopFileName,,,,ROM_filename_no_ext
    if(!parsed_ROM_array.HasKey(ROM_filename_no_ext)) ;### we have not already found it by looking in the main folder
    {
      romset_entry := DAT_array[ROM_filename_no_ext].clone()
      romset_entry.CHD_only := True
      parsed_ROM_array[ROM_filename_no_ext] := romset_entry
    }
  }
  
  For ROM_filename_no_ext, romset_entry in parsed_ROM_array
  {
    romset_entry.path             :=(ROM_path . "\" . A_LoopFileName)

    IniRead, ROM_entry_categories, %catver_path%, Category, %ROM_filename_no_ext%, **Uncategorized**    
    romset_entry.is_mature        := False
    romset_entry.primary_category := ""
    romset_entry.full_category    := ROM_entry_categories

    flag_index := InStr(ROM_entry_categories, " / ")
    if(flag_index)
    {
      romset_entry.primary_category := Trim(SubStr(ROM_entry_categories, 1, flag_index))
    }
    else
    {
      romset_entry.primary_category := Trim(ROM_entry_categories)
    }

    ;### Mature tag looks like this in older catver.ini: *Mature*
    ;### looks like this in newer catver.ini: * Mature *
    if(InStr(ROM_entry_categories, " *Mature*") || InStr(ROM_entry_categories, " * Mature *"))
    {
      romset_entry.is_mature    := True
      flag_index := InStr(ROM_entry_categories, "*") - 2
      ROM_entry_categories := Trim(SubStr(ROM_entry_categories, 1, flag_index))
    }

    ;### Build an ongoing list of all the categories represented in the catver.ini file
    IfNotInString, category_list, % romset_entry.primary_category . "|"
    {
      category_list .= romset_entry.primary_category . "|"
    }
    IfNotInString, category_list, % romset_entry.full_category . "|"
    {
      category_list .= romset_entry.full_category . "|"
    }

    percent_parsed := Round(100 * (A_index / number_of_roms))
    Progress, %percent_parsed%
  }

  Progress, Off

  ShowFilterSelectGUI:
  output_path    := "" ;### (re)initialize
  include_filter := ""
  exclude_filter := ""

  FilterSelectGUI()
  WinWaitClose

  if(!trigger_generation) {  ;### For example if the "Return" button or window close chrome has been used
    Goto, GatherConfigData
  }

  if (output_path == "") {
    MsgBox,,Path Error!, Output path is blank
    Goto, ShowFilterSelectGUI
  }
  StripFinalSlash(output_path)    ;## Remove any trailing forward or back slashes from user-provided paths
  FileCreateDir, %output_path%    ;### create output folder if it doesn't exist

  include_filter := "|" . include_filter . "|" ;### pipe characters @ beginning and end to help match pattern

  if (exclude_filter == "")
  {
    ;### It's OK if there's no exclusion filter
  } else
  {
    exclude_filter := "|" . exclude_filter . "|"
  }

  current_ROM_index := 0
  Progress, A M T, Filtering and copying ROMs and CHDs., Initializing, %app_title%

  For romset_index, romset_details in parsed_ROM_array
  {
    current_ROM_index          += 1
    current_romset_name        := romset_details.romset_name
    current_ROM_path           := romset_details.path
    ROM_matches_inclusion_list := False
    ROM_filename_with_ext      := ""
    SplitPath, current_ROM_path, ROM_filename_with_ext,,,

    if(exclude_bios_files && romset_details.is_BIOS)
    {
      continue
    }
    if(exclude_device_files && romset_details.is_device)
    {
      continue
    }
    if(exclude_mechanical_files && romset_details.is_mechanical)
    {
      continue
    }
    if(exclude_mature_titles && romset_details.is_mature)
    {
      continue
    }
    if(exclude_CHD_titles && romset_details.needs_CHD)
    {
      continue
    }
    if(exclude_non_running_titles && !romset_details.runnable)
    {
      continue
    }

    if(bundle_bios_files && romset_details.is_BIOS)
    {
       ROM_matches_inclusion_list := True
    }
    else if(bundle_device_files && romset_details.is_device)
    {
       ROM_matches_inclusion_list := True
    }
    else if(bundle_mature_files && romset_details.is_mature)
    {
      ROM_matches_inclusion_list := True
    }
    else {

      check_category_query := "|" . romset_details.primary_category . "|"
      If(InStr(include_filter, check_category_query))
      {
        ROM_matches_inclusion_list := True
      } 
      else if(InStr(exclude_filter, check_category_query))
      {
        continue
      }

      check_category_query := "|" . romset_details.full_category . "|"
      If(InStr(include_filter, check_category_query))
      {
        ROM_matches_inclusion_list := True
      }
      else if(InStr(exclude_filter, check_category_query))
      {
        continue
      }
    }

    if(!ROM_matches_inclusion_list)
    {
      continue
    }
    percent_parsed := Round(100 * (current_ROM_index / number_of_roms))
    Progress, %percent_parsed%, Filtering and copying ROMs and CHDs., %current_romset_name%, %app_title%

    ;MsgBox current_rom path:%current_ROM_path%`n`noutput: %output_path%

    if(!romset_details.CHD_only)
    {
      FileCopy, %current_ROM_path%, %output_path%, 0 ;### do not overwrite existing files
    }

    if(romset_details.needs_CHD)
    {
      ;### check for CHD folders
      CHD_source_path      := ROM_path . "\" . current_romset_name
      CHD_destination_path := output_path . "\" . current_romset_name

      if(FileExist(CHD_source_path))
      {
        If(!FileExist(CHD_destination_path))
        {
          FileCreateDir, %CHD_destination_path%
        }
        FileCopy, %CHD_source_path%\*.*, %CHD_destination_path%\*.*, False
      }
    }

  }
  Progress, Off
  MsgBox,,%app_title%,Copy complete. Click OK to return to menu.
  Goto, ShowFilterSelectGUI

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
  Gui, Add, Groupbox, xm0 ym0 w545 h230 Section, Configure sources

    ;### ROM storage location
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 ys22 w535, %rom_path_label%
    Gui, Font, s10 w400, Verdana
    Gui, Add, Edit, xs8 y+2 w360 h24 vrom_path, %rom_path%
        Gui, Add, Button, x+10 yp-1 w150 h26 gBrowseROMs, Browse for folder...

        Gui, Font, s10 w700, Verdana
        Gui, Add, Text, xs8 y+20 w535, %MAME_version_reminder%


    ;### Arcade DAT file location
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+10 w535, Local path to MAME XML DAT file
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, Edit, xs8 y+0 w360 h24 vdat_path, %dat_path%
        Gui, Add, Button, x+10 yp-1 w150 h26 gBrowseDAT, Browse for file...


    ;### catver.ini file location
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+10 w535, %catver_path_label%
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, Edit, xs8 y+0 w360 h24 vcatver_path, %catver_path%
        Gui, Add, Button, x+10 yp-1 w150 h26 gBrowseCatver, Browse for file...


  ;### Buttons
  Gui, Font, s10 w700, Verdana
  Gui, Add, Button, w100 xm+240 y+24 gDone, Next Step
  Gui, Add, Button, w100 x+20 yp gExit, Exit


    ;### Donation link
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 y+10 w545 h68 Section, Donation link
    Gui, Font, s10 w400, Verdana
    Gui, Add, Link, xs8 ys24 w535, Donations are accepted via <a href="http://paypal.me/handbarrow">Handbarrow's PayPal.me account</a>. Please consider giving $5 to support the development of this tool. Thank you!


  Gui, Show, w570, %app_title%
  Return WinExist()


    BrowseROMs:
    {
        FileSelectFolder, rom_path, , 3
        if (rom_path == "")
        {
            Return      ;### User selected 'cancel'
        }
        GuiControl,, rom_path, %rom_path%
        Return
    }
    BrowseDAT:
    {
        FileSelectFile, dat_path, 3, , Select an arcade XML DAT file, DAT Files (*.dat; *.xml)
        if (dat_path == "")
        {
            Return      ;### User selected 'cancel'
        }
        GuiControl,, dat_path, %dat_path%
        Return
    }
    BrowseCatver:
    {
        FileSelectFile, catver_path, 3, , Select an arcade catver.ini file, INI Files (*.ini)
        if (catver_path == "")
        {
            Return      ;### User selected 'cancel'
        }
        GuiControl,, catver_path, %catver_path%
        Return
    }
  Done:
  {
    Gui,submit,nohide
    Gui,destroy
    Return
  }

  path_entry_windowGuiClose:
  Exit:
  {
    Gui path_entry_window:destroy
    ExitApp
  }
}

;---------------------------------------------------------------------------------------------------------

FilterSelectGUI() {

  DetectHiddenWindows, Off
  Gui, category_selection_window: new
  Gui, Default
  Gui, +LastFound

  ;### BEGIN LEFT COLUMN

  ;### output path
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w490 Section xm0 ym0 h70,%output_path_config_label%
  Gui, Font, s10 w400, Verdana
  Gui, Add, Edit, w310 xs8 ys+24 h24 voutput_path, %output_path%
    Gui, Add, Button, x+10 yp-1 w150 h26 gBrowseOutputFolder, Browse for folder...
  Gui, Add, Text, xs8 y+0 w470, %output_path_config_desc%

  ;### include filter
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w490 xm0 ys75 h382 Section,%include_list_label%
    Gui, Font, s12 w400, Verdana
    Gui, Add, ListBox, Sort Multi vinclude_filter xs9 ys+24 w470 h240, %category_list%

    ;### manual include filter
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+10, %manual_include_filter_label%
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, Edit, r3 xs8 w470 y+0 vmanual_include_filter, %manual_include_filter%
    Gui, Add, Link, xs8 w470 y+0, %manual_include_filter_desc%

  ;### other include filters
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xm0 y+14 w490 h92 Section, Other include filters
  Gui, Font, s10 w400, Verdana
  Gui, Add, Checkbox, xs8 ys24 w470 vbundle_bios_files       Checked%bundle_bios_files%,       Copy all BIOS sets
  Gui, Add, Checkbox, xs8 y+4  w470 vbundle_device_files     Checked%bundle_device_files%,     Copy all Device sets
  Gui, Add, Checkbox, xs8 y+4  w470 vbundle_mature_files     Checked%bundle_mature_files%,     Copy all Mature sets


  ;### BEGIN RIGHT COLUMN
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w490 Section x+20 ym0 h70,Generate manual filters
  Gui, Font, s10 w400, Verdana
  Gui, Add, Text, xs8 ys24 w300, Translate inclusion and exclusion selections into manual filters.
  Gui, Add, button, w150 x+20 ys24 h26 gGenerateManualFilters, Generate filters

  ;### exclude filter
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, w490 xs0 ys75 h382 Section,%exclude_list_label%
    Gui, Font, s12 w400, Verdana
    Gui, Add, ListBox, Sort 8 vexclude_filter xs9 ys+24 w470 h240, %category_list%

    ;### manual exclude filter entry
    Gui, Font, s10 w700, Verdana
    Gui, Add, Text, xs8 y+10, %manual_exclude_filter_label%
    Gui, Font, Normal s10 w400, Verdana
    Gui, Add, Edit, r3 xs8 w470 y+0 vmanual_exclude_filter, %manual_exclude_filter%
    Gui, Add, Link, xs8 w470 y+0, %manual_exclude_filter_desc%

  ;### other exclude filters
  Gui, Font, s12 w700, Verdana
  Gui, Add, Groupbox, xs0 y+14 w490 h162 Section, Other exclude filters
  Gui, Font, s10 w400, Verdana
  Gui, Add, Checkbox, xs8 ys24 w470 vexclude_bios_files         Checked%exclude_bios_files%,          Exclude BIOS sets
  Gui, Add, Checkbox, xs8 y+4  w470 vexclude_device_files       Checked%exclude_device_files%,        Exclude Device sets
  Gui, Add, Checkbox, xs8 y+4  w470 vexclude_mechanical_files   Checked%exclude_mechanical_files%,    Exclude Mechanical sets
  Gui, Add, Checkbox, xs8 y+4  w470 vexclude_mature_titles      Checked%exclude_mature_titles%,       Exclude Mature sets
  Gui, Add, Checkbox, xs8 y+4  w470 vexclude_CHD_titles         Checked%exclude_CHD_titles%,          Exclude sets with CHDs
  Gui, Add, Checkbox, xs8 y+4  w470 vexclude_non_running_titles Checked%exclude_non_running_titles%,  Exclude non-runnable sets (depending on MAME version this may also filter out BIOS, Device, and/or Mechanical)


  ;### Buttons
  Gui, Font, s10 w700, Verdana
  Gui, Add, button, w200 xs0 y+15 gCopyROMs, Copy Matching ROMs
  Gui, Add, button, w100 x+20 yp gExit_Category_Select, Return

  Gui, show, w1020, %app_title%
  return WinExist()

    BrowseOutputFolder:
    {
         FileSelectFolder, output_path, , 3
        if (output_path == "")
        {
            Return      ;### User selected 'cancel'
        }
        GuiControl,, output_path, %output_path%
    }
  GenerateManualFilters:
  {
    Gui, submit, nohide
    GuiControl,, manual_include_filter, %include_filter%
    GuiControl,, manual_exclude_filter, %exclude_filter%
    Return
  }
  CopyROMs:
  {
    Gui,submit,nohide
    if (manual_include_filter != "")
    {
      include_filter := manual_include_filter
    }
    else if (include_filter == "")
    {
      ;## not a problem if they're using the 'other' include filters
    }

    if (manual_exclude_filter != "")
    {
      exclude_filter := manual_exclude_filter
    }

    trigger_generation := True
    Gui category_selection_window:destroy
    Return
  }

  category_selection_windowGuiClose:
  Exit_Category_Select:
  {
    trigger_generation := False
    Gui category_selection_window:destroy
    Return
  }
}
