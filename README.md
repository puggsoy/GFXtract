# GFXtract
A script-driven graphic converter/extractor/dumper.

## Current Functionality
Can load and save image files. Can also perform simple manipulation (horizontal and vertical flipping). Various file reading and variable manipulation commands.

## Things to add next
* Loops
* File-related datatypes such as filename, size, basename, etc
* More image manipulation (in particular copying parts of images to stitch them together)
* Binary in strings ('\x' notation)
* Tiled image reading

## Compiling
This should be compiled as a Neko or C++ command-line program (i.e. not an OpenFL program). It requires the following libraries:
* [OpenFL](http://www.openfl.org/) (and Lime)
* [format](https://github.com/HaxeFoundation/format)
* [systools](https://github.com/waneck/systools)