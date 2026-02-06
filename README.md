> [!WARNING]
> I cannot guarantee that this program will not brick you NBT files, as it
> wasn't yet tested thoroughly. Please backup your files beforehand if you wish
> to use it.

# NBTex
Crossplatform (Linux, Windows and hopefully Mac) NBT file explorer/editor
written in nameless programming language.

Currently only supports gzip'ed NBT files and uncompressed NBT files. So no
SNBT for now (feel free to PR tho).

# Building
It has no external dependencies apart from the Jai programming language.
```shell
$ jai.exe nbtex.jai
```

# Usage
You can either pass the files as command line arguments or drag'n'drop them
into the program after launching.

```shell
$ nbtex --help
USAGE: nbtex [options] [files]

OPTIONS:
  --help     Print this message
```

# Linux: Display protocol
It only supports X11 because that's what Jai's standard library supports. And
if you're a Wayland user you probably already have XWayland set up in some way,
so it's fine. Just beware that not all Wayland compositors support
drag'n'dropping stuff into XWayland windows.

# Licenses
NBTex is redistributed under MIT license. See [LICENSE.txt](./LICENSE.txt).

Inter font is redistributed under SIL Open Font License 1.1. See
[FONT_LICENSE.txt](./FONT_LICENSE.txt) for a copy of the SIL license.
