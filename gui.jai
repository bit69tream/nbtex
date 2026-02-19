quit := false;

init :: (files_via_command_line: []string) {
  for files_via_command_line {
    nbt_file, success := read_nbt_file(it);

    if !success {
      print("ERROR: File '%' is either not a valid NBT file or inaccessible.\n", path_filename(it));
      exit(1);
    }

    add_gui_nbt_file(nbt_file);
  }

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
            add_warning_popup(it);
          } else {
            add_gui_nbt_file(nbt_file);
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

  gui_nbt_file_deletion_index := -1;

  if gui_nbt_files.count == 0 then render_tooltip();
  else for * gui_nbt_files {
    window_theme := theme.subwindow_theme;
    if it.info.open {
      add_subwindow(*it.info, *window_theme, it.subwindow_id);
    } else {
      gui_nbt_file_deletion_index = it_index;
    }
  }

  if gui_nbt_file_deletion_index != -1 {
    // @Todo save file dialog
    array_unordered_remove_by_index(*gui_nbt_files, gui_nbt_file_deletion_index);
  }

  {
    popup_theme := theme.subwindow_theme;

    for * info_warning_popups {
      if it.open {
        add_subwindow(it, *popup_theme, it.id);
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
  subwindow_id: s64;
  info: Subwindow_Info;
  horizontal_scroll_value: float;
  vertical_scroll_value: float;
}

gui_nbt_files: [..]GUI_NBT_File;

Info_Warning_Popup :: struct {
  id: s64 = 0;
  #as using info: Subwindow_Info;
  text: string = "";
}

info_warning_popups: [..]Info_Warning_Popup;

global_subwindow_id_counter: s64 = 0;

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

add_warning_popup :: (path: string) {
  popup := Info_Warning_Popup.{};
  popup.title_text = "WARNING";
  popup.text = sprint("File '%' is not a valid NBT file (or doesn't exist).", path_filename(path));

  text_width := Simp.prepare_text(font, popup.text);
  popup.rect = get_rect(xx window_width * .5 - xx text_width * .5,
                        xx window_height * .5,
                        xx (text_width * 1.05),
                        xx font.character_height * 2.5);
  popup.draw = render_warning_info_popup;

  popup.id = next_subwindow_id();

  array_add(*info_warning_popups, popup);

  {
    using info_warning_popups[info_warning_popups.count-1];
    info.user_data = *text;
  }
}

add_gui_nbt_file :: (nbt_file: NBT_File) {
  gui_nbt_file := GUI_NBT_File.{};
  gui_nbt_file.nbt = nbt_file;

  gui_nbt_file.subwindow_id = next_subwindow_id();
  gui_nbt_file.info.title_text = nbt_file.basename;
  gui_nbt_file.info.rect = get_rect(xx (window_width / 64),
                                    xx (window_height / 64),
                                    xx (window_width * .5),
                                    xx (window_height * .9));
  gui_nbt_file.info.draw = render_nbt_file;

  gui_nbt_file.info.user_data = cast(*void, gui_nbt_files.count);
  array_add(*gui_nbt_files, gui_nbt_file);
}

// most of the GetRect stuff here is copy-pasted from modules/GetRect/examples/example.jai
render_nbt_file :: (state: *Subwindow_State, rect: Rect, data: *void) {
  index := cast(s64, data);
  gui_nbt_file := *gui_nbt_files[index];

  pad := floor(font.default_line_spacing * .5 + .5);
  vertical_theme := theme.scrollable_region_theme;

  vertical_theme.margin_flags = 0;
  vertical_theme.region_background.frame_color.w = 0;

  horizontal_theme := vertical_theme;
  {
    using horizontal_theme;
    direction = .HORIZONTAL;
    scrollbar_nib_theme.rectangle_shape.frame_thickness_type = .RELATIVE_TO_HEIGHT;
    scrollbar_nib_theme.rectangle_shape.roundedness_type     = .RELATIVE_TO_HEIGHT;
    region_background.shape.roundedness_type                 = .RELATIVE_TO_HEIGHT;
    scrollbar_background.shape.roundedness_type              = .RELATIVE_TO_HEIGHT;
    region_background.shape.rounding_flags                   = .NORTHWEST | .NORTHEAST;
    scrollbar_background.shape.rounding_flags                = .SOUTHWEST | .SOUTHEAST;
  }

  horizontal_region, inside_horizontal := begin_scrollable_region(rect, *horizontal_theme);
  vertical_region, inside := begin_scrollable_region(inside_horizontal, *vertical_theme);

  scrollbar_width := inside_horizontal.w - inside.w;

  x := inside.x + pad - gui_nbt_file.horizontal_scroll_value;
  y := inside.y + inside.h + gui_nbt_file.vertical_scroll_value;

  max_width := inside.w - scrollbar_width;

  // actual rendering

  min_y := y + cast(float) font.default_line_spacing - pad;
  max_x := x + max_width + scrollbar_width + pad;

  end_scrollable_region(vertical_region, 0, min_y,   *gui_nbt_file.vertical_scroll_value);
  end_scrollable_region(horizontal_region, max_x, 0, *gui_nbt_file.horizontal_scroll_value);

  gui_nbt_files[index].info.snap_to_size.x = max_x - x + pad;
  gui_nbt_files[index].info.snap_to_size.y = inside.y - min_y + rect.h; // inside.h cancels itself
}

next_subwindow_id :: () -> s64 {
  id := global_subwindow_id_counter;
  global_subwindow_id_counter += 1;

  return id;
}

render_tooltip :: () {
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
}

#import "GetRect";
#import "Math";
#import "Window_Creation";
#import "String";
#import "System";

Simp  :: #import "Simp";
Input :: #import "Input";
