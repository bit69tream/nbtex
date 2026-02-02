#import "GetRect";
#import "Math";
#import "Window_Creation";
#import "String";
#import "System";

Simp :: #import "Simp";
Input :: #import "Input";

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

NBT_File :: struct {
  path:     string;
  basename: string;
  content:  Tag;
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

  draw_popups();

  Simp.swap_buffers(window);
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

main :: () {
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
    //                  gzipped nbt files   uncompressed nbt files
    typelist := string.["application/gzip", "application/octet-stream"];
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

  quit := false;
  while !quit {
    current_time = seconds_since_init();
    dt := cast(float, current_time - last_time);
    Clamp(*dt, 0, 0.1);
    last_time = current_time;

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
          // for dropped_files free(it);
          // array_reset(*dropped_files);
          // for event.files array_add(*dropped_files, copy_string(it));
      }
    }

    render_frame(dt);

    reset_temporary_storage();
    sleep_milliseconds(16);
  }
}

old_main :: () {
  path := get_file_from_command_line_arguments();

  data, success := read_nbt_file(path);
  if !success then exit(1);

  next_data, level, succ := parse_tag(data);

  print_tag_as_json(level);
}

get_file_from_command_line_arguments :: () -> string {
  args := get_command_line_arguments();

  usage :: #string END
USAGE: nbtex [filepath]
END;

  if args.count > 2 {
    print("ERROR: incorrect command line arguments\n", to_standard_error = true);
    print("%", usage, to_standard_error = true);
    exit(1);
  }

  if args.count <= 1 {
    print("%", usage, to_standard_error = true);
    exit(1);
  }

  return args[1];
}

#import "Basic";
#import "Bit_Operations";

#load "file.jai";
#load "parser.jai";
