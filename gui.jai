BAKE_FONTS :: false;

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
            add_warning_popup(sprint("File '%' is not a valid NBT file (or doesn't exist).", path_filename(it)));
          } else {
            add_gui_nbt_file(nbt_file);
          }
        }
    }
  }

  info_warning_closed_index: s64 = -1;
  for info_warning_popups {
    if !it.open {
      info_warning_closed_index = it_index;
      break;
    }
  }

  if info_warning_closed_index != -1 {
    free(info_warning_popups[info_warning_closed_index].text.data);
    array_unordered_remove_by_index(*info_warning_popups, info_warning_closed_index);
  }

  tag_editor_closed_index: s64 = -1;
  for tag_editor_popups {
    if !it.open {
      tag_editor_closed_index = it_index;
      break;
    }
  }

  if tag_editor_closed_index != -1 {
    free(tag_editor_popups[tag_editor_closed_index].repr);
    array_unordered_remove_by_index(*tag_editor_popups, tag_editor_closed_index);
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
    for * tag_editor_popups {
      if it.open {
        add_subwindow(it, *popup_theme, it.id);
      }
    }
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

#if BAKE_FONTS {
  FONT        :: #run read_entire_file_bytes("./Inter-Light.ttf");
  FONT_ITALIC :: #run read_entire_file_bytes("./Inter-LightItalic.ttf");
}

background_font: *Simp.Dynamic_Font;
font:            *Simp.Dynamic_Font;
font_italic:     *Simp.Dynamic_Font;

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

Tag_Editor_Popup :: struct {
  id: s64 = 0;
  #as using info: Subwindow_Info;
  tag: *Tag;
  repr: string;
}

tag_editor_popups: [..]Tag_Editor_Popup;
info_warning_popups: [..]Info_Warning_Popup;

global_subwindow_id_counter: s64 = 1;

is_tag_too_complex :: (tag: *Tag) -> bool {
  using tag.payload;
  if type == .Compound {
      add_warning_popup(sprint("Type too complex. Open an issue or submit PR if you want this feature."));
      return true;
  }

  if type == .List {
    if as_list.count == 0 {
      add_warning_popup(sprint("Not supported because List has no type. Open an issue or submit PR if you want this feature."));
      return true;
    }

    if as_list[0].payload.type == .List
    || as_list[0].payload.type == .Compound
    || as_list[0].payload.type == .Byte_Array
    || as_list[0].payload.type == .Long_Array
    || as_list[0].payload.type == .Int_Array {
      add_warning_popup(sprint("Type too complex. Open an issue or submit PR if you want this feature."));
      return true;
    }
  }
  return false;
}

render_tag_editor_popup :: (state: *Subwindow_State, content_rect: Rect, user_data: *void) {
  text_theme := theme.text_input_theme;
  text_theme.font = font;
  text_theme.rectangle_shape.roundedness = 0.;

  repr := cast(*string, user_data);

  // NOTE: taken from the GetRect/example.jai of JAI distribution
  modify_string :: (ps: *string, new_value: string) {
    free(ps.*);
    ps.* = copy_string(new_value);
  }

  action, new_text := text_input(content_rect, repr.*, *text_theme);
  if action & .ENTERED  modify_string(repr, new_text);
}

tag_to_string :: (tag: *Tag) -> bool, string {
  using tag.payload;

  list_tag_to_string :: (tag: *Tag) -> bool, string {
    builder: String_Builder;
    init_string_builder(*builder);

    append(*builder, "[");

    for tag.payload.as_list {
      value: string;

      if it.type == {
      case .End;        return false, "BUG: .End tag must never be here";
      case .Compound;   return false, "BUG: not implemented and shouldn't reach here";
      case .List;       return false, "BUG: not implemented and shouldn't reach here";
      case .Byte;       value = tprint("%",     it.as_byte);
      case .Short;      value = tprint("%",     it.as_short);
      case .Int;        value = tprint("%",     it.as_int);
      case .Long;       value = tprint("%",     it.as_long);
      case .Float;      value = tprint("%",     it.as_float);
      case .Double;     value = tprint("%",     it.as_double);
      case .Byte_Array; value = tprint("%",     it.as_byte_array);
      case .String;     value = tprint("\"%\"", it.as_string);
      case .Int_Array;  value = tprint("%",     it.as_int_array);
      case .Long_Array; value = tprint("%",     it.as_long_array);
      case; assert(false);
      }

      append(*builder, value);

      if it_index < (tag.payload.as_list.count - 1) {
        append(*builder, ", ");
      }
    }

    append(*builder, "]");

    repr := builder_to_string(*builder);
    free(builder.current_buffer);
    return true, repr;
  }

  if #complete type == {
  case .End;        return false, "BUG: .End tag must never be here";
  case .Byte;       return true, sprint("%", as_byte);
  case .Short;      return true, sprint("%", as_short);
  case .Int;        return true, sprint("%", as_int);
  case .Long;       return true, sprint("%", as_long);
  case .Float;      return true, sprint("%", as_float);
  case .Double;     return true, sprint("%", as_double);
  case .Byte_Array; return true, sprint("%", as_byte_array);
  case .String;     return true, copy_string(as_string);
  case .Compound;   return false, "BUG: not implemented and shouldn't reach here";
  case .Int_Array;  return true, sprint("%", as_int_array);
  case .Long_Array; return true, sprint("%", as_long_array);
  case .List; {
    succ, repr := list_tag_to_string(tag);
    return succ, repr;
  }
  }
}

add_tag_editor_popup :: (tag: *Tag) {
  if is_tag_too_complex(tag) then return;

  editor := Tag_Editor_Popup.{
    id = next_subwindow_id(),
    tag = tag,
  };

  editor.info = Subwindow_Info.{};
  {
    using editor.info;
    title_text = ifx tag.name != "" then tag.name else sprint("%", tag.payload.type);
    rect = get_rect(xx window_width * .5,
                    xx window_height * .5,
                    xx window_width * .3,
                    xx font.character_height * 2.5);
    draw = render_tag_editor_popup;
  }

  succ, repr_or_error := tag_to_string(tag);
  assert(succ, repr_or_error);
  editor.repr = repr_or_error;

  array_add(*tag_editor_popups, editor);

  {
    using,only(info, repr) tag_editor_popups[tag_editor_popups.count-1];
    info.user_data = *repr;
  }
}

render_warning_info_popup :: (state: *Subwindow_State, content_rect: Rect, user_data: *void) {
  text := cast(*string, user_data).*;

  label_theme := theme.label_theme;
  label_theme.font = font;

  label(content_rect, text, *label_theme);
}

working_directory_set := false;

init_fonts :: () {
  font_data:        []u8;
  font_italic_data: []u8;

  #if BAKE_FONTS {
    font_data   = FONT;
    font_italic = FONT_ITALIC;
  } else {
    if !working_directory_set {
      // So that we can load our font, set to path of running executable.
      path := path_strip_filename(get_path_of_running_executable());
      set_working_directory(path);

      working_directory_set = true;
    }

    font_data        = read_entire_file_bytes("./Inter-Light.ttf");
    font_italic_data = read_entire_file_bytes("./Inter-LightItalic.ttf");
  }

  background_font_height := window_height / 16;
  background_font = Simp.get_font_at_size(font_data, background_font_height);

  font_height := window_height / 30;
  font = Simp.get_font_at_size(font_data, font_height);
  font_italic = Simp.get_font_at_size(font_italic_data, font_height);
}

add_warning_popup :: (message: string) {
  popup := Info_Warning_Popup.{};
  popup.title_text = "WARNING";
  popup.text = copy_string(message);

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

  gui_nbt_file.nbt.path = copy_string(nbt_file.path);
  gui_nbt_file.nbt.basename = copy_string(nbt_file.basename);
  gui_nbt_file.nbt.content = nbt_file.content;

  gui_nbt_file.subwindow_id = next_subwindow_id();
  gui_nbt_file.info.title_text = gui_nbt_file.nbt.basename;

  gui_nbt_file.info.rect = get_rect(xx ((gui_nbt_file.subwindow_id * 64) % window_width),
                                    xx ((gui_nbt_file.subwindow_id * 64) % window_height),
                                    xx (window_width  * .3),
                                    xx (window_height * .9));
  gui_nbt_file.info.draw = render_nbt_file;

  gui_nbt_file.info.user_data = cast(*void, gui_nbt_files.count);
  array_add(*gui_nbt_files, gui_nbt_file);
}

INDENT_STEP :: 1;
render_tag :: (subwindow_rect: Rect, x: float, y: float, tag: *Tag, indent: s64 = 0) -> (tag_width: float, new_y: float) {
  INDENT_SPACE_WIDTH: float = xx font.em_width;

  indent_width := INDENT_SPACE_WIDTH * indent;
  new_y := y;

  tag_width := indent_width;

  determine_tag_type :: (tag: *Tag) -> string {
    if tag.payload.type == .List {
      list_type := "";

      if tag.payload.as_list.count > 0 {
        list_type = tprint("%", tag.payload.as_list[0].payload.type);
      }

      return tprint(": %[%]", tag.payload.type, list_type);
    } else {
      return tprint(": %", tag.payload.type);
    }
  }

  new_y -= xx font.default_line_spacing;

  tag_font := font;

  mouse_x, mouse_y, succ := get_mouse_pointer_position(window, true);
  mouse_pos := Vector2.{xx mouse_x, xx mouse_y};

  tag_name := tprint("\"%\"", tag.name);
  name_width := Simp.prepare_text(tag_font, tag_name);

  selection_y_offset := font.character_height / 12;

  left_x   := cast(float32, x + tag_width);
  right_x  := cast(float32, x + tag_width + name_width);
  top_y    := cast(float32, new_y + font_italic.character_height - font_italic.y_offset_for_centering / 2);
  bottom_y := cast(float32, new_y - font_italic.y_offset_for_centering / 2);
  tag_name_rect := Vector4.{left_x, bottom_y, right_x, top_y};

  left_mouse_button_state  := Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT];
  right_mouse_button_state := Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_RIGHT];

  HIGHTLIGHT_COLOR := theme.text_input_theme.text_color_autocomplete;
  TAG_NAME_COLOR   := theme.text_input_theme.text_color_over;
  TAG_TYPE_COLOR   := theme.text_input_theme.text_color;

  is_point_inside_rect :: (p: Vector2, r: Vector4) -> bool {
    return p.x > r.x && p.x < r.z && p.y > r.y && p.y < r.w;
  }

  subwindow_status := get_status_flags(subwindow_rect);

  my_weird_subwindow_rect := Vector4.{subwindow_rect.x, subwindow_rect.y, subwindow_rect.w, subwindow_rect.h};
  is_mouse_inside_this_subwindow := (subwindow_status != 0) && is_point_inside_rect(mouse_pos, my_weird_subwindow_rect);

  if is_mouse_inside_this_subwindow && succ && is_point_inside_rect(mouse_pos, tag_name_rect) {
    if left_mouse_button_state == .END then add_tag_editor_popup(tag);
    else if left_mouse_button_state != .NONE {
      TAG_NAME_COLOR   = theme.text_input_theme.text_color_autocomplete;
      HIGHTLIGHT_COLOR = theme.text_input_theme.text_color_over;
    }

    tag_font = font_italic;
    Simp.prepare_text(tag_font, tag_name);

    Simp.immediate_quad(cast(float32) left_x, xx top_y, xx right_x, xx bottom_y, HIGHTLIGHT_COLOR);
  }

  Simp.draw_prepared_text(tag_font, xx (x + tag_width), xx new_y, TAG_NAME_COLOR);
  tag_width += xx name_width;

  tag_width += Simp.draw_text(font, xx (x + tag_width), xx new_y, determine_tag_type(tag), TAG_TYPE_COLOR);

  TREE_LINE_COLOR      := theme.text_input_theme.frame_color;
  TAG_TREE_LINE_WIDTH  := font.character_height / 12;

  if tag.payload.type == .Compound {
    compound_tag_width := 0.;
    child_max_y := 0.;
    for * tag.payload.as_compound {
      sub_tag_width, sub_new_y := render_tag(subwindow_rect, x, new_y, it, indent + INDENT_STEP);
      child_max_y = new_y;
      new_y = sub_new_y;
      compound_tag_width = max(compound_tag_width, sub_tag_width);
    }
    child_max_y -= font.default_line_spacing;
    tag_width = max(tag_width, compound_tag_width);

    if tag.payload.as_compound.count > 0 {
      tag_tree_line_x := x + indent_width;
      Simp.immediate_quad(tag_tree_line_x,
                          y-cast(float, font.default_line_spacing),
                          tag_tree_line_x+TAG_TREE_LINE_WIDTH,
                          new_y,
                          TREE_LINE_COLOR);
    }
  }
  Simp.immediate_flush();

  return tag_width, new_y;
}

// most of the GetRect stuff here is copy-pasted from modules/GetRect/examples/example.jai
render_nbt_file :: (state: *Subwindow_State, rect: Rect, data: *void) {
  index := cast(s64, data);
  subwindow_id := gui_nbt_files[index].subwindow_id;

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

  horizontal_region, inside_horizontal := begin_scrollable_region(rect, *horizontal_theme, subwindow_id);
  vertical_region, inside := begin_scrollable_region(inside_horizontal, *vertical_theme,   subwindow_id);

  scrollbar_width := inside_horizontal.w - inside.w;

  x := inside.x + pad      - gui_nbt_files[index].horizontal_scroll_value;
  y := inside.y + inside.h + gui_nbt_files[index].vertical_scroll_value;

  tag_width, new_y := render_tag(state.info.rect, x, y, *gui_nbt_files[index].nbt.content);

  y = new_y;

  min_y := y - pad;
  max_x := x + tag_width + scrollbar_width + pad;

  end_scrollable_region(vertical_region,   0,     min_y, *gui_nbt_files[index].vertical_scroll_value);
  end_scrollable_region(horizontal_region, max_x, 0,     *gui_nbt_files[index].horizontal_scroll_value);

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
