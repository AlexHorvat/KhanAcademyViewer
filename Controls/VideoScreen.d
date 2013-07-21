/**
 * 
 * VideoWindow.d
 * 
 * Author:
 * 		Alex Horvat <alex.horvat9@gmail.com>
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

module KhanAcademyViewer.Controls.VideoScreen;

debug alias std.stdio.writeln output;

import core.thread;

import gtk.Widget;
import gtk.Overlay;
import gtk.DrawingArea;
import gtk.Spinner;
import gtk.Label;
import gtk.Image;
import gtk.EventBox;

import gdk.Event;
import gdk.X11;
import gdk.Cursor;

import KhanAcademyViewer.Controls.VideoControl;
import KhanAcademyViewer.Include.Functions;

public final class VideoScreen : Overlay
{
	private Label _lblTitle;
	private Spinner _spinLoading;
	private EventBox _ebLoading;
	private EventBox _ebPlay;
	private EventBox _ebPause;
	private EventBox _ebTitle;
	private DrawingArea _daVideoArea;

	private Thread _pauseHider;
	private Cursor _blankCursor;

	public this(void delegate() playPauseMethod)
	{
		debug output(__FUNCTION__);
		PlayPause = playPauseMethod;

		_blankCursor = new Cursor(GdkCursorType.BLANK_CURSOR);

		_daVideoArea = new DrawingArea();
		//For some reason BUTTON_PRESS_MASK is needed to get the button release event going (not BUTTON_RELEASE MASK)
		_daVideoArea.addEvents(GdkEventMask.BUTTON_PRESS_MASK);

		super.add(_daVideoArea);
	}

	//Only add the overlays after all the other widgets have 'shown' otherwise they end up displayed
	public void AddOverlays()
	{
		Image imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.DIALOG);
		imgPlay.show();
		
		_ebPlay = new EventBox();
		_ebPlay.setSizeRequest(50, 50);
		_ebPlay.setHalign(GtkAlign.CENTER);
		_ebPlay.setValign(GtkAlign.CENTER);
		_ebPlay.hide();
		_ebPlay.add(imgPlay);
		
		Image imgPause = new Image(StockID.MEDIA_PAUSE, GtkIconSize.DIALOG);
		imgPause.show();
		
		_ebPause = new EventBox();
		_ebPause.setSizeRequest(50, 50);
		_ebPause.setHalign(GtkAlign.CENTER);
		_ebPause.setValign(GtkAlign.CENTER);
		_ebPause.hide();
		_ebPause.add(imgPause);
		
		_lblTitle = new Label("", false);
		_lblTitle.modifyFont("", 24);
		_lblTitle.setMarginBottom(50);
		_lblTitle.show();
		
		_ebTitle = new EventBox();
		_ebTitle.setSizeRequest(300, 50);
		_ebTitle.setHalign(GtkAlign.CENTER);
		_ebTitle.setValign(GtkAlign.END);
		_ebTitle.hide();
		_ebTitle.add(_lblTitle);
		
		_spinLoading = new Spinner();
		_spinLoading.show();
		_spinLoading.setSizeRequest(200, 200);
		
		_ebLoading = new EventBox();
		_ebLoading.setSizeRequest(200, 200);
		_ebLoading.setHalign(GtkAlign.CENTER);
		_ebLoading.setValign(GtkAlign.CENTER);
		_ebLoading.hide();
		_ebLoading.add(_spinLoading);

		super.addOverlay(_ebLoading);
		super.addOverlay(_ebPlay);
		super.addOverlay(_ebPause);
		super.addOverlay(_ebTitle);
	}

	//Simply setting setSensitive to false greys out everything, I want it to stay black, but the user to not be able to interact
	//with the screen, so remove handlers
	public void SetEnabled(bool isEnabled)
	{
		if (isEnabled)
		{
			_ebPlay.addOnButtonRelease(&DrawingAreaOrEventBox_ButtonRelease);
			_ebPause.addOnButtonRelease(&DrawingAreaOrEventBox_ButtonRelease);
			_daVideoArea.addOnButtonRelease(&DrawingAreaOrEventBox_ButtonRelease);
			_daVideoArea.addOnMotionNotify(&daVideoArea_MotionNotify);
		}
		else
		{
			HideSpinner();

			_ebTitle.hide();
			_ebPlay.hide();
			_ebPause.hide();

			_ebPlay.onButtonReleaseListeners.destroy();
			_ebPause.onButtonPressListeners.destroy();
			_daVideoArea.onButtonReleaseListeners.destroy();
			_daVideoArea.onMotionNotifyListeners.destroy();
		}
	}

	public ulong GetDrawingWindowID()
	{
		debug output(__FUNCTION__);
		return X11.windowGetXid(_daVideoArea.getWindow());
	}

	public void ShowSpinner()
	{
		debug output(__FUNCTION__);
		_ebLoading.show();
		_spinLoading.start();
	}

	public void HideSpinner()
	{
		debug output(__FUNCTION__);
		_spinLoading.stop();
		_ebLoading.hide();
	}

	public void ShowTitle(string title)
	{
		debug output(__FUNCTION__);
		_lblTitle.setText(title);
		_ebTitle.show();

		//Spawn a new thread to hide the title
		Thread TitleHider = new Thread(&DelayedHideTitle);
		TitleHider.start();
	}
	
	public void HideTitle()
	{
		_ebTitle.hide();
	}

	public void ShowPlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.show();
	}

	public void HidePlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.hide();
	}

	private void DelayedHideTitle()
	{
		debug output(__FUNCTION__);
		Thread.sleep(dur!"seconds"(3));
		_ebTitle.hide();

		//Hide the cursor too
		if (VideoControl.IsFullscreen)
		{
			_daVideoArea.setCursor(_blankCursor);
		}
	}

	private void delegate() PlayPause;

	private bool DrawingAreaOrEventBox_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		if (VideoControl.IsPlaying)
		{
			_ebPause.hide();
			_ebPlay.show();
		}
		else
		{
			_ebPlay.hide();
		}

		PlayPause();
		return false;
	}

	private void DelayedHidePause()
	{
		debug output(__FUNCTION__);
		Thread.sleep(dur!"seconds"(3));
		_ebPause.hide();

		//Hide the cursor too
		if (VideoControl.IsFullscreen)
		{
			_daVideoArea.setCursor(_blankCursor);
		}

		_pauseHider = null;
	}

	private bool daVideoArea_MotionNotify(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		//Spawn a thread, if already exists do nothing to stop from creating huge amount of timer threads and crashing
		if (VideoControl.IsPlaying && !_pauseHider)
		{
			_ebPause.show();

			_pauseHider = new Thread(&DelayedHidePause);
			_pauseHider.start();
		}
		else
		{
			_daVideoArea.resetCursor();
		}

		return false;
	}
}