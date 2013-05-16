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
import gtk.Button;
import gtk.Image;

import gdk.Event;
import gdk.Keysyms;

import KhanAcademyViewer.Workers.VideoWorker;

protected final class Fullscreen
{
	private string _gladeFile = "./Windows/Fullscreen.glade";

	private Window _wdwFullscreen;
	private DrawingArea _drawVideo;
	private DrawingArea _originalDrawingArea;
	private VideoWorker _videoWorker;
	private Button _btnPlay;
	private Image _imgPlay;
	private Image _imgPause;

	this(VideoWorker videoWorker, Button btnPlay, Image imgPlay, Image imgPause, DrawingArea originalDrawingArea)
	{
		_videoWorker = videoWorker;
		_btnPlay = btnPlay;
		_imgPlay = imgPlay;
		_imgPause = imgPause;
		_originalDrawingArea = originalDrawingArea;
		SetupWindow();
	}

	~this()
	{
		if (_videoWorker !is null)
		{
			//Switch the video back to the main window drawing area and get rid of the fullscreen window
			_videoWorker.ChangeOverlay(_originalDrawingArea);
			_wdwFullscreen.destroy();
		}
	}

	private void SetupWindow()
	{
		Builder windowBuilder = new Builder();
		
		if (!windowBuilder.addFromFile(_gladeFile))
		{
			//Could not load viewer glade file (./Windows/Fullscreen.glade), does it exist?
			return;
		}

		_drawVideo = cast(DrawingArea)windowBuilder.getObject("drawVideo");

		_wdwFullscreen = cast(Window)windowBuilder.getObject("wdwFullscreen");
		_wdwFullscreen.addOnKeyPress(&wdwFullscreen_KeyPress);
		_wdwFullscreen.addOnButtonRelease(&wdwFullscreen_ButtonRelease);
		_wdwFullscreen.fullscreen();
		_wdwFullscreen.showAll();

		//Move the video onto the fullscreen drawing area
		_videoWorker.ChangeOverlay(_drawVideo);

		//Sometimes when fullscreening the video will go back to it's original (small) size, pausing and resuming fixes this
		//TODO can this be fixed by waiting for gstreamer bus to have a confirmation of change overlay? (That code will need to be in _videoWorker.ChangeOverlay();
		_videoWorker.Pause();
		_videoWorker.Play();
	}

	private bool wdwFullscreen_ButtonRelease(Event e, Widget sender)
	{
		//Need to edit the image of the play button here to make sure it's always got the correct icon
		if (_videoWorker.IsPlaying())
		{
			_videoWorker.Pause();
			_btnPlay.setImage(_imgPlay);
		}
		else
		{
			_videoWorker.Play();
			_btnPlay.setImage(_imgPause);
		}

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