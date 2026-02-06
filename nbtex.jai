main :: () {
  files_via_command_line := get_files_from_command_line_arguments();

  // this function will exit() the program if it can't open the files
  init(files_via_command_line);

  while !quit {
    dt := get_delta_time();

    update_and_process_events();
    render_frame(dt);

    reset_temporary_storage();
    sleep_milliseconds(16);
  }
}

get_files_from_command_line_arguments :: () -> []string {
  args := get_command_line_arguments();

  usage :: #string END
USAGE: nbtex [options] [files]

OPTIONS:
  --help     Print this message
END;

  if args.count == 1 {
    return .{};
  }

  if args[1] == "--help" {
    print(usage, to_standard_error = true);
    exit(0);
  }

  return array_view(args, 1);
}

#import "Basic";
#import "Bit_Operations";

#load "file.jai";
#load "parser.jai";
#load "gui.jai";
