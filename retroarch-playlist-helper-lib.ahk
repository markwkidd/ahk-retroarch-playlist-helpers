;### AUTOHOTKEY FUNCTIONS FOR RETROARCH PLAYLISTS AND THUMBNAILS
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;### newShrinkArcadeDAT(datfile_source, ByRef shrunk_DAT_array)
;### Parses an XML DAT file for MAME or FB Alpha
;### creates associative 2D array objects in shrunk_DAT_array

BuildArcadeDATArray(datfile_path, ByRef shrunk_DAT_array, display_progress_bar:=False) {

  shrunk_DAT_array   := Object()
  dat_contents       := ""
  dat_length         := 0
  is_old_XML_format  := False
  old_XML_parent_tag := "<game"
  new_XML_parent_tag := "<machine"
  scanning_pos       := 0
  needle             := ""

  if(display_progress_bar) {
    Progress, A M T, %datfile_path%,,Parsing arcade DAT
  }

  FileRead, dat_contents, %datfile_path%
  dat_length := StrLen(dat_contents)

  needle = PSs)<(?:game|machine) name="(.*?)"(?:\s(.*?))?>(?:\s*?)(.*?)</(?:game|machine)>

  scanning_pos := 0
  Loop {
    scanning_pos += 1

    if(display_progress_bar) {
      parsing_progress := Round(100 * (scanning_pos / dat_length))
      Progress, %parsing_progress%
    }

    scanning_pos := RegExMatch(dat_contents, needle, dat_match, scanning_pos)
    if(!scanning_pos) {
      break
    }

    romset_name    := (SubStr(dat_contents, dat_matchPos1, dat_matchLen1) . "")
    modifiers      := (SubStr(dat_contents, dat_matchPos2, dat_matchLen2) . "")
    XML_subentries := (SubStr(dat_contents, dat_matchPos3, dat_matchLen3) . "")

    is_BIOS         := False
    is_device       := False
    is_mechanical   := False
    clone_of        := False
    ROM_of          := False
    runnable        := True
    needs_CHD       := False
    CHD_only        := False
    title           := ""
    year            := ""
    manufacturer    := ""
    player_count    := 0

    if(romset_name == "") {
      MsgBox Unexpected error processing DAT file.`n`nROM set name:%romset_name% Title:%dat_title%
      ExitApp
    }
    if (InStr(modifiers, "isbios=""yes""")) {
      is_BIOS          := True
    }
    if (InStr(modifiers, "isdevice=""yes""")) {
      is_device        := True
    }
    if (InStr(modifiers, "ismechanical=""yes""")) {
      is_mechanical    := True
    }

    attribute_start_pos := InStr(modifiers, "cloneof")
    if(attribute_start_pos) {
      attribute_start_pos += 9
      clone_of := SubStr(modifiers, attribute_start_pos, (InStr(modifiers, """", false, attribute_start_pos) - attribute_start_pos))
    }

    attribute_start_pos := InStr(modifiers, "romof")
    if(attribute_start_pos) {
      attribute_start_pos += 7
      ROM_of := SubStr(modifiers, attribute_start_pos, (InStr(modifiers, """", false, attribute_start_pos) - attribute_start_pos))
    }

    if (InStr(XML_subentries, "status=""preliminary""")) {
      runnable        := False
    }

    if (InStr(XML_subentries, "emulation=""preliminary""")) {
      runnable        := False
    }

    if (InStr(XML_subentries, "status=""protection""")) {
      runnable        := False
    }

    if (InStr(XML_subentries, "protection=""preliminary""")) {
      runnable        := False
    }

    if(InStr(XML_subentries, "disk")) {
      needs_CHD       := True
    }
    
    ;### TODO: detect CHD-only sets
    ;### CHD_only     := True

    attribute_start_pos := InStr(XML_subentries, "<description>")
    if(attribute_start_pos) {
      attribute_start_pos += 13
      title           := SubStr(XML_subentries, attribute_start_pos, (InStr(XML_subentries, "</description>") - attribute_start_pos))
    }

    attribute_start_pos := InStr(XML_subentries, "<year>")
    if(attribute_start_pos) {
      attribute_start_pos += 6
      year            := SubStr(XML_subentries, attribute_start_pos, 4)
    }

    attribute_start_pos := InStr(XML_subentries, "<manufacturer>")
    if(attribute_start_pos){
      attribute_start_pos += 14
      manufacturer    := SubStr(XML_subentries, attribute_start_pos, (InStr(XML_subentries, "</manufacturer>") - attribute_start_pos))
    }
    
    attribute_start_pos := InStr(XML_subentries, "players=""")
    if(attribute_start_pos) {
      attribute_start_pos += 9
      player_count    := SubStr(XML_subentries, attribute_start_pos, 1)
    }

    if(title != "") {
      title := StrReplace(title, "&#179;", "3") ;### Remove HTML encoded characters in the DAT title --
      title := StrReplace(title, "&apos;", "'") ;### only handles characters actually spotted in the wild
      title := StrReplace(title, "&amp;", "_")
    }


    shrunk_DAT_array[romset_name] := {romset_name:romset_name
                    , title:title
                    , needs_CHD:needs_CHD
                    , CHD_only:CHD_only
                    , is_BIOS:is_BIOS
                    , is_device:is_device
                    , is_mechanical:is_mechanical
                    , clone_of:clone_of
                    , ROM_of:ROM_of
                    , runnable:runnable
                    , year:year
                    , manufacturer:manufacturer
                    , player_count:player_count}
  }

  if(display_progress_bar) {
    Progress, Off
  }
}

;---------------------------------------------------------------------------------------------------------

;### PlaylistGenerator
;###
;### ROM_file_array needs to be an associative array in this format:
;### ROM_file_array[ROM_name_no_file_extension].path == full path to the ROM file
;### ROM_file_array[ROM_name_no_file_extension].title == the title to display on the playlist

PlaylistGenerator(ByRef ROM_file_array, playlist_filename, playlist_name, playlist_ROM_path, path_delimiter, display_progress_bar:=False) {

  playlist_file := FileOpen(playlist_filename,"w") ;### erases any existing file and opens a new file with this name

  number_of_files    := NumGet(&ROM_file_array + 4*A_PtrSize)   ;### associative array size. voodoo from the AHK forums
  current_ROM_count  := 0

  if(display_progress_bar) {
    Progress, A M T, Generating playlist:`n%playlist_name%,,%app_title%
  }

  For rom_index, rom_details in ROM_file_array
  {
    current_ROM_count += 1
    current_ROM_path := rom_details.path
    SplitPath, current_ROM_path, ROM_filename_with_ext,current_ROM_directory,,

    if(display_progress_bar) {
      percent_parsed := Round(100 * (current_ROM_count / number_of_files))
      Progress, %percent_parsed%
    }

    playlist_entry_ROM_path :=  playlist_ROM_path . path_delimiter . playlist_name . path_delimiter . ROM_filename_with_ext
    playlist_entry := FormatPlaylistEntry(playlist_entry_ROM_path, (rom_details.title), RA_core_path, playlist_name)
    playlist_file.Write(playlist_entry)
  }

  playlist_file.Close() ;### close and flush the new playlist file

  if(display_progress_bar) {
    Progress, Off
  }
}


;---------------------------------------------------------------------------------------------------------

SanitizeFilename(input_string) {            ;### fix chars for multi-platform use per No-Intro standard
  input_string := StrReplace(input_string, "&",  "_")
  input_string := StrReplace(input_string, "\",  "_")
  input_string := StrReplace(input_string, "/",  "_")
  input_string := StrReplace(input_string, "?",  "_")
  input_string := StrReplace(input_string, ":",  "_")
  input_string := StrReplace(input_string, "``", "_")
  input_string := StrReplace(input_string, "<",  "_")
  input_string := StrReplace(input_string, ">",  "_")
  input_string := StrReplace(input_string, "*",  "_")
  input_string := StrReplace(input_string, "|",  "_")
  return input_string
}


;---------------------------------------------------------------------------------------------------------
StripFinalSlash(ByRef source_path)
{
  last_char = SubStr(source_path,0,1)

  if ((last_char == "\") or (last_char == "/"))
  {
    StringTrimRight, source_path, source_path, 1
  }
}

;---------------------------------------------------------------------------------------------------------

FormatPlaylistEntry(playlist_entry_rom_path, playlist_title, core_path, playlist_name) {
  playlist_entry := playlist_entry_rom_path . "`n"
                    . playlist_title . "`n"
                    . core_path . "`n"
                    . "DETECT" . "`n"
                    . "DETECT" . "`n"
                    . playlist_name . ".lpl" . "`n"
    return playlist_entry
}

;---------------------------------------------------------------------------------------------------------

;### DownloadFile function by Bruttosozialprodukt with modifications
DownloadFile(UrlToFile, SaveFileAs, Overwrite := True, UseProgressBar := True) {

    ;### Check if the file already exists and if we must not overwrite it
  If (!Overwrite && FileExist(SaveFileAs)) {
    Return
  }

  If (UseProgressBar) {
    LastSize =
    LastSizeTick =

    ;### Initialize the WinHttpRequest Object
    WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    WebRequest.SetTimeouts("10000", "10000", "10000", "10000")

    WebRequest.Open("HEAD", UrlToFile)
    WebRequest.Send()
    WebRequest.WaitForResponse()

    ;#### Download the headers
    if (WebRequest.Status() == 404)      ;### 404 error
      return

    ;### Store the header which holds the file size in a variable:
    FinalSize := WebRequest.GetResponseHeader("Content-Length")
    ;### Create the progressbar and the timer
    Progress, , , Downloading..., %UrlToFile%
    SetTimer, __UpdateProgressBar, 100
  }

    ;Download the file
  UrlDownloadToFile, %UrlToFile%, %SaveFileAs%
    ;Remove the timer and the progressbar because the download has finished
  If (UseProgressBar) {
    Progress, Off
    SetTimer, __UpdateProgressBar, Off
  }
    Return

  __UpdateProgressBar:
    ;Get the current filesize and tick
    CurrentSize := FileOpen(SaveFileAs, "r").Length ;FileGetSize wouldn't return reliable results
    CurrentSizeTick := A_TickCount

    ;Calculate the downloadspeed
    Speed := Round((CurrentSize/1024-LastSize/1024)/((CurrentSizeTick-LastSizeTick)/1000)) . " Kb/s"
    ;Save the current filesize and tick for the next time
    LastSizeTick := CurrentSizeTick
    LastSize := FileOpen(SaveFileAs, "r").Length
    ;Calculate percent done
    PercentDone := Round(CurrentSize/FinalSize*100)
    ;Update the ProgressBar
    progress_caption := "Downloading: " . UrlToFile . "`nDestination: " . SaveFileAs
    Progress, %PercentDone%, %progress_caption%, %PercentDone%`% (%Speed%), Downloading thumbnails
    Return
}


