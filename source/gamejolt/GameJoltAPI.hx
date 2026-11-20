package gamejolt;

import flixel.FlxG;
import flixel.util.FlxTimer;
import haxe.Json;
import haxe.crypto.Md5;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.SecurityErrorEvent;
import openfl.geom.Matrix;
import openfl.net.URLLoader;
import openfl.net.URLRequest;

using StringTools;

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

typedef TrophyRow =
{
	var name:String;
	var unlocked:Bool;
	var order:Int;
}

class GameJoltAPI
{
	static inline var PING_EVERY_MS:Int = 30000;
	static inline var REQUEST_TIMEOUT:Float = 15;
	static inline var API_URL:String = "https://api.gamejolt.com/api/game/v1_2/";

	static var userLogin:Bool = false;
	static var connected:Bool = false;
	static var lastPing:Int = 0;

	public static var leaderboardToggle:Bool = true;
	public static var syncing(default, null):Bool = false;

	public static var onStatusChanged:Void->Void = null;
	public static var onSynced:Void->Void = null;
	public static var onAvatarLoaded:Void->Void = null;

	public static var avatarBitmap(default, null):BitmapData = null;
	public static var trophyIcons(default, null):Map<Int, BitmapData> = new Map();

	public static function getStatus():Bool
		return userLogin;

	public static function getUserInfo(username:Bool = true):String
		return username ? FlxGameJolt.username : FlxGameJolt.usertoken;

	public static function hasKeys():Bool
		return GameJoltKeys.id != 0 && GameJoltKeys.key != null && GameJoltKeys.key != "";

	public static function prettySongName(name:String):String
	{
		if (name == null)
			return "";

		var words:Array<String> = name.replace("-", " ").split(" ");
		var out:Array<String> = [];

		for (w in words)
		{
			w = w.trim();
			if (w == "")
				continue;
			out.push(w.charAt(0).toUpperCase() + w.substr(1));
		}

		return out.join(" ");
	}

	public static function init():Void
	{
		leaderboardToggle = (FlxG.save.data.gjLeaderboard != null) ? (FlxG.save.data.gjLeaderboard == true) : true;

		if (!hasKeys())
		{
			trace('[GameJolt] GameJoltKeys.hx is empty, GameJolt is disabled.');
			return;
		}
		connect();

		var user:String = FlxG.save.data.gjUser;
		var token:String = FlxG.save.data.gjToken;
		if (user != null && token != null && user != "" && token != "")
			login(user, token, null, true);
	}

	static function connect():Void
	{
		if (connected || !hasKeys())
			return;
		connected = true;
		FlxGameJolt.init(GameJoltKeys.id, GameJoltKeys.key, function(_:Bool) {});
	}

	public static function toast(title:String, ?description:String = "", ?kind:Int = GameJoltToastManager.INFO, ?sound:Bool = false, ?icon:BitmapData):Void
	{
		if (Main.gjToastManager != null)
			Main.gjToastManager.createToast(title, description, kind, sound, icon);
	}

	static var queue:Array<(Void->Void)->Void> = [];
	static var running:Bool = false;

	static function enqueue(job:(Void->Void)->Void):Void
	{
		queue.push(job);
		runNext();
	}

	static function runNext():Void
	{
		if (running || queue.length == 0)
			return;

		running = true;
		var job = queue.shift();
		var finished:Bool = false;
		var timeout:FlxTimer = null;

		var done = function()
		{
			if (finished)
				return;
			finished = true;
			if (timeout != null)
				timeout.cancel();
			running = false;
			runNext();
		};

		timeout = new FlxTimer().start(REQUEST_TIMEOUT, function(_)
		{
			trace('[GameJolt] request timed out');
			done();
		});

		try
		{
			job(done);
		}
		catch (e:Dynamic)
		{
			trace('[GameJolt] request error: $e');
			done();
		}
	}

	static function apiGet(endpoint:String, params:String, cb:Dynamic->Void):Void
	{
		var url:String = API_URL + endpoint + '?game_id=' + GameJoltKeys.id + '&' + params + '&format=json';
		url += '&signature=' + Md5.encode(url + GameJoltKeys.key);

		var loader:URLLoader = new URLLoader();
		var finished:Bool = false;

		var finish = function(result:Dynamic)
		{
			if (finished)
				return;
			finished = true;
			cb(result);
		};

		loader.addEventListener(Event.COMPLETE, function(_)
		{
			var result:Dynamic = null;
			try
			{
				var json:Dynamic = Json.parse(Std.string(loader.data));
				if (json != null && json.response != null && Std.string(json.response.success) == "true")
					result = json.response;
			}
			catch (e:Dynamic)
			{
				trace('[GameJolt] bad response: $e');
			}
			finish(result);
		});
		loader.addEventListener(IOErrorEvent.IO_ERROR, function(_) finish(null));
		loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(_) finish(null));

		try
		{
			loader.load(new URLRequest(url));
		}
		catch (e:Dynamic)
		{
			finish(null);
		}
	}

	static function loadImage(url:String, cb:BitmapData->Void):Void
	{
		if (url == null || url == "")
		{
			cb(null);
			return;
		}

		try
		{
			BitmapData.loadFromFile(url).onComplete(function(bd:BitmapData) cb(bd)).onError(function(_) cb(null));
		}
		catch (e:Dynamic)
		{
			cb(null);
		}
	}

	public static function circleBitmap(src:BitmapData, size:Int):BitmapData
	{
		var out:BitmapData = new BitmapData(size, size, true, 0x00000000);
		var shape:Shape = new Shape();
		var m:Matrix = new Matrix();
		m.scale(size / src.width, size / src.height);
		shape.graphics.beginBitmapFill(src, m, false, true);
		shape.graphics.drawCircle(size / 2, size / 2, size / 2);
		shape.graphics.endFill();
		out.draw(shape, null, null, null, null, true);
		return out;
	}

	static function loadProfile(user:String, ?cb:Void->Void):Void
	{
		var fired:Bool = false;
		var finish = function()
		{
			if (fired)
				return;
			fired = true;
			if (cb != null)
				cb();
		};

		new FlxTimer().start(5, function(_) finish());

		apiGet('users/', 'username=' + user.urlEncode(), function(res:Dynamic)
		{
			if (res == null || res.users == null)
			{
				finish();
				return;
			}

			var users:Array<Dynamic> = res.users;
			if (users.length == 0)
			{
				finish();
				return;
			}

			var url:String = users[0].avatar_url;
			loadImage(url, function(bd:BitmapData)
			{
				if (bd != null && userLogin && FlxGameJolt.username == user)
				{
					avatarBitmap = bd;
					if (onAvatarLoaded != null)
						onAvatarLoaded();
				}
				finish();
			});
		});
	}

	static function loadTrophyIcons(user:String, token:String):Void
	{
		apiGet('trophies/', 'username=' + user.urlEncode() + '&user_token=' + token.urlEncode(), function(res:Dynamic)
		{
			if (res == null || res.trophies == null)
				return;

			var wanted:Array<Int> = [for (v in GameJoltInfo.TROPHIES) v];
			var trophies:Array<Dynamic> = res.trophies;

			for (t in trophies)
			{
				var id:Null<Int> = Std.parseInt(Std.string(t.id));
				if (id == null || wanted.indexOf(id) == -1)
					continue;

				var url:String = t.image_url;
				loadImage(url, function(bd:BitmapData)
				{
					if (bd != null)
						trophyIcons.set(id, bd);
				});
			}
		});
	}

	public static function login(user:String, token:String, ?onDone:Bool->String->Void, auto:Bool = false):Void
	{
		user = (user == null) ? "" : user.trim();
		token = (token == null) ? "" : token.trim();

		if (!hasKeys())
		{
			if (onDone != null)
				onDone(false, "GameJoltKeys.hx has no Game ID / Private Key.");
			return;
		}
		if (user == "" || token == "")
		{
			if (onDone != null)
				onDone(false, "Type your username and your game token.");
			return;
		}

		connect();

		enqueue(function(done)
		{
			FlxGameJolt.resetUser(user, token, function(ok:Bool)
			{
				if (ok)
				{
					userLogin = true;
					FlxG.save.data.gjUser = user;
					FlxG.save.data.gjToken = token;
					FlxG.save.flush();

					loadProfile(user, function()
					{
						toast(auto ? 'Welcome back, $user!' : '$user signed in!',
							'Trophies are now synced with GameJolt.', GameJoltToastManager.SUCCESS, false, avatarBitmap);
					});
					loadTrophyIcons(user, token);

					startSession();
					syncTrophies();
					if (onStatusChanged != null)
						onStatusChanged();
					if (onDone != null)
						onDone(true, null);
				}
				else
				{
					userLogin = false;
					FlxGameJolt.logout();
					if (onDone != null)
						onDone(false, "Invalid username or token, or no internet connection.");
				}
				done();
			});
		});
	}

	public static function logout():Void
	{
		var wasLogged:Bool = userLogin;
		userLogin = false;
		avatarBitmap = null;
		stopPing();

		FlxG.save.data.gjUser = "";
		FlxG.save.data.gjToken = "";
		FlxG.save.flush();

		if (wasLogged)
		{
			enqueue(function(done)
			{
				FlxGameJolt.closeSession(function(_)
				{
					FlxGameJolt.logout();
					done();
				});
			});
			toast('Signed out', 'See you soon!', GameJoltToastManager.INFO);
		}
		else
			FlxGameJolt.logout();

		if (onStatusChanged != null)
			onStatusChanged();
	}

	static function startSession():Void
	{
		enqueue(function(done)
		{
			FlxGameJolt.openSession(function(_)
			{
				lastPing = Lib.getTimer();
				Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onPingFrame);
				Lib.current.stage.addEventListener(Event.ENTER_FRAME, onPingFrame);
				done();
			});
		});
	}

	static function stopPing():Void
	{
		Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onPingFrame);
	}

	static function onPingFrame(_:Event):Void
	{
		if (!userLogin)
		{
			stopPing();
			return;
		}
		if (Lib.getTimer() - lastPing < PING_EVERY_MS)
			return;

		lastPing = Lib.getTimer();
		enqueue(function(done) FlxGameJolt.pingSession(true, function(_) done()));
	}

	public static function onAchievementUnlocked(name:String):Void
	{
		if (!userLogin)
			return;
		var id:Null<Int> = GameJoltInfo.TROPHIES.get(name);
		if (id == null)
			return;

		enqueue(function(done) FlxGameJolt.addTrophy(id, function(data:Map<String, String>)
		{
			trace('[GameJolt] trophy $name -> ${data.get("success")}');

			if (data.get("success") == "true")
			{
				var title:String = name;
				#if ACHIEVEMENTS_ALLOWED
				var a = Achievements.get(name);
				if (a != null && a.name != null)
					title = a.name;
				#end
				toast('Trophy unlocked!', title, GameJoltToastManager.TROPHY, false, trophyIcons.get(id));
			}
			done();
		}));
	}

	static function isAchieved(data:Map<String, String>):Bool
	{
		if (data == null || data.get("success") != "true")
			return false;
		var a:String = data.get("achieved");
		return a != null && a != "false" && a != "";
	}

	public static function syncTrophies(?onFinish:Int->Int->Void):Void
	{
		#if ACHIEVEMENTS_ALLOWED
		if (!userLogin || syncing)
			return;
		syncing = true;

		var pulled:Int = 0;
		var pushed:Int = 0;
		var names:Array<String> = [for (k in GameJoltInfo.TROPHIES.keys()) k];

		for (name in names)
		{
			if (!Achievements.exists(name))
				continue;
			var id:Int = GameJoltInfo.TROPHIES.get(name);

			enqueue(function(done)
			{
				FlxGameJolt.fetchTrophy(id, function(data:Map<String, String>)
				{
					var remote:Bool = isAchieved(data);
					var local:Bool = Achievements.isUnlocked(name);

					if (remote && !local)
					{
						if (Achievements.unlockSilently(name))
							pulled++;
						done();
					}
					else if (!remote && local && data.get("success") == "true")
					{
						FlxGameJolt.addTrophy(id, function(_)
						{
							pushed++;
							done();
						});
					}
					else
						done();
				});
			});
		}

		enqueue(function(done)
		{
			syncing = false;
			if (pulled > 0 || pushed > 0)
				toast('Trophies synced', 'Downloaded: $pulled   Uploaded: $pushed', GameJoltToastManager.TROPHY);
			if (onFinish != null)
				onFinish(pulled, pushed);
			if (onSynced != null)
				onSynced();
			done();
		});
		#end
	}

	public static function trophyRows():Array<TrophyRow>
	{
		var rows:Array<TrophyRow> = [];
		#if ACHIEVEMENTS_ALLOWED
		for (key in GameJoltInfo.TROPHIES.keys())
		{
			var a = Achievements.get(key);
			if (a == null)
				continue;
			var un:Bool = Achievements.isUnlocked(key);
			rows.push({
				name: (a.hidden == true && !un) ? "???" : a.name,
				unlocked: un,
				order: (a.ID != null) ? a.ID : 999
			});
		}
		rows.sort(function(x, y) return x.order - y.order);
		#end
		return rows;
	}

	public static function submitScore(score:Int, ?extra:String, ?tableID:Int):Void
	{
		if (!userLogin || !leaderboardToggle || score <= 0)
			return;
		if (tableID == null)
			tableID = GameJoltInfo.SCORE_TABLE_ID;

		var extraData:String = (extra == null) ? "" : extra.urlEncode();
		var labelText:String = '$score Points';
		if (extra != null && extra != "")
			labelText += ' | $extra';
		var label:String = labelText.urlEncode();

		enqueue(function(done) FlxGameJolt.addScore(label, score, tableID, false, null, extraData, function(data:Map<String, String>)
		{
			if (data.get("success") == "true")
				toast('Score submitted!', 'Score: $score' + (extra != null ? '\n$extra' : ''), GameJoltToastManager.SUCCESS);
			else
				toast('Score not submitted', 'GameJolt did not accept it. Are you online?', GameJoltToastManager.ERROR);
			done();
		}));
	}

	public static function setLeaderboardToggle(value:Bool):Void
	{
		leaderboardToggle = value;
		FlxG.save.data.gjLeaderboard = value;
		FlxG.save.flush();
	}
}