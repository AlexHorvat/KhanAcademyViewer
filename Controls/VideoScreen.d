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

import gtk.Widget;
import gtk.Overlay;
import gtk.DrawingArea;
import gtk.Spinner;
import gtk.Label;
import gtk.Image;
import gtk.EventBox;

import gdk.Event;
import gdk.X11;

import KhanAcademyViewer.Controls.VideoControl;

public final class VideoScreen : Overlay
{
	private Label _lblTitle;
	private Spinner _spinLoading;
	private EventBox _ebLoading;
	private EventBox _ebPlay;
	private EventBox _ebPause;
	private DrawingArea _daVideoArea;

	public this(void delegate() playPauseMethod)
	{
		debug output(__FUNCTION__);
		PlayPause = playPauseMethod;

		Image imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.DIALOG);
		imgPlay.setVisible(true);

		_ebPlay = new EventBox();
		_ebPlay.setSizeRequest(50, 50);
		_ebPlay.setHalign(GtkAlign.CENTER);
		_ebPlay.setValign(GtkAlign.CENTER);
		_ebPlay.setVisible(false);
		_ebPlay.add(imgPlay);

		Image imgPause = new Image(StockID.MEDIA_PAUSE, GtkIconSize.DIALOG);
		imgPause.setVisible(true);

		_ebPause = new EventBox();
		_ebPause.setSizeRequest(50, 50);
		_ebPause.setHalign(GtkAlign.CENTER);
		_ebPause.setValign(GtkAlign.CENTER);
		_ebPause.setVisible(false);
		_ebPause.add(imgPause);

		//TODO sort out how the label will work - might need an event box too
		_lblTitle = new Label("", false);
		_lblTitle.setVisible(false);

		_spinLoading = new Spinner();
		_spinLoading.setVisible(true);
		_spinLoading.setSizeRequest(200, 200);

		_ebLoading = new EventBox();
		_ebLoading.setSizeRequest(200, 200);
		_ebLoading.setHalign(GtkAlign.CENTER);
		_ebLoading.setValign(GtkAlign.CENTER);
		_ebLoading.setVisible(false);
		_ebLoading.add(_spinLoading);

		_daVideoArea = new DrawingArea();
		//For some reason BUTTON_PRESS_MASK is needed to get the button release event going (not BUTTON_RELEASE MASK)
		_daVideoArea.addEvents(GdkEventMask.BUTTON_PRESS_MASK);
		_daVideoArea.setVisible(true);

		super.add(_daVideoArea);
		super.addOverlay(_ebLoading);
		super.addOverlay(_ebPlay);
		super.addOverlay(_ebPause);
		//super.addOverlay(_lblTitle);
		super.setVisible(true);
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
		_ebLoading.setVisible(true);
		_spinLoading.start();
	}

	public void HideSpinner()
	{
		debug output(__FUNCTION__);
		_spinLoading.stop();
		_ebLoading.setVisible(false);
	}

	public void ShowTitle(string title)
	{
		debug output(__FUNCTION__);
		_lblTitle.setText(title);
		_lblTitle.setVisible(true);

		//TODO Start timer which will hide the title in a few seconds
	}

	public void ShowPlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.setVisible(true);
	}

	public void HidePlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.setVisible(false);
	}

	private void delegate() PlayPause;

	private bool DrawingAreaOrEventBox_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		if (VideoControl.IsPlaying)
		{
			_ebPause.setVisible(false);
			_ebPlay.setVisible(true);
		}
		else
		{
			_ebPlay.setVisible(false);
		}

		PlayPause();
		return false;
	}

	private bool daVideoArea_MotionNotify(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		if (VideoControl.IsPlaying)
		{
			debug output("Is playing");
			_ebPause.setVisible(true);

			//TODO hide pause image after a few seconds, also hide mouse pointer if fullscreen
		}

		return false;
	}
}