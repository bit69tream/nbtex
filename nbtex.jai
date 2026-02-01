main :: () {
  path := get_file_from_command_line_arguments();

  data, success := read_nbt_file(path);
  if !success then exit(1);

  print("%\n", data);
  next_data, level, succ := parse_tag(data);
  print("% %\n", succ, level);
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
