/**
 * Fullscreen.d
 * 
 * Author: Alex Horvat <alex.horvat9@gmail.com>
 * 
 * Copyright (c) 2013 Alex Horvat
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module kav.Windows.Fullscreen;

debug alias std.stdio.writeln output;

import gdk.Event;
import gdk.Keysyms;

import gtk.Widget;
import gtk.Window;

import kav.Controls.VideoScreen;

public final class Fullscreen
{
	
public:

	this(VideoScreen screen, void delegate() exitFullscreen)
	{
		this.exitFullscreen = exitFullscreen;

		_wdwFullscreen = new Window(GtkWindowType.TOPLEVEL);
		_wdwFullscreen.addOnKeyPress(&wdwFullscreen_KeyPress);
		_wdwFullscreen.fullscreen();
		_wdwFullscreen.show();

		screen.reparent(_wdwFullscreen);
	}

	~this()
	{
		exitFullscreen();
		_wdwFullscreen.destroy();
	}

private:

	Window _wdwFullscreen;

	void delegate() exitFullscreen;
	
	bool wdwFullscreen_KeyPress(Event e, Widget)
	{
		debug output(__FUNCTION__);
		uint key;

		e.getKeyval(key);

		if (key == GdkKeysyms.GDK_Escape)
		{
			//The destructor switches the video back to the original drawing area
			this.destroy();
		}

		return false;
	}
}