
ctrl+F2 to reload scripts
F3 - debug overlay
SCREENMAN:SystemMessage("")
Trace("")
lua.ReportScriptError("")
rec_print_table()

https://dguzek.github.io/Lua-For-SM5/

consensual has persistent mods

- usable screens
  - graph - score vs nps?
  - player feedback?
  - playing a song affects position in play count weighting
- config?
- profiles?
  - what happens with no data?
  - multiple players?
- more selection factors ?
- actual score reaction ?

## Solved

Branch in scripts controls most transitions
Can overwrite members of Branch
Can overwrite global functions
Gamecommands do not see my custom functions and overrides
Gamecommand setenv does not seem to work
Global variables defined in Scripts will persist, variables in BGAanimations will not
No apparant way to add new PlayMode

ScreenSelectPlayMode has screen transitions in each option
ScreenSelectPlayMode acccepts custom options
ScreenSelectPlayMode needs additional config for highlight graphics - see error messages
SelectMusicOrCourse - entry point when returning
drunken uses a extra pick screen to do selection logic, probably needed for select play mode transitions to skip select music

Button text at bottom of screen is HelpText in language files for that screen

Some objects are not available at actor init, must wait until oncommand
