/**
 * 
 * Control.d
 * 
 * Author:
 * Alex Horvat <alex.horvat9@gmail.com>
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
module KhanAcademyViewer.Controls.VideoControl;

debug alias std.stdio.writeln output;

import std.file:exists;
import std.string:format;

//For some reason the gstreamer gtkd code will not compile without glib.Date being included in this project
import glib.Date;

import gtk.Grid;
import gtk.EventBox;
import gtk.Label;
import gtk.Button;
import gtk.Scale;
import gtk.ScrolledWindow;
import gtk.Viewport;
import gtk.Image;
import gtk.Range;

import gdk.RGBA;

import gstreamer.gstreamer;
import gstreamer.Element;
import gstreamer.ElementFactory;
import gstreamer.Bus;
import gstreamer.Message;

import gstinterfaces.VideoOverlay;

import KhanAcademyViewer.Include.Functions;
import KhanAcademyViewer.Controls.VideoScreen;
import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Windows.Fullscreen;

public final class VideoControl : Grid
{
	public static bool IsPlaying = false;
	public shared static bool IsFullscreen = false; //Is shared with HidePause and HideTitle threads in VideoScreen

	private double _maxRange;
	private bool _isContinuousPlay = false;

	private Label _lblTitle;
	private EventBox _ebVideo;
	private VideoScreen _vsScreen;
	private Button _btnPlay;
	private Scale _sclPosition;
	private Button _btnFullscreen;
	private Label _lblCurrentTime;
	private Label _lblTotalTime;
	private Label _lblDescription;
	private Image _imgPlay;
	private Image _imgPause;

	private VideoOverlay _voOverlay;
	private Element _elSource;

	public this()
	{
		debug output(__FUNCTION__);
		//Add 4 columns to the grid
		super.insertColumn(0);
		super.insertColumn(0);
		super.insertColumn(0);
		super.insertColumn(0);
		
		//And 5 rows
		super.insertRow(0);
		super.insertRow(0);
		super.insertRow(0);
		super.insertRow(0);
		super.insertRow(0);
		
		_imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);
		_imgPause = new Image(StockID.MEDIA_PAUSE, GtkIconSize.BUTTON);
		
		_lblTitle = new Label("", false);
		_lblTitle.setMaxWidthChars(50);
		_lblTitle.setSizeRequest(-1, 60);
		super.attach(_lblTitle, 0, 0, 4, 1);
		
		_ebVideo = new EventBox();
		_ebVideo.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(0, 0, 0));
		_ebVideo.setSizeRequest(600, 400);
		_ebVideo.setVexpand(true);
		_ebVideo.setHexpand(true);
		super.attach(_ebVideo, 0, 1, 4, 1);

		_vsScreen = new VideoScreen(&PlayPause);
		_ebVideo.add(_vsScreen);
		
		_btnPlay = new Button();
		_btnPlay.setHalign(GtkAlign.START);
		_btnPlay.setImage(_imgPlay);
		_btnPlay.setSensitive(false);
		_btnPlay.addOnClicked(&btnPlay_Clicked);
		super.attach(_btnPlay, 0, 2, 1, 2);
		
		_sclPosition = new Scale(GtkOrientation.HORIZONTAL, null);
		_sclPosition.setDrawValue(false);
		_sclPosition.setHexpand(true);
		_sclPosition.setSensitive(false);
		_sclPosition.addOnChangeValue(&sclPosition_ChangeValue);
		super.attach(_sclPosition, 1, 2, 2, 1);
		
		_btnFullscreen = new Button("Fullscreen", false);
		_btnFullscreen.setHalign(GtkAlign.END);
		_btnFullscreen.setSensitive(false);
		_btnFullscreen.addOnClicked(&btnFullscreen_Clicked);
		super.attach(_btnFullscreen, 3, 2, 1, 2);
		
		_lblCurrentTime = new Label("", false);
		_lblCurrentTime.setHalign(GtkAlign.START);
		_lblCurrentTime.setMarginLeft(5);
		_lblCurrentTime.setHexpand(true);
		super.attach(_lblCurrentTime, 1, 3, 1, 1);
		
		_lblTotalTime = new Label("", false);
		_lblTotalTime.setHalign(GtkAlign.END);
		_lblTotalTime.setMarginRight(5);
		_lblTotalTime.setHexpand(true);
		super.attach(_lblTotalTime, 2, 3, 1, 1);
		
		_lblDescription = new Label("", false);
		
		Viewport vpDescription = new Viewport(null, null);
		vpDescription.add(_lblDescription);
		
		ScrolledWindow swDescription = new ScrolledWindow(vpDescription);
		swDescription.setSizeRequest(-1, 150);
		super.attach(swDescription, 0, 4, 4, 1);
	}

	public void AddOverlays()
	{
		_vsScreen.AddOverlays();
	}

	public void LoadVideo(Library currentVideo, bool startPlaying)
	{
		debug output(__FUNCTION__);
		//Always stop current video before playing another as otherwise can end up with two videos playing at once
		UnloadVideo();

		//Get the spinner going
		_vsScreen.ShowSpinner();

		//Load the text for the video
		LoadVideoDetails(currentVideo);

		//Spinner's going so get the video ready to play
		if (!GStreamer.isInitialized)
		{
			string[] args;
			GStreamer.init(args);
		}
		
		//Not really sure which overlay is better
		//xvimagesink used to be better but now (with different video driver) gives green lines top and bottom of video
		//ximagesink seems to be working ok now with fullscreen, so using that for now.
		//TODO create a setting to switch image sink
		Element elVideoSink = ElementFactory.make("ximagesink", "videosink");
		
		//Setup the video overlay
		_voOverlay = new VideoOverlay(elVideoSink);
		_voOverlay.setWindowHandle(_vsScreen.GetDrawingWindowID());
		
		//Create playbin element and link to videosink
		_elSource = ElementFactory.make("playbin", "playBin");
		_elSource.setProperty("video-sink", cast(ulong)elVideoSink.getElementStruct());

		GstState current;
		GstState pending;
		string localFileName = GetLocalFileName(currentVideo.MP4);
		string totalTime;

		//If file is saved locally then load it, otherwise stream it
		if (exists(localFileName))
		{
			_elSource.setProperty("uri", "file://" ~ localFileName);
		}
		else
		{
			_elSource.setProperty("uri", currentVideo.MP4);
		}

		//Get the video buffered and ready to play
		_elSource.setState(GstState.PAUSED);
		_elSource.getState(current, pending, 100000000); //0.1 seconds
		
		//While loading keep the UI going - refresh every 0.1 seconds until video reports it's ready
		while (current != GstState.PAUSED)
		{
			RefreshUI();
			_elSource.getState(current, pending, 100000000);
		}
		
		//Now that video is ready, can query the length and set the total time of the scale
		//Return in seconds as that's way more managable
		_maxRange = _elSource.queryDuration() / 1000000000;
		 
		_sclPosition.setRange(0, _maxRange);
		
		//Write the total time to lblTotalTime
		totalTime = format("%s:%02s", cast(int)(_maxRange / 60) % 60, cast(int)_maxRange % 60);
		_lblTotalTime.setText(totalTime);
		_lblCurrentTime.setText("0:00");
		
		//Finally re-enable the buttons
		_btnPlay.setSensitive(true);
		_btnFullscreen.setSensitive(true);
		_sclPosition.setSensitive(true);
		_vsScreen.SetEnabled(true);

		//And get rid of the spinner
		_vsScreen.HideSpinner();

		if (startPlaying)
		{
			Play();
		}
	}

	public void UnloadVideo()
	{
		debug output(__FUNCTION__);
		if (_elSource)
		{
			//Stop the video
			_elSource.setState(GstState.NULL);
			IsPlaying = false;

			//Reset the UI
			_btnPlay.setImage(_imgPlay);
			_sclPosition.setValue(0);
			_btnPlay.setSensitive(false);
			_sclPosition.setSensitive(false);
			_btnFullscreen.setSensitive(false);
			_vsScreen.SetEnabled(false);

			_lblTitle.setText("");
			_lblDescription.setText("");
			_lblTotalTime.setText("");
			_lblCurrentTime.setText("");

			//Finally kill elSource
			_elSource.destroy();
			_elSource = null;
		}
	}

	public void StartContinuousPlayMode(void delegate() playNextVideoMethod)
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = true;
		PlayNextVideo = playNextVideoMethod;
	}

	public void StopContinuousPlayMode()
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = false;
		PlayNextVideo = null;
	}

	private void delegate() PlayNextVideo;

	private void btnPlay_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		PlayPause();
	}

	private void btnFullscreen_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		Fullscreen fullScreen = new Fullscreen(_vsScreen, &ExitFullscreen);
		IsFullscreen = true;
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

	private void LoadVideoDetails(Library currentVideo)
	{
		debug output(__FUNCTION__);
		//Get the authors (if there are any)
		string authors;
		
		if (currentVideo.AuthorNames.length > 0)
		{
			foreach (string author; currentVideo.AuthorNames)
			{
				authors ~= author;
				authors ~= ", ";
			}
			//Cut off trailing ", "
			authors.length = authors.length - 2;
		}
		
		_lblTitle.setText(currentVideo.Title);
		
		//Add authors and date added to description
		_lblDescription.setText(currentVideo.Description ~ "\n\nAuthor(s): " ~ authors ~ "\n\nDate Added: " ~ currentVideo.DateAdded.date.toString());

		//If in fullscreen mode show the video title
		if (IsFullscreen)
		{
			_vsScreen.ShowTitle(currentVideo.Title);
		}
	}

	private void ExitFullscreen()
	{
		debug output(__FUNCTION__);
		_vsScreen.HideTitle();
		_vsScreen.reparent(_ebVideo);
		IsFullscreen = false;
	}

	private void PlayPause()
	{
		debug output(__FUNCTION__);
		IsPlaying ? Pause() : Play();
	}

	private void Play()
	{
		debug output(__FUNCTION__);
		if (_elSource.setState(GstState.PLAYING) == GstStateChangeReturn.FAILURE)
		{
			return;
		}
		
		Bus bus = _elSource.getBus();
		Message message;
		long position;
		double positionInSeconds;
		string currentTime;
		
		_btnPlay.setImage(_imgPause);
		
		IsPlaying = true;
		
		while(IsPlaying)
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

						if (_isContinuousPlay)
						{
							PlayNextVideo();
						}

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
				if (_elSource.queryPosition(GstFormat.TIME, position))
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
		_elSource.setState(GstState.PAUSED);
		_btnPlay.setImage(_imgPlay);
		
		IsPlaying = false;
	}

	private void SeekTo(double seconds)
	{
		debug output(__FUNCTION__);
		long nanoSeconds = cast(long)seconds * 1000000000;

		_elSource.seek(nanoSeconds);
	}
}