/*
 * VideoScreen.d
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

module kav.Controls.VideoScreen;

debug alias std.stdio.writeln output;

import core.thread;

import gdk.Cursor;
import gdk.Event;
import gdk.X11;

import gtk.DrawingArea;
import gtk.EventBox;
import gtk.Image;
import gtk.Label;
import gtk.Overlay;
import gtk.Spinner;
import gtk.Widget;

import kav.Controls.VideoControl;
import kav.Include.Functions;

import pango.PgFontDescription;

public final class VideoScreen : Overlay
{

public:

	this(void delegate() playPauseMethod)
	{
		debug output(__FUNCTION__);
		this.playPause = playPauseMethod;

		_blankCursor = new Cursor(GdkCursorType.BLANK_CURSOR);

		_daVideoArea = new DrawingArea();
		//For some reason BUTTON_PRESS_MASK is needed to get the button release event going (not BUTTON_RELEASE MASK)
		_daVideoArea.addEvents(GdkEventMask.BUTTON_PRESS_MASK);

		super.add(_daVideoArea);
	}
	
	/**
	 * Add the overlays (i.e. the play/pause/title etc controls) to the video window.
	 * This needs to be done after all the other widgets have been displayed by the parent .showAll as otherwise the
	 * overlays are displayed too. 
	 */
	void addOverlays()
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
		_lblTitle.overrideFont(new PgFontDescription("", 24));
		_lblTitle.setLineWrap(true);
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

	/**
	 * Get the video window ID, this is needed by some of the gstreamer objects to give them somewhere to output video.
	 * 
	 * Returns: The ID value of the video window widget.
	 */
	ulong getDrawingWindowID()
	{
		debug output(__FUNCTION__);
		return X11.windowGetXid(_daVideoArea.getWindow());
	}

	/**
	 * Hide the play button/image overlay.
	 */
	void hidePlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.hide();
	}

	/**
	 * Stop and hide the spinner overlay.
	 */
	void hideSpinner()
	{
		debug output(__FUNCTION__);
		if (_ebLoading.isVisible)
		{
			_spinLoading.stop();
			_ebLoading.hide();
		}
	}

	/**
	 * Hide the title overlay.
	 */
	void hideTitle()
	{
		debug output(__FUNCTION__);
		_ebTitle.hide();
	}

	/**
	 * Simply setting setSensitive to false greys out everything, I want the video window's background to stay black,
	 * but stop the user interacting with the screen with the screen, so remove the event handlers.
	 * 
	 * Params:
	 * isEnabled = whether to add or remove the event handlers.
	 */
	void setEnabled(bool isEnabled)
	{
		debug output(__FUNCTION__);
		if (isEnabled)
		{
			_ebPlay.addOnButtonRelease(&drawingAreaOrEventBox_ButtonRelease);
			_ebPause.addOnButtonRelease(&drawingAreaOrEventBox_ButtonRelease);
			_daVideoArea.addOnButtonRelease(&drawingAreaOrEventBox_ButtonRelease);
			_daVideoArea.addOnMotionNotify(&daVideoArea_MotionNotify);
		}
		else
		{
			hideSpinner();

			_ebTitle.hide();
			_ebPlay.hide();
			_ebPause.hide();

			_ebPlay.onButtonReleaseListeners.destroy();
			_ebPause.onButtonReleaseListeners.destroy();
			_daVideoArea.onButtonReleaseListeners.destroy();
			_daVideoArea.onMotionNotifyListeners.destroy();
		}
	}

	/**
	 * Show the play button/image overlay.
	 */
	void showPlayButton()
	{
		debug output(__FUNCTION__);
		_ebPlay.show();
	}

	/**
	 * Show and start the spinner overlay.
	 */
	void showSpinner()
	{
		debug output(__FUNCTION__);
		if (!_ebLoading.isVisible())
		{
			_ebLoading.show();
			_spinLoading.start();
		}
	}

	/**
	 * Show the title overlay and set the text.
	 * 
	 * Params:
	 * title = the text to show.
	 */
	void showTitle(string title)
	{
		debug output(__FUNCTION__);
		_lblTitle.setText(title);
		_ebTitle.show();

		//Spawn a new thread to hide the title
		Thread titleHider = new Thread(&delayedHideTitle);
		titleHider.start();
		titleHider = null;
	}
	
private:

	Cursor		_blankCursor;
	DrawingArea	_daVideoArea;
	EventBox	_ebLoading;
	EventBox	_ebPause;
	EventBox	_ebPlay;
	EventBox	_ebTitle;
	Label		_lblTitle;
	Thread		_pauseHider;
	Spinner		_spinLoading;

	/*
	 * If the user moves the mouse over the video widget, and the video is playing, then show the pause overlay.
	 * Then this spawns a thread to hide the overlay after a few seconds.
	 */
	bool daVideoArea_MotionNotify(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Spawn a thread, if already exists do nothing to stop from creating huge amount of timer threads and crashing
		if (VideoControl.isPlaying && !_pauseHider)
		{
			_ebPause.show();
			
			_pauseHider = new Thread(&delayedHidePause);
			_pauseHider.start();
		}
		else
		{
			_daVideoArea.resetCursor();
		}
		
		return false;
	}

	/*
	 * Hide the pause overlay after a few seconds.
	 * This should be called on it's own thread as it locks the thread while waiting to hide the overlay.
	 */
	void delayedHidePause()
	{
		debug output(__FUNCTION__);
		Thread.sleep(dur!"seconds"(3));
		_ebPause.hide();
		
		//Hide the cursor too
		if (VideoControl.isFullscreen)
		{
			_daVideoArea.setCursor(_blankCursor);
		}
		
		_pauseHider = null;
	}

	/*
	 * Hide the title overlay after a few seconds.
	 * This should be called on it's own thread as it locks the thread while waiting to hide the overlay.
	 */
	void delayedHideTitle()
	{
		debug output(__FUNCTION__);
		Thread.sleep(dur!"seconds"(5));
		_ebTitle.hide();

		//Hide the cursor too
		if (VideoControl.isFullscreen)
		{
			_daVideoArea.setCursor(_blankCursor);
		}
	}

	/*
	 * If the user clicks anywhere on the video widget then depending on whether the video is playing or paused, either pause the video
	 * or start it playing again. If pausing show the play image overlay.
	 */
	bool drawingAreaOrEventBox_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		if (VideoControl.isPlaying)
		{
			_ebPause.hide();
			_ebPlay.show();
		}
		else
		{
			_ebPlay.hide();
		}
		
		playPause();
		return false;
	}

	/*
	 * Delegate for the playPause method in videoControl.d this handles the actual playing/pausing of the video.
	 */
	void delegate() playPause;
}