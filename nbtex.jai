main :: () {
  init();

  while !quit {
    dt := get_delta_time();

    update_and_process_events();
    render_frame(dt);

    reset_temporary_storage();
    sleep_milliseconds(16);
  }
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
#load "gui.jai";
