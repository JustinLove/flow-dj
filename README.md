# Flow DJ

A Stepmania 5 theme mod which replaces music selection with an auto song picker.

## Features

- Selects steps by player score, with warm-up/cool-down and random variations.
- Estimates scores for unplayed steps.
- Prefers songs by inverse play count to maximize variety.

## Limits

Most limits up for discussion if there is sufficient interest. This is built around the way I play and there are probably a lot of issues I have never run into.

- Single player only.
- Stacks on `default` theme only, unlikely to work on all other themes.
- Development started on Stepmania 5.0, and is now on Stepmania 5.1. It should still work with 5.0 and the old default (now legacy) theme, but I'm not running it regularly.
- No means to filter songs. There is currently a hard-coded exclusion of a song group named `Muted` (which I use for songs muted by Twitch)
- Score estimation assumes a single player set the high scores. However you can still request songs based on any target score, even if you wont't get that score yourself.
- I play in event mode, and have not tested other modes.
- I play FailOff; providing scores, even bad ones, will help improve the model for estimating scores.
- Runs for a set (but easily configurable) number of songs.
- Always pauses on pick screen (time on this screen is also used to improve the estimated score model.)

## Usage

Functionally a theme since that is the only extension mechanism available, Flow-DJ uses the fallback mechanism on the default theme. Install in your Themes folder and select it as the active theme.

The select music screen is effectively replaced with a screen that performs the picks and shows the current queue. The initial view will be a report on the model for estimating scores. It will switch to the normal screen when the model has improved a bit.

### Main screen

- Top left: current options
- Top center: Stage number
- Upper left: Song title image
- Lower Left: Score distribution graph, this is intended to show where the next song sits within your overall range of scores.
- Center/Right: song list each item has:
  - Grey box: score selection range
  - White mark: actual high score
  - Blue mark: estimated score
  - First line: meter, song name, song group
  - Second line: notes-per-second, song artist, steps author


#### Controls

- START starts the song.
- BACK exists to the title screen.
- SELECT Cycles control modes for the arrow buttons. A short help line is shown on the bottom of the screen, long description follows:

#### Default Controls

- LEFT/RIGHT adjust the target score used to select songs. One confusing thing is there are only two score numbers: the start/end target used for warm-up/cool-down, and main target. Adjustments will be made to those numbers based on how they influence the current item.
- UP Enables you to go to the standard select music screen to manually pick a song. The song will receive the highest priority for use in the flow, but must still match the score selection conditions.
- DOWN allows you to review the last song's score screen. It is skipped by default.

#### Alt Controls 1

- LEFT/RIGHT adjust the amount of wiggle or variation in the target scores.
- UP/DOWN adjust the number of stages.

#### Alt Controls 2

- LEFT toggles playing the music sample from the current song
- UP toggles the view to the model display

### Model Screen

The model is a linear regression the basic stats and groove-radar values available about each set of steps.

The left side shows the relative size of the weights for each factor.

Right shows a plot of the actual versus estimated scores. A perfect model would be a flat diagonal line. Below the plot, the overall model error is shown.

## Bootstrapping

The model for estimating scores relies on high scores. If there are no scores on the current profile (or machine profile if no profile is selected), there is a bootstrapping mode that runs successively higher meters until a sufficiently low score is seen. However, you may wish to simply play a selection of songs in normal play mode to provide startup data.

## Credits

The code was made with reference both to Stepmania code, and the Consensual theme in particular. It incorporates pieces of code from both upstream Stepmania (MIT) and Consensual (BSD 3-Clause), especially around saving settings.
