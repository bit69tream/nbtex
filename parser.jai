Tag_Type :: enum u8 {
  End        :: 0;
  Byte       :: 1;
  Short      :: 2;
  Int        :: 3;
  Long       :: 4;
  Float      :: 5;
  Double     :: 6;
  Byte_Array :: 7;
  String     :: 8;
  List       :: 9;
  Compound   :: 10;
  Int_Array  :: 11;
  Long_Array :: 12;
}

Tag_Value :: union type: Tag_Type {
  .End        ,, _:             void;
  .Byte       ,, as_byte:       s8;
  .Short      ,, as_short:      s16;
  .Int        ,, as_int:        s32;
  .Long       ,, as_long:       s64;
  .Float      ,, as_float:      float32;
  .Double     ,, as_double:     float64;
  .Byte_Array ,, as_byte_array: []u8;
  .String     ,, as_string:     string;
  .List       ,, as_list:       []Tag;
  .Compound   ,, as_compound:   []Tag;
  .Int_Array  ,, as_int_array:  []s32;
  .Long_Array ,, as_long_array: []s64;
}

Tag :: struct {
  name: string;
  using payload: Tag_Value;
}

parse_tag :: (data: []u8) -> (next_data: []u8, value: Tag, success: bool) {
  for parsers {
    next_data, value, success := it.proc(data);
    if success then return next_data, value, true;
  }

  return .{}, .{}, false;
}

#scope_file

Tag_Parser_Proc :: #type (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool);
Tag_Parser :: struct {
  type: Tag_Type;
  proc: Tag_Parser_Proc;
}

parsers :: Tag_Parser.[
  .{.End,        parse_tag_end},
  .{.Byte,       parse_tag_byte},
  .{.Short,      parse_tag_short},
  .{.Int,        parse_tag_int},
  .{.Long,       parse_tag_long},
  .{.Float,      parse_tag_float},
  .{.Double,     parse_tag_double},
  .{.String,     parse_tag_string},
  .{.List,       parse_tag_list},
  .{.Compound,   parse_tag_compound},
  .{.Int_Array,  parse_tag_int_array},
  .{.Long_Array, parse_tag_long_array},
];

big_endian :: () -> bool {
  x : s16 = 1;

  b : *u8 = cast(*u8) *x;

  if b[0] return false;
  return true;
}

byte_swap_if_necessary :: (input: $T) -> T {
  if !big_endian() then return byte_swap(input);
  return input;
}

parse_string :: (data: []u8) -> (next_data: []u8, value: string, success: bool) {
  length: u16 = byte_swap_if_necessary(cast(*u16, data.data).*);

  value: string = ---;
  value.data = data.data + size_of(u16);
  value.count = length;

  next_data: []u8 = ---;
  next_data.data  = data.data + size_of(u16) + length;
  next_data.count = data.count - size_of(u16) - length;

  return next_data, value, true;
}

parse_tag_header :: (data: []u8, type: Tag_Type, is_named: bool = true) -> (next_data: []u8, name: string, success: bool) {
  if data[0] != xx type then return .{}, .{}, false;

  next_data := data;
  next_data.data += 1;
  next_data.count -= 1;

  ret_name := "";
  if is_named {
    data2, name, success := parse_string(next_data);
    if !success then return .{}, .{}, false;

    next_data = data2;
    ret_name = name;
  }

  return next_data, ret_name, true;
}

parse__primitive_tag ::
inline (data: []u8, is_named: bool = true, $type: Tag_Type) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, type, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  #insert -> string {
    String :: #import "String";
    #import "Reflection";

    field: string = sprint("as_%", enum_value_to_name(type));
    String.to_lower_in_place(field);

    return sprint(#string JAI
    payload: Tag_Value;
    payload.type    = type;
    payload.%       = byte_swap_if_necessary(cast(type_of(*payload.%), next_data.data).*);

    ret := Tag.{name, payload};

    next_data.data  += size_of(type_of(payload.%));
    next_data.count -= size_of(type_of(payload.%));
    JAI, field, field, field, field);
  }

  return next_data, ret, true;
}

parse_tag_end :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  if data[0] != xx Tag_Type.End then return .{}, .{}, false;
  next_data := data;
  next_data.data  += 1;
  next_data.count -= 1;

  ret: Tag;
  ret.type = .End;

  return next_data, ret, true;
}

parse_tag_byte :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Byte);
  return next_data, value, success;
}

parse_tag_short :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Short);
  return next_data, value, success;
}

parse_tag_int :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Int);
  return next_data, value, success;
}

parse_tag_long :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Long);
  return next_data, value, success;
}

parse_tag_float :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Float);
  return next_data, value, success;
}

parse_tag_double :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, value, success := parse__primitive_tag(data, is_named, .Double);
  return next_data, value, success;
}

parse_tag_string :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, .String, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  new_data, payload, succ := parse_string(next_data);
  if !succ then return .{}, .{}, false;

  ret: Tag = ---;
  ret.name = name;
  ret.payload.type = .String;
  ret.payload.as_string = payload;

  return new_data, ret, true;
}

parse_tag_list :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, .List, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  tag_id := cast(*u8,next_data.data).*;
  count  := byte_swap_if_necessary(cast(*s32, next_data.data+1).*);
  next_data.data  += size_of(u32)+size_of(u8);
  next_data.count -= size_of(u32)+size_of(u8);
  tag_type: Tag_Type = xx tag_id;

  proc: Tag_Parser_Proc;

  for parsers {
    if tag_type == it.type {
      proc = it.proc;
      break;
    }
  }

  payload: [..]Tag;
  array_reserve(*payload, xx count);

  for 0..count-1 {
    new_data, value, success := proc(next_data, false);
    if !success then return .{}, .{}, false;

    next_data = new_data;
    array_add(*payload, value);
  }

  ret: Tag = ---;
  ret.name = name;
  ret.payload = .{
    type = .List,
    as_list = payload,
  };

  return next_data, ret, true;
}

parse_tag_compound :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, .Compound, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  payload: [..]Tag;

  while true {
    new_data, tag, success := parse_tag(next_data);
    if !success then return .{}, .{}, false;

    next_data = new_data;
    if tag.type == .End then break;

    array_add(*payload, tag);
  }

  ret: Tag = ---;
  ret.name = name;
  ret.payload = .{
    type = .Compound,
    as_compound = payload,
  };

  return next_data, ret, true;
}

parse_tag_int_array :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, .Int_Array, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  count := byte_swap_if_necessary(cast(*s32, next_data.data).*);
  next_data.data  += size_of(u32);
  next_data.count -= size_of(u32);

  payload: []s32;
  payload.data  = cast(*s32)next_data.data;
  payload.count = count;

  payload_size := size_of(s32)*count;
  next_data.data  += payload_size;
  next_data.count -= payload_size;

  ret: Tag = ---;
  ret.name = name;
  ret.payload = .{
    type = .Int_Array,
    as_int_array = payload,
  };

  return next_data, ret, true;
}

parse_tag_long_array :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  name: string = ---;
  next_data := data;

  if is_named {
    data1, tag_name, success := parse_tag_header(data, .Long_Array, is_named);
    if !success then return .{}, .{}, false;

    name = tag_name;
    next_data = data1;
  }

  count := byte_swap_if_necessary(cast(*s32, next_data.data).*);
  next_data.data  += size_of(u32);
  next_data.count -= size_of(u32);

  payload: []s64;
  payload.data = cast(*s64)next_data.data;
  payload.count = count;

  payload_size := size_of(s64)*count;
  next_data.data  += payload_size;
  next_data.count -= payload_size;

  ret: Tag = ---;
  ret.name = name;
  ret.payload = .{
    type = .Long_Array,
    as_long_array = payload,
  };

  return next_data, ret, true;
}
