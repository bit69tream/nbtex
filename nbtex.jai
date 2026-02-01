Tag_Type :: enum u8 {
  // TYPE: 0  NAME: TAG_End
  // Payload: None.
  // Note:    This tag is used to mark the end of a list.
  //          Cannot be named! If type 0 appears where a Named Tag is expected, the name is assumed to be "".
  //          (In other words, this Tag is always just a single 0 byte when named, and nothing in all other cases)
  End :: 0;
  // TYPE: 1  NAME: TAG_Byte
  // Payload: A single signed byte (8 bits)
  Byte :: 1;
  // TYPE: 2  NAME: TAG_Short
  // Payload: A signed short (16 bits, big endian)
  Short :: 2;
  // TYPE: 3  NAME: TAG_Int
  // Payload: A signed short (32 bits, big endian)
  Int :: 3;
  // TYPE: 4  NAME: TAG_Long
  // Payload: A signed long (64 bits, big endian)
  Long :: 4;
  // TYPE: 5  NAME: TAG_Float
  // Payload: A floating point value (32 bits, big endian, IEEE 754-2008, binary32)
  Float :: 5;
  // TYPE: 6  NAME: TAG_Double
  // Payload: A floating point value (64 bits, big endian, IEEE 754-2008, binary64)
  Double :: 6;
  // TYPE: 7  NAME: TAG_Byte_Array
  // Payload: TAG_Int length
  //          An array of bytes of unspecified format. The length of this array is <length> bytes
  Byte_Array :: 7;
  // TYPE: 8  NAME: TAG_String
  // Payload: TAG_Short length
  //          An array of bytes defining a string in UTF-8 format. The length of this array is <length> bytes
  String :: 8;
  // TYPE: 9  NAME: TAG_List
  // Payload: TAG_Byte tagId
  //          TAG_Int length
  //          A sequential list of Tags (not Named Tags), of type <typeId>. The length of this array is <length> Tags
  // Notes:   All tags share the same type.
  List :: 9;
  // TYPE: 10 NAME: TAG_Compound
  // Payload: A sequential list of Named Tags. This array keeps going until a TAG_End is found.
  //          TAG_End end
  // Notes:   If there's a nested TAG_Compound within this tag, that one will also have a TAG_End, so simply reading until the next TAG_End will not work.
  //          The names of the named tags have to be unique within each TAG_Compound
  //          The order of the tags is not guaranteed.
  Compound :: 10;
}

Tag_Value :: union type: Tag_Type {
  .Byte       ,, as_byte:       u8;
  .Short      ,, as_short:      s16;
  .Int        ,, as_int:        s32;
  .Long       ,, as_long:       s64;
  .Float      ,, as_float:      float32;
  .Double     ,, as_double:     float64;
  .Byte_Array ,, as_byte_array: []u8;
  .String     ,, as_string:     string;
  .List       ,, as_list:       []Tag;
  .Compound   ,, as_compound:   []Tag;
}

Tag :: struct {
  name: string;
  payload: Tag_Value;
}

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
  length: u16 = byte_swap_if_necessary((cast(*u16)data.data).*);

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

parse__primitive_tag :: (data: []u8, is_named: bool = true, $type: Tag_Type) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, name, success := parse_tag_header(data, type, is_named);
  if !success then return .{}, .{}, false;

  #insert -> string {
    String :: #import "String";
    #import "Reflection";

    field: string = sprint("as_%", enum_value_to_name(type));
    String.to_lower_in_place(field);

    return sprint(#string JAI
    payload: Tag_Value;
    payload.type    = type;
    payload.%       = byte_swap_if_necessary((cast(type_of(*payload.%))next_data.data).*);

    ret := Tag.{name, payload};

    next_data.data  += size_of(type_of(payload.%));
    next_data.count -= size_of(type_of(payload.%));
    JAI, field, field, field, field);
  }

  return next_data, ret, true;
}

Tag_Parser :: #type (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool);

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

parse_tag_string ::  (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  next_data, name, success := parse_tag_header(data, .String, is_named);
  if !success then return .{}, .{}, false;

  new_data, payload, succ := parse_string(next_data);
  if !succ then return .{}, .{}, false;

  ret: Tag = ---;
  ret.name = name;
  ret.payload.type = .String;
  ret.payload.as_string = payload;

  return new_data, ret, true;
}

parse_tag :: (data: []u8, is_named: bool = true) -> (next_data: []u8, value: Tag, success: bool) {
  parsers := Tag_Parser.[
    parse_tag_byte,
    parse_tag_short,
    parse_tag_int,
    parse_tag_long,
    parse_tag_float,
    parse_tag_double,
    parse_tag_string,
  ];

  for parsers {
    next_data, value, success := it(data, is_named);
    if success then return next_data, value, true;
  }

  return .{}, .{}, false;
}

main :: () {
  path := "./level.dat";

  data, success := read_nbt_file(path);
  if !success then exit(1);

  print("%\n", data);

  //                    a     m     g     u     s           s     u     s
  mogus := u8.[8, 0, 5, 0x61, 0x6d, 0x67, 0x75, 0x73, 0, 3, 0x73, 0x75, 0x73];
  _, byte, _ := parse_tag(mogus);
  print("% %\n", byte.name, byte.payload.as_string);
}

#import "Basic";
#import "Bit_Operations";

#load "file.jai";
