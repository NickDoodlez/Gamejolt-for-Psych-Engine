package gamejolt;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUIInputText;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import lime.system.Clipboard;
import backend.ClientPrefs;
import backend.MusicBeatSubstate;
import backend.Paths;
import gamejolt.GameJoltAPI.TrophyRow;

using StringTools;

class GameJoltLogin extends MusicBeatSubstate
{
	static inline var CARD_W:Int = 640;
	static inline var PAD:Int = 32;
	static inline var INNER_W:Int = CARD_W - PAD * 2;
	static inline var MAX_INPUT:Int = 64;

	static final GRAY:FlxColor = 0xFF9A9A9A;
	static final DARK_BTN:FlxColor = 0xFF2B2B2B;
	static final RED:FlxColor = 0xFFFF5A5F;

	var dim:FlxSprite;
	var ui:FlxGroup;

	var userInput:FlxUIInputText;
	var tokenInput:FlxUIInputText;
	var statusTxt:FlxText;
	var signInBtn:GJButton;

	var savedUser:String = "";
	var savedToken:String = "";
	var syncNote:String = "";
	var statusMsg:String = "";
	var statusColor:FlxColor = 0xFF9A9A9A;

	var busy:Bool = false;
	var closed:Bool = false;
	var pendingRebuild:Bool = false;
	var prevMouseVisible:Bool = false;

	override function create()
	{
		super.create();

		prevMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;
		ClientPrefs.toggleVolumeKeys(false);

		dim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		dim.alpha = 0;
		dim.scrollFactor.set();
		add(dim);
		FlxTween.tween(dim, {alpha: 0.88}, 0.25);

		ui = new FlxGroup();
		add(ui);

		GameJoltAPI.onStatusChanged = requestRebuild;
		GameJoltAPI.onSynced = requestRebuild;
		GameJoltAPI.onAvatarLoaded = requestRebuild;

		if (!GameJoltAPI.hasKeys())
		{
			statusMsg = "GameJoltKeys.hx is empty: set your Game ID and Private Key.";
			statusColor = RED;
		}

		rebuild();
	}

	override function destroy()
	{
		closed = true;
		GameJoltAPI.onStatusChanged = null;
		GameJoltAPI.onSynced = null;
		GameJoltAPI.onAvatarLoaded = null;
		FlxG.mouse.visible = prevMouseVisible;
		ClientPrefs.toggleVolumeKeys(true);
		super.destroy();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (pendingRebuild)
		{
			pendingRebuild = false;
			rebuild();
			return;
		}

		sanitizeInput(userInput);
		sanitizeInput(tokenInput);

		var typing:Bool = userInput != null && (userInput.hasFocus || tokenInput.hasFocus);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (typing)
			{
				userInput.hasFocus = false;
				tokenInput.hasFocus = false;
			}
			else
				closeMenu();
			return;
		}

		if (userInput != null && !busy)
		{
			if (FlxG.keys.justPressed.TAB)
			{
				var toToken:Bool = userInput.hasFocus;
				userInput.hasFocus = !toToken;
				tokenInput.hasFocus = toToken;
			}
			if (FlxG.keys.justPressed.ENTER)
				submit();
		}
	}

	function sanitizeInput(input:FlxUIInputText):Void
	{
		if (input == null)
			return;

		var current:String = input.text;
		var clean:String = current.replace("\r", "").replace("\n", "").replace("\t", "");
		if (clean.length > MAX_INPUT)
			clean = clean.substr(0, MAX_INPUT);

		if (clean != current)
		{
			input.text = clean;
			input.caretIndex = clean.length;
		}
	}

	function closeMenu():Void
	{
		if (closed)
			return;
		closed = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		close();
	}

	function requestRebuild():Void
	{
		if (!closed)
			pendingRebuild = true;
	}

	function rounded(w:Int, h:Int, radius:Int, color:FlxColor):FlxSprite
	{
		var s:FlxSprite = new FlxSprite().makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(s, 0, 0, w, h, radius * 2, radius * 2, color);
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.scrollFactor.set();
		return s;
	}

	function label(x:Float, y:Float, w:Float, str:String, size:Int, color:FlxColor, ?align:FlxTextAlign):FlxText
	{
		if (align == null)
			align = FlxTextAlign.LEFT;
		var t:FlxText = new FlxText(x, y, w, str, size);
		t.setFormat(Paths.font('vcr.ttf'), size, color, align);
		t.antialiasing = ClientPrefs.data.antialiasing;
		t.scrollFactor.set();
		ui.add(t);
		return t;
	}

	function button(x:Float, y:Float, w:Int, h:Int, text:String, color:FlxColor, textColor:FlxColor, cb:Void->Void):GJButton
	{
		var b:GJButton = new GJButton(x, y, w, h, text, color, textColor, cb);
		ui.add(b);
		return b;
	}

	function clearUI():Void
	{
		if (userInput != null)
		{
			savedUser = userInput.text;
			savedToken = tokenInput.text;
		}
		for (m in ui.members)
			if (m != null)
				m.destroy();
		ui.clear();
		userInput = null;
		tokenInput = null;
		signInBtn = null;
		statusTxt = null;
	}

	function buildCard(cardH:Int):{x:Float, y:Float}
	{
		var cx:Float = (FlxG.width - CARD_W) / 2;
		var cy:Float = Math.max(12, (FlxG.height - cardH) / 2);

		var shadow:FlxSprite = rounded(CARD_W + 24, cardH + 24, 34, 0x55000000);
		shadow.setPosition(cx - 12, cy - 4);
		ui.add(shadow);

		var card:FlxSprite = rounded(CARD_W, cardH, 26, 0xFF141414);
		card.setPosition(cx, cy);
		ui.add(card);

		var strip:FlxSprite = rounded(CARD_W - 120, 4, 2, GameJoltInfo.ACCENT);
		strip.setPosition(cx + 60, cy);
		ui.add(strip);

		var pill:FlxSprite = rounded(124, 28, 14, GameJoltInfo.ACCENT);
		pill.setPosition(cx + PAD, cy + 30);
		ui.add(pill);
		label(cx + PAD, cy + 34, 124, "GAME JOLT", 18, 0xFF111111, FlxTextAlign.CENTER);

		return {x: cx, y: cy};
	}

	function createInput(x:Float, y:Float, w:Int, text:String, password:Bool):FlxUIInputText
	{
		var input:FlxUIInputText = new FlxUIInputText(x, y, w, text, 22, FlxColor.WHITE, FlxColor.TRANSPARENT);
		input.fieldBorderThickness = 0;
		input.caretColor = GameJoltInfo.ACCENT;
		input.passwordMode = password;
		input.maxLength = MAX_INPUT;
		input.wordWrap = false;
		ui.add(input);
		return input;
	}

	function makeInput(x:Float, y:Float, w:Int, rightReserve:Int, text:String, password:Bool):FlxUIInputText
	{
		var bg:FlxSprite = rounded(w, 46, 12, 0xFF262626);
		bg.setPosition(x, y);
		ui.add(bg);

		var input:FlxUIInputText = createInput(x + 14, y + 8, w - 28 - rightReserve, text, password);
		input.y = y + (46 - input.height) / 2;
		return input;
	}

	function toggleTokenVisibility():Void
	{
		if (tokenInput == null)
			return;

		var old:FlxUIInputText = tokenInput;
		var oldText:String = old.text;
		var hide:Bool = !old.passwordMode;
		var hadFocus:Bool = old.hasFocus;
		var ox:Float = old.x;
		var oy:Float = old.y;
		var ow:Int = Std.int(old.width);

		ui.remove(old, true);
		old.destroy();

		tokenInput = createInput(ox, oy, ow, oldText, hide);
		tokenInput.y = oy;
		tokenInput.caretIndex = oldText.length;
		tokenInput.hasFocus = hadFocus;
	}

	function setStatus(msg:String, color:FlxColor):Void
	{
		statusMsg = msg;
		statusColor = color;
		if (statusTxt != null)
		{
			statusTxt.text = msg;
			statusTxt.color = color;
		}
	}

	function rebuild():Void
	{
		clearUI();
		if (GameJoltAPI.getStatus())
			buildLoggedIn();
		else
			buildLoggedOut();
	}

	function buildLoggedOut():Void
	{
		var c = buildCard(500);
		var x:Float = c.x + PAD;
		var y:Float = c.y;

		label(x, y + 68, INNER_W, "Sign in", 44, FlxColor.WHITE);
		label(x, y + 122, INNER_W, "Sync your trophies and send your scores to the leaderboard.", 18, GRAY);

		label(x, y + 178, INNER_W, "Username", 16, GRAY);
		userInput = makeInput(x, y + 200, INNER_W, 0, savedUser, false);

		label(x, y + 262, INNER_W, "Game token", 16, GRAY);
		tokenInput = makeInput(x, y + 284, INNER_W, 150, savedToken, true);

		var showBtn:GJButton = null;
		showBtn = button(x + INNER_W - 70, y + 290, 62, 34, "Show", DARK_BTN, FlxColor.WHITE, function()
		{
			toggleTokenVisibility();
			showBtn.setText(tokenInput.passwordMode ? "Show" : "Hide");
		});
		button(x + INNER_W - 140, y + 290, 62, 34, "Paste", DARK_BTN, FlxColor.WHITE, function()
		{
			var clip:String = Clipboard.text;
			if (clip != null && clip.trim() != "")
			{
				var clean:String = clip.replace("\r", "").replace("\n", "").replace("\t", "").trim();
				if (clean.length > MAX_INPUT)
					clean = clean.substr(0, MAX_INPUT);
				tokenInput.text = clean;
				tokenInput.caretIndex = clean.length;
			}
		});

		label(x, y + 340, INNER_W, "Use your Game Jolt Game Token, NOT your password.", 14, GRAY);

		statusTxt = label(x, y + 372, INNER_W, statusMsg, 18, statusColor);

		var by:Float = y + 416;
		signInBtn = button(x, by, 200, 48, "Sign in", GameJoltInfo.ACCENT, 0xFF111111, submit);
		button(x + 218, by, 230, 48, "How to get my token", DARK_BTN, FlxColor.WHITE, function() FlxG.openURL(GameJoltInfo.tokenHelpUrl));
		button(x + 466, by, 110, 48, "Back", DARK_BTN, FlxColor.WHITE, closeMenu);

		if (!GameJoltAPI.hasKeys())
			signInBtn.setEnabled(false);
		else if (savedUser == "")
			userInput.hasFocus = true;
	}

	function buildLoggedIn():Void
	{
		var rows:Array<TrophyRow> = GameJoltAPI.trophyRows();
		var rowCount:Int = Std.int(Math.max(1, rows.length));
		var panelH:Int = 20 + rowCount * 28;

		var panelTop:Int = 236;
		var row1:Int = panelTop + panelH + 22;
		var row2:Int = row1 + 48 + 14;
		var cardH:Int = row2 + 48 + 32;

		var c = buildCard(cardH);
		var x:Float = c.x + PAD;
		var y:Float = c.y;

		var user:String = GameJoltAPI.getUserInfo(true);
		var avatar:FlxSprite = new FlxSprite(x, y + 82);
		var hasAvatar:Bool = false;

		if (GameJoltAPI.avatarBitmap != null)
		{
			try
			{
				avatar.loadGraphic(GameJoltAPI.circleBitmap(GameJoltAPI.avatarBitmap, 76), false, 0, 0, true);
				hasAvatar = true;
			}
			catch (e:Dynamic)
			{
				hasAvatar = false;
			}
		}

		if (!hasAvatar)
		{
			avatar.makeGraphic(76, 76, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawCircle(avatar, 38, 38, 38, GameJoltInfo.ACCENT);
		}

		avatar.antialiasing = ClientPrefs.data.antialiasing;
		avatar.scrollFactor.set();
		ui.add(avatar);

		if (!hasAvatar)
		{
			var initial:String = (user != null && user.length > 0) ? user.charAt(0).toUpperCase() : "?";
			label(x, y + 82 + 14, 76, initial, 46, 0xFF111111, FlxTextAlign.CENTER);
		}

		label(x + 98, y + 84, INNER_W - 98, "SIGNED IN AS", 14, GRAY);
		label(x + 98, y + 104, INNER_W - 98, user, 34, FlxColor.WHITE);

		var dot:FlxSprite = new FlxSprite(x + 98, y + 150).makeGraphic(12, 12, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(dot, 6, 6, 6, GameJoltInfo.ACCENT);
		dot.scrollFactor.set();
		ui.add(dot);
		label(x + 118, y + 146, INNER_W - 118, "Connected to Game Jolt", 16, GRAY);

		var unlocked:Int = 0;
		for (r in rows)
			if (r.unlocked)
				unlocked++;
		label(x, y + 200, 300, 'Trophies  $unlocked / ${rows.length}', 20, FlxColor.WHITE);
		if (syncNote != "")
			label(x + INNER_W - 300, y + 204, 300, syncNote, 14, GRAY, FlxTextAlign.RIGHT);

		var panel:FlxSprite = rounded(INNER_W, panelH, 14, 0xFF1D1D1D);
		panel.setPosition(x, y + panelTop - 8);
		ui.add(panel);

		if (rows.length == 0)
			label(x + 16, y + panelTop + 2, INNER_W - 32, "No trophies connected yet.", 16, GRAY);

		for (i in 0...rows.length)
		{
			var r:TrophyRow = rows[i];
			var ry:Float = y + panelTop + 2 + i * 28;
			label(x + 16, ry, INNER_W - 180, r.name, 18, r.unlocked ? FlxColor.WHITE : GRAY);
			label(x + INNER_W - 160, ry + 1, 144, r.unlocked ? "Unlocked" : "Locked", 16, r.unlocked ? GameJoltInfo.ACCENT : 0xFF666666, FlxTextAlign.RIGHT);
		}

		var halfW:Int = Std.int((INNER_W - 18) / 2);
		var syncBtn:GJButton = button(x, y + row1, halfW, 48, GameJoltAPI.syncing ? "Syncing..." : "Sync trophies", DARK_BTN, FlxColor.WHITE, function()
		{
			if (GameJoltAPI.syncing)
				return;
			GameJoltAPI.syncTrophies(function(pulled:Int, pushed:Int)
			{
				syncNote = (pulled + pushed == 0) ? "Everything is up to date" : 'Downloaded $pulled, uploaded $pushed';
			});
			requestRebuild();
		});
		if (GameJoltAPI.syncing)
			syncBtn.setEnabled(false);

		var lb:Bool = GameJoltAPI.leaderboardToggle;
		button(x + halfW + 18, y + row1, halfW, 48, 'Upload scores: ' + (lb ? "ON" : "OFF"), lb ? GameJoltInfo.ACCENT : DARK_BTN, lb ? 0xFF111111 : FlxColor.WHITE, function()
		{
			GameJoltAPI.setLeaderboardToggle(!GameJoltAPI.leaderboardToggle);
			requestRebuild();
		});

		button(x, y + row2, halfW, 48, "Sign out", RED, 0xFF111111, function()
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			savedUser = "";
			savedToken = "";
			setStatus("", GRAY);
			GameJoltAPI.logout();
		});
		button(x + halfW + 18, y + row2, halfW, 48, "Back", DARK_BTN, FlxColor.WHITE, closeMenu);
	}

	function submit():Void
	{
		if (busy || userInput == null || !GameJoltAPI.hasKeys())
			return;

		busy = true;
		signInBtn.setEnabled(false);
		signInBtn.setText("Signing in...");
		setStatus("Connecting to Game Jolt...", GRAY);

		GameJoltAPI.login(userInput.text.trim(), tokenInput.text.trim(), function(ok:Bool, msg:String)
		{
			busy = false;
			if (closed)
				return;

			if (ok)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				setStatus("", GRAY);
				return;
			}

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if (signInBtn != null && signInBtn.exists)
			{
				signInBtn.setEnabled(true);
				signInBtn.setText("Sign in");
			}
			setStatus(msg, RED);
		});
	}
}

private class GJButton extends FlxSpriteGroup
{
	public var onClick:Void->Void;
	public var enabled:Bool = true;

	var bg:FlxSprite;
	var text:FlxText;
	var baseColor:FlxColor;
	var hoverColor:FlxColor;

	public function new(x:Float, y:Float, w:Int, h:Int, caption:String, color:FlxColor, textColor:FlxColor, ?cb:Void->Void)
	{
		super(x, y);
		onClick = cb;
		baseColor = color;
		hoverColor = color.getLightened(0.15);

		bg = new FlxSprite().makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(bg, 0, 0, w, h, h, h, FlxColor.WHITE);
		bg.color = baseColor;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var size:Int = h >= 44 ? 20 : 16;
		text = new FlxText(0, 0, w, caption, size);
		text.setFormat(Paths.font('vcr.ttf'), size, textColor, FlxTextAlign.CENTER);
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.y = (h - text.height) / 2;
		add(text);

		scrollFactor.set();
	}

	public function setText(caption:String):Void
		text.text = caption;

	public function setEnabled(value:Bool):Void
	{
		enabled = value;
		bg.color = value ? baseColor : 0xFF3A3A3A;
		text.alpha = value ? 1 : 0.5;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!enabled)
			return;

		var over:Bool = FlxG.mouse.overlaps(bg);
		bg.color = over ? hoverColor : baseColor;

		if (over && FlxG.mouse.justPressed && onClick != null)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			onClick();
		}
	}
}