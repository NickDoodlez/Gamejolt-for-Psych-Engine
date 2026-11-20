package gamejolt;

import backend.Paths;
import flixel.FlxG;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.filters.DropShadowFilter;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class GameJoltToastManager extends Sprite
{
	public static inline var INFO:Int = 0;
	public static inline var SUCCESS:Int = 1;
	public static inline var ERROR:Int = 2;
	public static inline var TROPHY:Int = 3;

	static inline var MARGIN:Int = 14;
	static inline var GAP:Int = 10;
	static inline var ENTER_TIME:Float = 0.35;
	static inline var HOLD_TIME:Float = 3.6;
	static inline var LEAVE_TIME:Float = 0.4;

	var toasts:Array<Toast> = [];
	var lastTime:Int;

	public function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;
		lastTime = Lib.getTimer();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	public function createToast(title:String, ?description:String = "", ?kind:Int = INFO, ?sound:Bool = false, ?icon:BitmapData):Void
	{
		if (sound)
		{
			try
			{
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
			}
			catch (e:Dynamic) {}
		}

		var toast:Toast = new Toast(title, description, kind, icon);
		toast.y = -toast.boxHeight - 20;
		addChild(toast);
		toasts.push(toast);
	}

	function onFrame(_:Event):Void
	{
		var now:Int = Lib.getTimer();
		var dt:Float = Math.min((now - lastTime) / 1000, 0.1);
		lastTime = now;

		var stageW:Float = Lib.current.stage.stageWidth;
		var targetY:Float = MARGIN;
		var i:Int = 0;

		while (i < toasts.length)
		{
			var t:Toast = toasts[i];
			t.age += dt;

			if (t.age >= ENTER_TIME + HOLD_TIME + LEAVE_TIME)
			{
				removeChild(t);
				toasts.splice(i, 1);
				continue;
			}

			var slide:Float = 1;
			if (t.age < ENTER_TIME)
				slide = t.age / ENTER_TIME;
			else if (t.age > ENTER_TIME + HOLD_TIME)
				slide = 1 - (t.age - ENTER_TIME - HOLD_TIME) / LEAVE_TIME;

			var eased:Float = 1 - Math.pow(1 - slide, 3);
			t.x = stageW - MARGIN - Toast.WIDTH + (1 - eased) * (Toast.WIDTH + MARGIN * 2);
			t.alpha = Math.min(1, eased * 1.5);

			if (!t.placed)
			{
				t.y = targetY;
				t.placed = true;
			}
			else
				t.y += (targetY - t.y) * Math.min(1, dt * 12);

			targetY += t.boxHeight + GAP;
			i++;
		}
	}
}

private class Toast extends Sprite
{
	public static inline var WIDTH:Int = 380;
	static inline var ICON_R:Int = 20;

	public var age:Float = 0;
	public var placed:Bool = false;
	public var boxHeight(default, null):Float = 0;

	static var fontName:String = null;

	static function getFontName():String
	{
		if (fontName != null)
			return fontName;

		fontName = "_sans";
		try
		{
			var font = openfl.utils.Assets.getFont(Paths.font('vcr.ttf'));
			if (font != null)
				fontName = font.fontName;
		}
		catch (e:Dynamic) {}
		return fontName;
	}

	public function new(title:String, description:String, kind:Int, ?iconBitmap:BitmapData)
	{
		super();

		var accent:Int = switch (kind)
		{
			case GameJoltToastManager.ERROR: 0xFF5A5F;
			case GameJoltToastManager.TROPHY: 0xFFC83D;
			default: 0xCCFF00;
		};

		var textX:Int = 68;
		var textW:Int = WIDTH - textX - 14;

		var titleField:TextField = makeField(title, 18, 0xFFFFFF, true, textW);
		titleField.x = textX;
		titleField.y = 12;

		var descField:TextField = null;
		var contentH:Float = titleField.height;
		if (description != null && description != "")
		{
			descField = makeField(description, 14, 0xB8B8B8, false, textW);
			descField.x = textX;
			descField.y = titleField.y + titleField.height + 2;
			contentH = descField.y + descField.height - 12;
		}

		boxHeight = Math.max(66, contentH + 24);

		var body:Shape = new Shape();
		body.graphics.beginFill(accent);
		body.graphics.drawRoundRect(0, 0, WIDTH, boxHeight, 16, 16);
		body.graphics.endFill();
		body.graphics.beginFill(0x161616, 0.97);
		body.graphics.drawRoundRect(5, 0, WIDTH - 5, boxHeight, 16, 16);
		body.graphics.endFill();
		addChild(body);

		var icon:Shape = new Shape();
		var cx:Float = 34;
		var cy:Float = boxHeight / 2;

		if (iconBitmap != null && iconBitmap.width > 0 && iconBitmap.height > 0)
		{
			var m:Matrix = new Matrix();
			m.scale(ICON_R * 2 / iconBitmap.width, ICON_R * 2 / iconBitmap.height);
			m.translate(cx - ICON_R, cy - ICON_R);

			icon.graphics.beginFill(accent);
			if (kind == GameJoltToastManager.TROPHY)
				icon.graphics.drawRoundRect(cx - ICON_R - 2, cy - ICON_R - 2, ICON_R * 2 + 4, ICON_R * 2 + 4, 14, 14);
			else
				icon.graphics.drawCircle(cx, cy, ICON_R + 2);
			icon.graphics.endFill();

			icon.graphics.beginBitmapFill(iconBitmap, m, false, true);
			if (kind == GameJoltToastManager.TROPHY)
				icon.graphics.drawRoundRect(cx - ICON_R, cy - ICON_R, ICON_R * 2, ICON_R * 2, 12, 12);
			else
				icon.graphics.drawCircle(cx, cy, ICON_R);
			icon.graphics.endFill();
		}
		else
		{
			icon.graphics.beginFill(accent);
			icon.graphics.drawCircle(cx, cy, 18);
			icon.graphics.endFill();
			drawGlyph(icon, cx, cy, kind);
		}
		addChild(icon);

		addChild(titleField);
		if (descField != null)
			addChild(descField);

		filters = [new DropShadowFilter(4, 90, 0x000000, 0.55, 14, 14, 1, 2)];
		mouseEnabled = false;
		mouseChildren = false;
	}

	function makeField(text:String, size:Int, color:Int, bold:Bool, width:Int):TextField
	{
		var tf:TextField = new TextField();
		tf.defaultTextFormat = new TextFormat(getFontName(), size, color, bold);
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.wordWrap = true;
		tf.multiline = true;
		tf.width = width;
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.text = text;
		return tf;
	}

	function drawGlyph(s:Shape, cx:Float, cy:Float, kind:Int):Void
	{
		var g = s.graphics;
		g.lineStyle(3, 0x111111, 1, false, null, openfl.display.CapsStyle.ROUND, openfl.display.JointStyle.ROUND);

		switch (kind)
		{
			case GameJoltToastManager.SUCCESS:
				g.moveTo(cx - 7, cy);
				g.lineTo(cx - 2, cy + 5);
				g.lineTo(cx + 7, cy - 6);
			case GameJoltToastManager.ERROR:
				g.moveTo(cx, cy - 8);
				g.lineTo(cx, cy + 2);
				g.moveTo(cx, cy + 7);
				g.lineTo(cx, cy + 7.1);
			case GameJoltToastManager.TROPHY:
				g.lineStyle(2, 0x111111, 1);
				g.beginFill(0x111111);
				for (i in 0...10)
				{
					var r:Float = (i % 2 == 0) ? 9 : 4;
					var a:Float = -Math.PI / 2 + i * Math.PI / 5;
					var px:Float = cx + Math.cos(a) * r;
					var py:Float = cy + Math.sin(a) * r;
					if (i == 0)
						g.moveTo(px, py);
					else
						g.lineTo(px, py);
				}
				g.endFill();
			default:
				g.moveTo(cx, cy - 1);
				g.lineTo(cx, cy + 8);
				g.moveTo(cx, cy - 8);
				g.lineTo(cx, cy - 7.9);
		}
	}
}