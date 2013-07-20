//
//  Fullscreen.d
//
//  Author:
//       Alex Horvat <alex.horvat9@gmail.com>
//
//  Copyright (c) 2013 Alex Horvat
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

module KhanAcademyViewer.Windows.Fullscreen;

debug alias std.stdio.writeln output;

import gtk.Window;
import gtk.Widget;

import gdk.Event;
import gdk.Keysyms;

import KhanAcademyViewer.Controls.VideoScreen;

public final class Fullscreen
{
	private Window _wdwFullscreen;

	public this(VideoScreen screen, void delegate() exitFullscreen)
	{
		ExitFullscreen = exitFullscreen;

		_wdwFullscreen = new Window(GtkWindowType.TOPLEVEL);
		_wdwFullscreen.addOnKeyPress(&wdwFullscreen_KeyPress);
		_wdwFullscreen.fullscreen();
		_wdwFullscreen.show();

		screen.reparent(_wdwFullscreen);
	}

	public ~this()
	{
		ExitFullscreen();
		_wdwFullscreen.destroy();
	}

	private void delegate() ExitFullscreen;
	
	private bool wdwFullscreen_KeyPress(Event e, Widget sender)
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