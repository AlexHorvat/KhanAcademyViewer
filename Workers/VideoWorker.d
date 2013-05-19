//
//  VideoWorker.d
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

module KhanAcademyViewer.Workers.VideoWorker;

import std.stdio;
alias std.string str;

import glib.Date;

import gtk.DrawingArea;
import gtk.Button;
import gtk.Image;
import gtk.Scale;
import gtk.Range;
import gtk.Widget;
import gtk.Spinner;
import gtk.Main;
import gtk.Fixed;
import gtk.Label;

import gdk.RGBA;
import gdk.Event;
import gdk.X11;

import gobject.Value;

import gstreamer.gstreamer;
import gstreamer.Element;
import gstreamer.ElementFactory;
import gstreamer.Bus;
import gstreamer.Message;

import gstinterfaces.VideoOverlay;

/* TODO
 * Clean up code, there's lot's of redundent stuff in here
 * Find out why crashing on clicking play for after first video
 * Make sure gstreamer disposed of correctly etc
 * Resizing the video still doesn't work all that well
 */

protected final class VideoWorker
{
	Element _videoSink;
	Element _source;
	VideoOverlay _overlay;
	Image _imgPlay;
	Image _imgPause;
	DrawingArea _drawVideo;
	Button _btnPlay;
	Scale _sclPosition;
	Spinner _spinLoading;
	Label _lblCurrentTime;
	Label _lblTotalTime;
	Fixed _fixedVideo;
	bool _isPlaying;
	double _maxRange;

	this(string fileName, Fixed fixedVideo, DrawingArea drawVideo, Button btnPlay, Scale sclPosition, Label lblCurrentTime, Label lblTotalTime)
	{
		//Set class level variables
		_fixedVideo = fixedVideo;
		_drawVideo = drawVideo;
		_btnPlay = btnPlay;
		_sclPosition = sclPosition;
		_lblCurrentTime = lblCurrentTime;
		_lblTotalTime = lblTotalTime;
		_isPlaying = false;
		_imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);
		_imgPause = new Image(StockID.MEDIA_PAUSE, GtkIconSize.BUTTON);

		ShowSpinner();
		SetupVideo(fileName);
		HideSpinner();
	}

	~this()
	{
		//Stop and get rid of video and all resources
		_source.setState(GstState.NULL);
		_source.destroy();
		_videoSink.destroy();
		_overlay.destroy();
	}

	private void ShowSpinner()
	{
		_spinLoading = new Spinner();
		RGBA rgbaWhite = new RGBA(255,255,255);
		RGBA rgbaBlack = new RGBA(0,0,0);
		int videoWidth;
		int videoHeight;
		int spinnerWidth = 100;
		int spinnerHeight = 100;

		//Need to get the event box's size to position the spinner correctly
		_drawVideo.getSizeRequest(videoWidth, videoHeight);
		_spinLoading.setSizeRequest(spinnerWidth, spinnerHeight);

		//Set the spinner to white forecolour, black background
		_spinLoading.overrideColor(GtkStateFlags.NORMAL, rgbaWhite);
		_spinLoading.overrideBackgroundColor(GtkStateFlags.NORMAL, rgbaBlack);

		//Setup then hide drawVideo
		_drawVideo.addOnButtonRelease(&drawVideo_ButtonRelease);
		_drawVideo.setVisible(false);
		
		//Place and show the spinner
		_fixedVideo.put(_spinLoading, videoWidth / 2 - spinnerWidth / 2, videoHeight / 2 - spinnerHeight / 2);
		_spinLoading.showAll();
		_spinLoading.start();
	}

	private void SetupVideo(string fileName)
	{
		GstState current;
		GstState pending;
		string[] args;
		string totalTime;

		//Setup controls
		GStreamer.init(args);

		_btnPlay.addOnClicked(&btnPlay_Clicked);
		_btnPlay.setSensitive(true);
		
		_sclPosition.addOnChangeValue(&sclPosition_ChangeValue);
		
		_videoSink = ElementFactory.make("xvimagesink", "videosink");
		
		//Link the video sink to the drawingArea
		_overlay = new VideoOverlay(_videoSink);
		_overlay.setWindowHandle(X11.windowGetXid(_drawVideo.getWindow()));
		
		//Create a playbin element and point it at the selected video
		_source = ElementFactory.make("playbin", "playBin");
		_source.setProperty("uri", fileName);

		//Work around to .setProperty not accepting Element type directly
		Value val = new Value();
		val.init(GType.OBJECT);
		val.setObject(_videoSink.getElementStruct());
		_source.setProperty("video-sink", val);

		//Get the video buffered and ready to play
		_source.setState(GstState.PAUSED);
		_source.getState(current, pending, 100000000); //0.1 seconds

		//While loading keep the UI going - refresh every 0.1 seconds until video reports it's ready
		while (current != GstState.PAUSED)
		{
			RefreshUI();
			_source.getState(current, pending, 100000000);
		}

		//Now that video is ready, can query the length and set the total time of the scale
		_maxRange = GetDuration();
		_sclPosition.setRange(0, _maxRange);

		//Write the total time to lblTotalTime
		totalTime = str.format("%s:%02s", cast(int)(_maxRange / 60) % 60, cast(int)_maxRange % 60);
		_lblTotalTime.setText(totalTime);
		_lblCurrentTime.setText("0:00");
	}

	private void HideSpinner()
	{
		_fixedVideo.remove(_spinLoading);
		_drawVideo.setVisible(true);
	}

	private void RefreshUI()
	{
		//Run any gtk events pending to refresh the UI
		while (Main.eventsPending)
		{
			Main.iteration();
		}
	}

	public void Play()
	{
		//TODO there's still a bug in here when playing a 2nd or later video - will just crash on play

		if (_source.setState(GstState.PLAYING) == GstStateChangeReturn.FAILURE)
		{
			writeln("Play failed");
			return;
		}

		_btnPlay.setImage(_imgPause);
		_isPlaying = true;

		Bus bus = _source.getBus();
		Message message;
		long position;
		double positionInSeconds;
		string currentTime;

		while(_isPlaying)
		{
			//Is a new message required every time?
			message = bus.timedPopFiltered(100000000, GstMessageType.EOS | GstMessageType.ERROR);

			if (message !is null)
			{
				//EOF or error happened
				switch (message.type)
				{
					case GstMessageType.EOS:
						writeln("Stream ended");
						Pause();
						//Seek but don't change sclPosition, so if user clicks play the video will start again, but still looks like it's finished
						SeekTo(0);
						break;

					case GstMessageType.ERROR:
						writeln("Error, errorr, erorror");
						this.destroy();
						break;

					default:
						break;
				}
			}
			else
			{
				if (_source.queryPosition(GstFormat.TIME, position))
				{
					//Get position in seconds for use in setting the scale position
					positionInSeconds = position / 1000000000;

					//Format the position into m:ss format (don't think there are any videos even near an hour long, so don't worry about hours for now)
					currentTime = str.format("%s:%02s", cast(int)(positionInSeconds / 60) % 60, cast(int)positionInSeconds % 60);

					//Move the position indicator
					_sclPosition.setValue(positionInSeconds);

					//Change the displayed time
					_lblCurrentTime.setText(currentTime);
				}
			}

			RefreshUI();
		}
	}

	public void Pause()
	{
		_source.setState(GstState.PAUSED);
		_btnPlay.setImage(_imgPlay);
		_isPlaying = false;
	}

	public bool IsPlaying()
	{
		return _isPlaying;
	}
	
	public void ChangeOverlay(ref DrawingArea area)
	{
		//Switch the video overlay to the provided drawing area
		_overlay.setWindowHandle(X11.windowGetXid(area.getWindow()));
	}

	public double GetDuration()
	{
		//Return in seconds as that's way more managable
		long duration = _source.queryDuration();

		return duration / 1000000000;
	}

	public void SeekTo(double seconds)
	{
		long nanoSeconds = cast(long)seconds * 1000000000;
		_source.seek(nanoSeconds);
	}

	private bool sclPosition_ChangeValue(GtkScrollType scrollType, double position, Range range)
	{
		if (scrollType == GtkScrollType.JUMP)
		{
			if (position > _maxRange)
			{
				position = _maxRange;
			}
			
			writeln("Seeking to ", position);
			SeekTo(position);

			long time;
			_source.queryPosition(GstFormat.TIME, time);
			writeln("new time ", time);
		}
		
		return false;
	}

	private bool drawVideo_ButtonRelease(Event e, Widget sender)
	{
		PlayPause();
		return true;
	}

	private void btnPlay_Clicked(Button sender)
	{
		PlayPause();
	}

	private void PlayPause()
	{
		//Check that a video is loaded
		//if (_videoWorker !is null)
		//{
		if (_isPlaying)
		{
			Pause();
			//_btnPlay.setImage(_imgPlay);
		}
		else
		{
			Play();
			//_btnPlay.setImage(_imgPause);
		}
		//}
	}
}