# VLPause - intermission for VLC

![VLPause](./assets/VLPause.webp)

Automatically pause what you are watching halfway through play.

## Description

This Lua extension for VLC allows the currently playing video to automatically pause midway through, with a `-- INTERMISSION --` message on screen.

## Installation

Copy the [VLPause_ext.lua](./src/VLPause_ext.lua) and [VLPause_intf.lua](./src/VLPause_intf.lua) files to the following folders (depends on your OS) :

* `VLPause_ext.lua` (installation directory `lua/extensions`)
  * Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
  * Windows (current user): %APPDATA%\VLC\lua\extensions\
  * Linux (all users): /usr/lib/vlc/lua/extensions/
  * Linux (current user): ~/.local/share/vlc/lua/extensions/
  * Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
  * Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
* `VLPause_intf.lua` (instalation directory `lua/intf`)
  * Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
  * Windows (current user): %APPDATA%\VLC\lua\intf\
  * Linux (all users): /usr/lib/vlc/lua/intf/
  * Linux (current user): ~/.local/share/vlc/lua/intf/
  * Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
  * Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/

NOTE: Create directories if they do not exist!

Or, take the zip file in the release assets and unzip into the Lua directory.

## Acknowledgements

* https://vlc.verg.ca/
* https://github.com/GDoux/Perroquet-Subtitles-for-VLC
* [Lua reference manual](https://www.lua.org/manual/5.4/contents.html#contents)
* [Programming in Lua (first edition)](https://www.lua.org/pil/contents.html)
* [Time v3.2](https://addons.videolan.org/p/1154032/) (c) lubozle
* lua-users wiki - [String Recipies](http://lua-users.org/wiki/StringRecipes)
* [Big Buck Bunny](https://www.bigbuckbunny.org) (c) copyright 2008, Blender Foundation / www.bigbuckbunny.org
