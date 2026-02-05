quit := false;

init :: () {
  #if OS == .WINDOWS {
    Windows :: #import "Windows";
    Windows.SetProcessDPIAware();

    // Windows is very bad at thread-switching by default unless you do this. Sad.
    Windows.timeBeginPeriod(1);
  }

  window = create_window(window_width, window_height, "NBTex");

  #if OS == .WINDOWS {
    Windows.DragAcceptFiles(window, cast(Windows.BOOL) true);
  } else #if OS == .LINUX {
    X11 :: #import "X11";
    typelist := string.["url/url", "text/uri-list", "text/plain", "application/gzip", "application/octet-stream"];
    X11.enable_drag_and_drop(window, typelist);
  } else #if OS == .MACOS {
    #import "Objective_C";
    #import "Objective_C/AppKit";
    // i dont have any macos so i'm not sure what should i do here
    types := NSArray(NSPasteboardType).arrayWithObject(NSPasteboardTypeFileURL);
    NSView.registerForDraggedTypes(window, types);
  }

  Simp.set_render_target(window);

  init_fonts();
  ui_init();
}

update_and_process_events :: () {
  Input.update_window_events();

  for Input.get_window_resizes() {
    Simp.update_window(it.window);

    if it.window == window {
      should_reinit := (it.width != window_width) || (it.height != window_height);

      window_width  = it.width;
      window_height = it.height;

      if should_reinit init_fonts();  // Resize the font for the new window size.
    }
  }

  for event: Input.events_this_frame {
    if event.type == .QUIT then quit = true;

    getrect_handle_event(event);

    if event.type == {
      case .DRAG_AND_DROP_FILES;
        for event.files {
          nbt_file, success := read_nbt_file(it);
          if !success then {
            popup := Info_Warning_Popup.{};
            popup.title_text = "WARNING";
            popup.text = sprint("File '%' is not a valid NBT file (or doesn't exist).", path_filename(it));

            text_width := Simp.prepare_text(font, popup.text);
            popup.rect = get_rect(xx window_width * .5 - xx text_width * .5, xx window_height * .5, xx (text_width * 1.05), xx font.character_height * 2.5);
            popup.draw = render_warning_info_popup;

            array_add(*info_warning_popups, popup);

            {
              using info_warning_popups[info_warning_popups.count-1];
              info.user_data = *text;
            }
          } else {
            print("parsed % file\n", nbt_file.basename);
            gui_nbt_file := GUI_NBT_File.{};
            gui_nbt_file.nbt = nbt_file;
            array_add(*gui_nbt_files, gui_nbt_file);
          }
        }
    }
  }

  closed_index: s64 = -1;
  for info_warning_popups {
    if !it.open {
      closed_index = it_index;
      break;
    }
  }

  if closed_index != -1 {
    free(info_warning_popups[closed_index].text.data);
    array_unordered_remove_by_index(*info_warning_popups, closed_index);
  }
}

get_delta_time :: () -> float {
  current_time = seconds_since_init();
  dt := cast(float, current_time - last_time);
  Clamp(*dt, 0, 0.1);
  last_time = current_time;

  return dt;
}

render_frame :: (dt: float) {
  proc := default_theme_procs[current_theme];
  theme = proc();
  set_default_theme(theme);

  theme.font = font;

  bg_col := theme.background_color;
  Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

  _, _, width, height := get_dimensions(window, true);
  ui_per_frame_update(window, width, height, current_time);

  {
    label_theme := theme.label_theme;
    label_theme.font = background_font;
    label_theme.text_color = theme.text_color;

    font_height: float = xx background_font.character_height;

    r := get_rect(0, xx (window_height / 2) + font_height*.5, xx window_width, font_height);
    label(r, "Drag'n'Drop files", *label_theme);

    r = get_rect(0, xx (window_height / 2) - font_height*.5, xx window_width, font_height);
    label(r, "to start tinkering…", *label_theme);
  }

  {
    label_theme := theme.label_theme;
    label_theme.font = font;
    label_theme.text_color = theme.background_color_bright;

    font_height: float = xx font.character_height;

    r := get_rect(0, font_height/2, xx window_width, font_height);
    label(r, "Or pass your files as cmd args :)", *label_theme);
  }

  {
    popup_theme := theme.subwindow_theme;

    for * info_warning_popups {
      if it.open {
        add_subwindow(it, *popup_theme, it_index);
      }
    }
  }

  draw_popups();

  Simp.swap_buffers(window);
}

#scope_file

window: Window_Type;
window_width:  s32 = 1600;
window_height: s32 = 900;

current_time: float64;
last_time:    float64;

FONT :: #run read_entire_file_bytes("./Inter-Light.ttf");

background_font: *Simp.Dynamic_Font;
font:            *Simp.Dynamic_Font;

current_theme: s32 = xx Default_Themes.Freddie_Freeloader;
theme: Overall_Theme;

GUI_NBT_File :: struct {
  #as using nbt: NBT_File;
}

gui_nbt_files: [..]GUI_NBT_File;

Info_Warning_Popup :: struct {
  #as using info: Subwindow_Info;
  text: string;
}

info_warning_popups: [..]Info_Warning_Popup;

render_warning_info_popup :: (state: *Subwindow_State, content_rect: Rect, user_data: *void) {
  text := cast(*string, user_data).*;

  label_theme := theme.label_theme;
  label_theme.font = font;

  label(content_rect, text, *label_theme);
}

working_directory_set := false;

init_fonts :: () {
  if !working_directory_set {
    // So that we can load our font, set to path of running executable.
    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    working_directory_set = true;
  }

  background_font_height := window_height / 16;
  background_font = Simp.get_font_at_size(FONT, background_font_height);

  font_height := window_height / 30;
  font = Simp.get_font_at_size(FONT, font_height);
}

#import "GetRect";
#import "Math";
#import "Window_Creation";
#import "String";
#import "System";

Simp :: #import "Simp";
Input :: #import "Input";
