![GameJoltAPIBanner](docs/img/banner.svg)

Game Jolt integration for [Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine). Players sign in from the options menu, game achievements sync with Game Jolt trophies, scores go to your leaderboard, and everything shows up with on-screen notifications.

This version is a modification by **NickDZ**, built on top of an existing Psych Engine port. See [Credits](#credits) for everyone involved.

## Installation:

1. Copy the `source/gamejolt` folder into the `source` folder of your Psych Engine project.
2. Set your game's keys and trophies (see [Customization](#customization)).
3. Apply the small changes to `Main.hx`, `Achievements.hx`, `OptionsState.hx` and `PlayState.hx` (see [Integration](#integration)).
4. Build with `lime build windows -clean` the first time.

### Compatibility

| Component | Version |
| --- | --- |
| Psych Engine | 1.0.4 (tested) |
| lime | 8.2.x |
| openfl | 9.4.x |
| flixel | 5.9.x |
| flixel-addons | 3.3.x |

Only tested on Psych Engine 1.0.4 on Windows. Other 1.0.x versions should work since they ship the same libraries. Psych Engine 0.7.x and mobile targets were not tested; on 0.7.x you would need to adjust at least `Language.getPhrase` and `ClientPrefs.toggleVolumeKeys`, which are 1.0 features.

It needs `flixel-addons` (for `FlxUIInputText`) and `openfl 9` or newer (for `BitmapData.loadFromFile`). Psych Engine 1.0.x already includes both.

### What's in the folder

```
source/gamejolt/
  FlxGameJolt.hx            Game Jolt API client
  GameJoltAPI.hx            login, trophies, scores, avatar, request queue
  GameJoltLogin.hx          account menu (substate)
  GameJoltToastManager.hx   notifications
  GameJoltInfo.hx           trophies, scoreboard and colors
  GameJoltKeys.hx           Game ID and Private Key
```

## Customization:

### Game Jolt dashboard

Everything below lives in your game's page, under `Game API`:

* **Game ID** and **Private Key**: `API Settings`.
* **Trophies**: create one per achievement and copy each ID. Upload an image to every trophy if you want its icon in the unlock notification.
* **Scoreboard**: use or create a table under `Scores` and copy its ID.

Players sign in with their username and their **Game Token**, not their password. The "How to get my token" button in the menu opens `GameJoltInfo.tokenHelpUrl`.

### GameJoltKeys.hx

```haxe
package gamejolt;

class GameJoltKeys
{
	public static var id:Int = 0;
	public static var key:String = "";
}
```

With `id = 0` or an empty `key` the integration stays disabled and the menu shows a warning. Put your game's values here.

**Do not publish your Private Key.** Anyone who has it can send fake data to your game. If your project is public, add `source/gamejolt/GameJoltKeys.hx` to your `.gitignore`. If it was ever pushed, regenerate the key in the dashboard.

### GameJoltInfo.hx

```haxe
public static final SCORE_TABLE_ID:Int = 0;

public static final TROPHIES:Map<String, Int> = [
	'example_achievement' => 0,
	'another_achievement' => 0
];
```

* `SCORE_TABLE_ID`: table where scores are uploaded.
* `TROPHIES`: the key is the achievement's name in `Achievements.hx` (the first argument of `createAchievement`), the value is the trophy ID on Game Jolt. To connect a new achievement, add a line. Order doesn't matter.
* `ACCENT`: accent color for the menus and notifications.
* `tokenHelpUrl`: page opened by the "How to get my token" button. Change it if you have your own tutorial.

## Integration:

### Main.hx

Imports and the static variable:

```haxe
import gamejolt.GameJoltAPI;
import gamejolt.GameJoltToastManager;

public static var gjToastManager:GameJoltToastManager;
```

Right after the `FlxGame` is created. `FlxG.save` must already be bound, and the `addChild` goes after the game so notifications stay on top:

```haxe
addChild(new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

gjToastManager = new GameJoltToastManager();
addChild(gjToastManager);
GameJoltAPI.init();
```

### Achievements.hx

Inside `unlock`, after saving and before the popup:

```haxe
Achievements.save();
FlxG.save.flush();

gamejolt.GameJoltAPI.onAchievementUnlocked(name);

if(autoStartPopup) startPopup(name);
return name;
```

And a new function, used by the sync to mark achievements without sound or popup:

```haxe
public static function unlockSilently(name:String):Bool
{
	if(!achievements.exists(name) || isUnlocked(name)) return false;

	achievementsUnlocked.push(name);
	Achievements.save();
	FlxG.save.flush();
	return true;
}
```

The API relies on `Achievements.get`, `Achievements.exists`, `Achievements.isUnlocked` and the `name`, `hidden` and `ID` fields of an achievement. All of them exist in Psych Engine 1.0.x. Achievements marked as `hidden` show as `???` in the menu until they're unlocked.

### OptionsState.hx

Add the entry to the list:

```haxe
var options:Array<String> = [
	'Note Colors',
	'Controls',
	'Adjust Delay and Combo',
	'Graphics',
	'Visuals',
	'Gameplay',
	'GameJolt'
	#if TRANSLATIONS_ALLOWED , 'Language' #end
];
```

And the case in `openSelectedSubstate`:

```haxe
case 'GameJolt':
	openSubState(new gamejolt.GameJoltLogin());
```

If your `OptionsState` camera follows an object, reset it before opening the menu and restore it when the menu closes. Otherwise the background can shift:

```haxe
FlxG.camera.target = null;
FlxG.camera.scroll.set(0, 0);
```

The menu can be opened from anywhere else too, for example the pause menu, with `openSubState(new gamejolt.GameJoltLogin())`.

### PlayState.hx

In `endSong()`, right after `Highscore.saveScore(...)`:

```haxe
#if !switch
var percent:Float = ratingPercent;
if (Math.isNaN(percent))
	percent = 0;
Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);

if (!chartingMode && !cpuControlled && !practiceMode)
	gamejolt.GameJoltAPI.submitScore(songScore, gamejolt.GameJoltAPI.prettySongName(Song.loadedSongName) + ' | ' + Difficulty.getString() + ' | ' + (Math.floor(percent * 10000) / 100) + '%');
#end
```

On Game Jolt the score reads like this: `12345 Points | Dad Battle | Hard | 98.5%`. `prettySongName` replaces dashes with spaces and capitalizes every word. Nothing is uploaded if the player isn't signed in, turned score uploads off, the score is 0, or cheats are on.

## Usage:

```haxe
import gamejolt.GameJoltAPI;
import gamejolt.GameJoltToastManager;

GameJoltAPI.getStatus();
GameJoltAPI.getUserInfo(true);
GameJoltAPI.login(user, token, function(ok:Bool, msg:String) {});
GameJoltAPI.logout();
GameJoltAPI.syncTrophies();
GameJoltAPI.submitScore(score, "extra text");
GameJoltAPI.submitScore(score, "extra text", otherTableID);
GameJoltAPI.setLeaderboardToggle(false);
GameJoltAPI.toast("Title", "Description", GameJoltToastManager.SUCCESS);
```

| Function | What it does |
| --- | --- |
| `init()` | Called once from `Main`. Signs in with the saved account, if any |
| `getStatus()` | `true` if someone is signed in |
| `getUserInfo(true)` | Username of the session. With `false`, the token |
| `login(user, token, cb)` | Signs in. The callback gets `(ok, errorMessage)` |
| `logout()` | Signs out without closing the game |
| `syncTrophies(cb)` | Syncs trophies. The callback gets `(downloaded, uploaded)` |
| `submitScore(score, extra, table)` | Uploads a score. `extra` and `table` are optional |
| `setLeaderboardToggle(bool)` | Turns score uploads on or off and saves the choice |
| `toast(...)` | Shows a notification |
| `prettySongName(name)` | Formats a song name |

Toast types are `INFO`, `SUCCESS`, `ERROR` and `TROPHY`. `toast` takes an optional `BitmapData` as its last argument to show an image instead of the default icon.

To upload scores from other game modes, call `submitScore` where each mode ends and pass the matching table ID.

To unlock a trophy from a Lua script, use Psych Engine's own `unlockAchievement` callback. It goes through `Achievements.unlock`, so it reaches Game Jolt as well.

### Coming from the original version

The calls changed. The old ones map like this:

| Original | This version |
| --- | --- |
| `GameJoltAPI.connect()` + `authDaUser(user, token)` | `GameJoltAPI.init()` in `Main`, nothing in `TitleState` |
| `GameJoltAPI.getTrophy(id)` | Automatic through `Achievements.unlock` and the `TROPHIES` map |
| `GameJoltAPI.addScore(score, table, extra)` | `GameJoltAPI.submitScore(score, extra, table)` |
| `GameJoltAPI.checkTrophy`, `pullTrophy`, `pullHighScore` | Removed. `FlxGameJolt` still has the raw calls if you need them |
| `ClientPrefs.loadPrefs` changes | Not needed. The account is stored directly in `FlxG.save` |
| `GameJoltInfo.font`, `fontPath`, `imagePath` | Removed |

## How it works:

* On startup, `GameJoltAPI.init()` reads the saved account from `FlxG.save` and signs in by itself. If there is no account or the keys are missing, it does nothing.
* On sign in, a game session is opened on Game Jolt and pinged every 30 seconds while the game is running. Trophies are synced and the avatar and trophy icons are downloaded.
* `FlxGameJolt` has a single shared callback, so two simultaneous requests used to overwrite each other. Its requests now go through a queue, one at a time, with a 15 second timeout each. The avatar and icon requests are separate and signed with your Private Key.
* The account is stored in `FlxG.save.data.gjUser` and `gjToken`. The score upload toggle is stored in `gjLeaderboard`.

### Known limitations

* GIF avatars can't be read. The menu shows the user's initial instead.
* The trophy icon only shows up if the trophy has an image on Game Jolt. Otherwise a star is used.
* Achievements unlocked while offline or signed out are uploaded on the next sync.
* Game Jolt doesn't show the "extra data" of a score on the public table, so the song info is written into the score text.

### Troubleshooting

* **The button doesn't show up in options:** build with `lime build windows -clean` and make sure `OptionsState.hx` has `'GameJolt'` in the list.
* **The menu says `GameJoltKeys.hx` is empty:** the Game ID or the Private Key is missing.
* **"Invalid username or token":** use the Game Token, not the password, and check your connection.
* **No avatar or icons:** check the Private Key. Those requests are signed with it.

## Credits:
* NickDZ - This version: request queue, account menu, avatar, trophy icons, notifications, score formatting.
* [Saw (M.A. Jigsaw)](https://github.com/jigsaw-4277821) - Redoing the code and adding multi-platform support in the previous version.
* [TentaRJ](https://github.com/TentaRJ) - Original repo and code.

### Special Thanks
* [BrightFyre](https://github.com/brightfyregit) - Testing and UI design on the original project.
* [Haya](https://github.com/haya3218) - Systools fork.
* [Firubii](https://github.com/firubii) - Toast system the notifications are based on.
* SumYungGai and Steve Richey (STVR) - Original `FlxGameJolt` from Flixel-Addons.

`FlxGameJolt.hx` keeps its original header and authors. Check the Flixel-Addons license before redistributing it.

***

# Features

## Account menu
* Sign in with username and Game Token from `Options > GameJolt`.
* The account is saved and the game signs in automatically on the next launch.
* Shows the player's avatar, the trophy list with its unlocked state, and buttons to sync, toggle score uploads and sign out.
* Paste button, show/hide for the token, and Tab/Enter support.

## Trophies
* Two-way sync between game achievements and Game Jolt trophies:
  * Trophies you already have on Game Jolt are marked as unlocked in the game, with no popup.
  * Achievements you have in the game and not on Game Jolt are uploaded.
* Trophies unlock in real time when an achievement is earned while signed in.
* The unlock notification shows the trophy's icon.

## Scores
* Scores upload when a song ends, with song name, difficulty and accuracy in the score text.
* Players can turn uploads off from the menu.
* Skipped automatically in charting mode, botplay and practice mode.

## Notifications
* Info, success, error and trophy cards in the top right corner.
* They live on the OpenFL stage, so they survive state changes.

## Session
* The player shows as online on Game Jolt while the game is open.

#### Game Jolt integration by NickDZ, based on the work of TentaRJ and M.A. Jigsaw. Psych Engine by ShadowMario.
