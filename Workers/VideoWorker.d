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

debug alias std.stdio.writeln output;

import std.string;
import std.path:expandTilde;
import std.file:exists;

import glib.Date;

import gtk.DrawingArea;
import gtk.Button;
import gtk.Image;
import gtk.Scale;
import gtk.Range;
import gtk.Widget;
import gtk.Spinner;
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

import KhanAcademyViewer.Include.Config;
import KhanAcademyViewer.Workers.DownloadWorker;
import KhanAcademyViewer.Include.Functions;
import KhanAcademyViewer.Windows.Fullscreen;

public final class VideoWorker
{
	private Element _videoSink;
	private Element _source;
	private VideoOverlay _overlay;
	private Image _imgPlay;
	private Image _imgPause;
	private DrawingArea _drawVideo;
	private Button _btnPlay;
	private Button _btnFullscreen;
	private Scale _sclPosition;
	private Spinner _spinLoading;
	private Label _lblCurrentTime;
	private Label _lblTotalTime;
	private Fixed _fixedVideo;
	private bool _isPlaying;
	private double _maxRange;

	public this(string fileName, Fixed fixedVideo, DrawingArea drawVideo, Button btnPlay, Button btnFullscreen, Scale sclPosition, Label lblCurrentTime, Label lblTotalTime)
	{
		debug output(__FUNCTION__);
		//Set class level variables
		_fixedVideo = fixedVideo;
		_drawVideo = drawVideo;
		_btnPlay = btnPlay;
		_btnFullscreen = btnFullscreen;
		_sclPosition = sclPosition;
		_lblCurrentTime = lblCurrentTime;
		_lblTotalTime = lblTotalTime;
		_isPlaying = false;
		_imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);
		_imgPause = new Image(StockID.MEDIA_PAUSE, GtkIconSize.BUTTON);
		//_fileName = fileName;

		//SetLocalFileName();
		ShowSpinner();
		SetupVideo(fileName);
		HideSpinner();
	}

	public ~this()
	{
		debug output(__FUNCTION__);
		//Don't leave icon as pause icon and move scale pointer back to 0
		_btnPlay.setImage(_imgPlay);
		_sclPosition.setValue(0);
		_btnPlay.setSensitive(false);
		_sclPosition.setSensitive(false);
		_btnFullscreen.setSensitive(false);

		//Remove listeners, otherwise old listeners are retained between
		//video loads causing a crash
		_drawVideo.onButtonReleaseListeners.destroy();
		_btnPlay.onClickedListeners.destroy();
		_sclPosition.onChangeValueListeners.destroy();
		_btnFullscreen.onClickedListeners.destroy();

		//Stop and get rid of video and all resources
		_source.setState(GstState.NULL);
		_source.destroy();
		_videoSink.destroy();
		_overlay.destroy();
	}

	private void btnFullscreen_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		Fullscreen fullScreen = new Fullscreen(_drawVideo, &ChangeOverlay, &PlayPause);
	}

	private void ShowSpinner()
	{
		debug output(__FUNCTION__);
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

		//Hide drawVideo
		_drawVideo.setVisible(false);
		
		//Place and show the spinner
		_fixedVideo.put(_spinLoading, videoWidth / 2 - spinnerWidth / 2, videoHeight / 2 - spinnerHeight / 2);
		_spinLoading.showAll();
		_spinLoading.start();
	}

	private void SetupVideo(string fileName)
	{
		debug output(__FUNCTION__);
		GstState current;
		GstState pending;
		string[] args;
		string totalTime;
		string localFileName = GetLocalFileName(fileName);

		//Setup controls
		GStreamer.init(args);

		_drawVideo.addOnButtonRelease(&drawVideo_ButtonRelease);

		_btnPlay.addOnClicked(&btnPlay_Clicked);
		_btnPlay.setSensitive(true);

		_btnFullscreen.addOnClicked(&btnFullscreen_Clicked);
		_btnFullscreen.setSensitive(true);
		
		_sclPosition.addOnChangeValue(&sclPosition_ChangeValue);
		_sclPosition.setSensitive(true);
		
		_videoSink = ElementFactory.make("xvimagesink", "videosink");
		
		//Link the video sink to the drawingArea
		_overlay = new VideoOverlay(_videoSink);
		_overlay.setWindowHandle(X11.windowGetXid(_drawVideo.getWindow()));
		
		//Create a playbin element and point it at the selected video
		_source = ElementFactory.make("playbin", "playBin");

		//If file is saved locally then load it, otherwise stream it
		if (exists(localFileName))
		{
			debug output("Local video");
			_source.setProperty("uri", "file://" ~ localFileName);
		}
		else
		{
			debug output("Streaming video");
			_source.setProperty("uri", fileName);
		}

		//TODO this seems to be a bug in GtkD, check for fixes BUG???
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
		totalTime = format("%s:%02s", cast(int)(_maxRange / 60) % 60, cast(int)_maxRange % 60);
		_lblTotalTime.setText(totalTime);
		_lblCurrentTime.setText("0:00");
	}

	private void HideSpinner()
	{
		debug output(__FUNCTION__);
		_fixedVideo.remove(_spinLoading);
		_drawVideo.setVisible(true);
	}
	
	private void Play()
	{
		debug output(__FUNCTION__);
		if (_source.setState(GstState.PLAYING) == GstStateChangeReturn.FAILURE)
		{
			return;
		}

		Bus bus = _source.getBus();
		Message message;
		long position;
		double positionInSeconds;
		string currentTime;

		_btnPlay.setImage(_imgPause);
		_isPlaying = true;

		while(_isPlaying)
		{
			//Is a new message required every time?
			message = bus.timedPopFiltered(100000000, GstMessageType.EOS | GstMessageType.ERROR);

			if (message)
			{
				//EOF or error happened
				switch (message.type)
				{
					case GstMessageType.EOS:
						Pause();
						//Seek but don't change sclPosition, so if user clicks play the video will start again, but still looks like it's finished
						SeekTo(0);
						break;

					case GstMessageType.ERROR:
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
					currentTime = format("%s:%02s", cast(int)(positionInSeconds / 60) % 60, cast(int)positionInSeconds % 60);

					//Move the position indicator
					_sclPosition.setValue(positionInSeconds);

					//Change the displayed time
					_lblCurrentTime.setText(currentTime);
				}
			}

			RefreshUI();
		}
	}

	private void Pause()
	{
		debug output(__FUNCTION__);
		_source.setState(GstState.PAUSED);
		_btnPlay.setImage(_imgPlay);
		_isPlaying = false;
	}

	private void ChangeOverlay(DrawingArea area)
	{
		debug output(__FUNCTION__);
		//Switch the video overlay to the provided drawing area
		_overlay.setWindowHandle(X11.windowGetXid(area.getWindow()));
	}

	private double GetDuration()
	{
		debug output(__FUNCTION__);
		//Return in seconds as that's way more managable
		return _source.queryDuration() / 1000000000;
	}

	private void SeekTo(double seconds)
	{
		debug output(__FUNCTION__);
		long nanoSeconds = cast(long)seconds * 1000000000;
		_source.seek(nanoSeconds);
	}

	private bool sclPosition_ChangeValue(GtkScrollType scrollType, double position, Range range)
	{
		debug output(__FUNCTION__);
		if (scrollType == GtkScrollType.JUMP)
		{
			//Don't allow seeking past end of video
			if (position > _maxRange)
			{
				position = _maxRange;
			}

			SeekTo(position);
		}
		
		return false;
	}

	private bool drawVideo_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		PlayPause();
		return false;
	}

	private void btnPlay_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		PlayPause();
	}

	private void PlayPause()
	{
		debug output(__FUNCTION__);
		if (_isPlaying)
		{
			Pause();
		}
		else
		{
			Play();
		}
	}
}