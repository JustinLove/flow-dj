
ctrl+F2 to reload scripts
F3 - debug overlay
SCREENMAN:SystemMessage("")
Trace("")
lua.ReportScriptError("")
rec_print_table()

https://dguzek.github.io/Lua-For-SM5/

consensual has persistent mods

No memory of songs played this round, causing repeats

## Solved

Branch in scripts controls most transitions
Can overwrite members of Branch
Can overwrite global functions
Gamecommands do not see my custom functions and overrides
Gamecommand setenv does not seem to work
No apparant way to add new PlayMode

ScreenSelectPlayMode has screen transitions in each option
ScreenSelectPlayMode acccepts custom options
ScreenSelectPlayMode needs additional config for highlight graphics - see error messages
SelectMusicOrCourse - entry point when returning
drunken uses a extra pick screen to do selection logic, probably needed for select play mode transitions to skip select music
