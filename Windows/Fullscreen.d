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

import gtk.Builder;
import gtk.Window;
import gtk.DrawingArea;
import gtk.Widget;

import gdk.Event;
import gdk.Keysyms;

import KhanAcademyViewer.Workers.VideoWorker;

protected final class Fullscreen
{
	private const string _gladeFile = "./Windows/Fullscreen.glade";

	private Window _wdwFullscreen;
	private DrawingArea _drawVideo;
	private DrawingArea _originalDrawingArea;
	private VideoWorker _videoWorker;

	this(VideoWorker videoWorker, DrawingArea originalDrawingArea)
	{
		_videoWorker = videoWorker;
		_originalDrawingArea = originalDrawingArea;
		SetupWindow();
	}

	~this()
	{
		//if (_videoWorker !is null)
		//{
			//Switch the video back to the main window drawing area and get rid of the fullscreen window
			_videoWorker.ChangeOverlay(_originalDrawingArea);
			_wdwFullscreen.hide();
			_wdwFullscreen.destroy();
		//}
	}

	private void SetupWindow()
	{
		Builder windowBuilder = new Builder();
		
		windowBuilder.addFromFile(_gladeFile);

		_drawVideo = cast(DrawingArea)windowBuilder.getObject("drawVideo");

		_wdwFullscreen = cast(Window)windowBuilder.getObject("wdwFullscreen");
		_wdwFullscreen.addOnKeyPress(&wdwFullscreen_KeyPress);
		_wdwFullscreen.addOnButtonRelease(&wdwFullscreen_ButtonRelease);
		_wdwFullscreen.fullscreen();
		_wdwFullscreen.showAll();

		//Move the video onto the fullscreen drawing area
		_videoWorker.ChangeOverlay(_drawVideo);
	}

	private bool wdwFullscreen_ButtonRelease(Event e, Widget sender)
	{
		_videoWorker.PlayPause();

		return false;
	}

	private bool wdwFullscreen_KeyPress(Event e, Widget sender)
	{
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