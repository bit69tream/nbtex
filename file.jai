#import "File";

NBT_File :: struct {
  path:     string;
  basename: string;
  content:  Tag;
}

// this function takes care of error reporting
read_nbt_file :: (path: string) -> NBT_File, bool {
  absolute_path := get_absolute_path(path);
  deflated_data, success := read_entire_file_bytes(absolute_path);

  if !success {
    System :: #import "System";

    code, s := System.get_error_value_and_string();
    print("ERROR: Unable to read file '%': %\n", path, s, to_standard_error = true);
    return .{}, false;
  }

  data: []u8 = ---;

  if is_gzip(deflated_data) {
    defer free(deflated_data.data);

    inflated_data, success := inflate(deflated_data);
    if !success {
      print("ERROR: File '%' is probably corrupted\n", path, to_standard_error = true);
      return .{}, false;
    }

    data = inflated_data;
  } else {
    data = deflated_data;
  }

  _, tag, succ := parse_tag(data);
  if !succ then return .{}, false;

  ret: NBT_File;
  ret.path = copy_string(absolute_path);
  ret.basename = path_filename(absolute_path);
  ret.content = tag;

  return ret, true;
}

read_entire_file_bytes :: (name: string) -> [] u8, bool {
  content, success := read_entire_file(name, log_errors = false);

  return xx content, success;
}

#scope_file

is_gzip :: (data: []u8) -> bool {
  // gzip magic number
  return data[0] == 0x1f && data[1] == 0x8b;
}

// https://en.wikipedia.org/wiki/Gzip
skip_and_check_header :: (data: []u8) -> []u8, bool {
  header_size := 0;

  if !is_gzip(data) then return .{}, false;
  header_size += 2;

  if data[2] != 8 then return .{}, false;
  header_size += 1;

  // flags
  // [TODO]: implement support for flags so we can skip header properly
  assert(data[3] == 0, "we do not support any gzip flags at the moment.");
  header_size += 1;

  // skip useless metadata
  header_size += 6;

  ret := data;
  ret.data += header_size;
  ret.count -= header_size;

  return ret, true;
}

inflate :: (deflated_data: []u8) -> []u8, bool {
  #import "stb_image";

  headerless_data, success := skip_and_check_header(deflated_data);
  if !success then return .{}, false;

  length: s32 = ---;
  ret := stbi_zlib_decode_noheader_malloc(headerless_data.data, xx headerless_data.count, *length);

  if ret == null then return .{}, false;

  return .{data = ret, count = xx length}, true;
}
