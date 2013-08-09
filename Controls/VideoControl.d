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
module kav.Controls.VideoControl;

debug alias std.stdio.writeln output;

import core.thread;

import gdk.RGBA;

import glib.Date; //For some reason the gstreamer gtkd code will not compile without glib.Date being included in this project

import gstinterfaces.VideoOverlay;

import gstreamer.Bus;
import gstreamer.Element;
import gstreamer.ElementFactory;
import gstreamer.gstreamer;
import gstreamer.Message;

import gtk.Button;
import gtk.EventBox;
import gtk.Grid;
import gtk.Image;
import gtk.Label;
import gtk.Range;
import gtk.Scale;
import gtk.ScrolledWindow;
import gtk.Viewport;

import kav.Controls.VideoScreen;
import kav.DataStructures.Library;
import kav.Include.Functions;
import kav.Windows.Fullscreen;

import std.file:exists;
import std.string:format;

public final class VideoControl : Grid
{

public:

	shared static bool isPlaying = false;
	shared static bool isFullscreen = false; //Is shared with HidePause and HideTitle threads in VideoScreen

	this()
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

		_vsScreen = new VideoScreen(&playPause);
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
		
		_btnFullscreen = new Button("Fullscreen", &btnFullscreen_Clicked, false);
		_btnFullscreen.setHalign(GtkAlign.END);
		_btnFullscreen.setSensitive(false);
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

	~this()
	{
		debug output(__FUNCTION__);
		//Make sure everything closes in an orderly fashion.
		//Stop the video
		_elSource.setState(GstState.NULL);
		isPlaying = false;
		
		//Make sure the update elapsed time thread is dead
		if (_updateElapsedTimeThread)
		{
			_updateElapsedTimeThread.join(false);
			_updateElapsedTimeThread = null;
		}

		//Finally kill elSource
		_elSource.destroy();
		_elSource = null;
	}

	void addOverlays()
	{
		debug output(__FUNCTION__);
		_vsScreen.addOverlays();
	}

	void loadVideo(Library currentVideo, bool startPlaying)
	{
		debug output(__FUNCTION__);
		//Always stop current video before playing another as otherwise can end up with two videos playing at once
		unloadVideo();

		//Get the spinner going
		_vsScreen.showSpinner();

		//Load the text for the video
		loadVideoDetails(currentVideo);

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
		_voOverlay.setWindowHandle(_vsScreen.getDrawingWindowID());
		
		//Create playbin element and link to videosink
		_elSource = ElementFactory.make("playbin", "playBin");
		_elSource.setProperty("video-sink", cast(ulong)elVideoSink.getElementStruct());

		//Add a message watch to the video
		_elSource.getBus().addWatch(&elSource_Watch);

		GstState current;
		GstState pending;
		string localFileName = Functions.getLocalFileName(currentVideo.mp4);
		string totalTime;

		//If file is saved locally then load it, otherwise stream it
		if (exists(localFileName))
		{
			_elSource.setProperty("uri", "file://" ~ localFileName);
		}
		else
		{
			_elSource.setProperty("uri", currentVideo.mp4);
		}

		//Get the video buffered and ready to play
		_elSource.setState(GstState.PAUSED);
		_elSource.getState(current, pending, _pointOneSecond);
		
		//While loading keep the UI going - refresh every 0.1 seconds until video reports it's ready
		while (current != GstState.PAUSED)
		{
			Functions.refreshUI();
			_elSource.getState(current, pending, _pointOneSecond);
		}
		
		//Now that video is ready, can query the length and set the total time of the scale
		//Return in seconds as that's way more managable
		_maxRange = _elSource.queryDuration() / _oneSecond;
		 
		_sclPosition.setRange(0, _maxRange);
		
		//Write the total time to lblTotalTime
		totalTime = format("%s:%02s", cast(int)(_maxRange / 60) % 60, cast(int)_maxRange % 60);
		_lblTotalTime.setText(totalTime);
		_lblCurrentTime.setText("0:00");
		
		//Finally re-enable the buttons
		_btnPlay.setSensitive(true);
		_btnFullscreen.setSensitive(true);
		_sclPosition.setSensitive(true);
		_vsScreen.setEnabled(true);

		//And get rid of the spinner
		_vsScreen.hideSpinner();

		if (startPlaying)
		{
			play();
		}
	}
	
	void startContinuousPlayMode(void delegate() playNextVideoMethod)
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = true;
		playNextVideo = playNextVideoMethod;
	}

	void stopContinuousPlayMode()
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = false;
		playNextVideo = null;
	}

	void unloadVideo()
	{
		debug output(__FUNCTION__);
		if (_elSource)
		{
			//Stop the video
			_elSource.setState(GstState.NULL);
			isPlaying = false;
			
			//Make sure the update elapsed time thread is dead
			if (_updateElapsedTimeThread)
			{
				_updateElapsedTimeThread.join(false);
				_updateElapsedTimeThread = null;
			}
			
			//Reset the UI
			_btnPlay.setImage(_imgPlay);
			_sclPosition.setValue(0);
			_btnPlay.setSensitive(false);
			_sclPosition.setSensitive(false);
			_btnFullscreen.setSensitive(false);
			_vsScreen.setEnabled(false);
			
			_lblTitle.setText("");
			_lblDescription.setText("");
			_lblTotalTime.setText("");
			_lblCurrentTime.setText("");
			
			//Finally kill elSource
			_elSource.destroy();
			_elSource = null;
		}
	}

private:

	immutable uint	_oneSecond = 1000000000;
	immutable uint	_pointOneSecond = 100000000;

	Button			_btnFullscreen;
	Button			_btnPlay;
	EventBox		_ebVideo;
	Element			_elSource;
	Image			_imgPause;
	Image			_imgPlay;
	bool			_isContinuousPlay = false;
	Label			_lblCurrentTime;
	Label			_lblDescription;
	Label			_lblTitle;
	Label			_lblTotalTime;
	double			_maxRange;
	Scale			_sclPosition;
	VideoOverlay	_voOverlay;
	VideoScreen		_vsScreen;
	Thread			_updateElapsedTimeThread;

	void btnFullscreen_Clicked(Button)
	{
		debug output(__FUNCTION__);
		Fullscreen fullScreen = new Fullscreen(_vsScreen, &exitFullscreen);
		isFullscreen = true;
	}

	void btnPlay_Clicked(Button)
	{
		debug output(__FUNCTION__);
		playPause();
	}

	void callNextVideo()
	{
		debug output(__FUNCTION__);
		//Need to call PlayNextVideo from a new thread, so that the Play thread can join back to main thread when unloading video.
		playNextVideo();
	}

	bool elSource_Watch(Message message)
	{
		debug output(__FUNCTION__);
		scope(failure) return false; //Kill the watch if something goes horribly wrong.

		switch (message.type)
		{
			case GstMessageType.EOS: //End of video, either stop or load the next video depending on isContinuousPlay
				pause();
				
				//Seek but don't change sclPosition, so if user clicks play the video will start again, but still looks like it's finished
				seekTo(0);
				
				if (_isContinuousPlay)
				{
					//Call next video from another thread, make sure this watch doesn't get kept going forever
					Thread callNextVideoThread = new Thread(&callNextVideo);
					callNextVideoThread.start();
					callNextVideoThread = null;
				}
				
				return false;
				break;
				
			case GstMessageType.ERROR:
				isPlaying = false;
				return false;
				break;
				
			default:
				break;
		}
		
		return true;
	}

	void exitFullscreen()
	{
		debug output(__FUNCTION__);
		_vsScreen.hideTitle();
		_vsScreen.reparent(_ebVideo);
		isFullscreen = false;
	}

	void loadVideoDetails(Library currentVideo)
	{
		debug output(__FUNCTION__);
		//Get the authors (if there are any)
		string authors;
		
		if (currentVideo.authorNames.length > 0)
		{
			foreach (string author; currentVideo.authorNames)
			{
				authors ~= author;
				authors ~= ", ";
			}
			//Cut off trailing ", "
			authors.length = authors.length - 2;
		}
		
		_lblTitle.setText(currentVideo.title);
		
		//Add authors and date added to description
		_lblDescription.setText(currentVideo.description ~ "\n\nAuthor(s): " ~ authors ~ "\n\nDate Added: " ~ currentVideo.dateAdded.date.toString());
		
		//If in fullscreen mode show the video title
		if (isFullscreen)
		{
			_vsScreen.showTitle(currentVideo.title);
		}
	}

	void pause()
	{
		debug output(__FUNCTION__);
		_elSource.setState(GstState.PAUSED);
		_btnPlay.setImage(_imgPlay);
		
		isPlaying = false;
		
		_updateElapsedTimeThread.join();
		_updateElapsedTimeThread = null;
	}

	void play()
	{
		debug output(__FUNCTION__);
		//Get the video playing
		_elSource.setState(GstState.PLAYING);
		_btnPlay.setImage(_imgPause);
		isPlaying = true;
		
		//Add the loop to update the elapsed time on it's own thread
		_updateElapsedTimeThread = new Thread(&updateElapsedTime);
		_updateElapsedTimeThread.start();
	}

	void delegate() playNextVideo;
	
	void playPause()
	{
		debug output(__FUNCTION__);
		isPlaying ? pause() : play();
	}

	bool sclPosition_ChangeValue(GtkScrollType scrollType, double position, Range)
	{
		debug output(__FUNCTION__);
		if (scrollType == GtkScrollType.JUMP)
		{
			//Don't allow seeking past end of video
			if (position > _maxRange)
			{
				position = _maxRange;
			}
			
			seekTo(position);
		}
		
		return false;
	}

	void seekTo(double seconds)
	{
		debug output(__FUNCTION__);
		long nanoSeconds = cast(long)seconds * _oneSecond;
		//Pause();
		_elSource.seek(nanoSeconds);
		
	}

	void updateElapsedTime()
	{
		debug output(__FUNCTION__);
		//This thread will self destruct when IsPlaying is set to false
		long position;
		double positionInSeconds;
		string currentTime;

		while(isPlaying)
		{
			//Swallow any queryPosition errors
			if (_elSource.queryPosition(GstFormat.TIME, position))
			{
				//Get position in seconds for use in setting the scale position
				positionInSeconds = position / _oneSecond;
				
				//Format the position into m:ss format (don't think there are any videos even near an hour long, so don't worry about hours for now)
				currentTime = format("%s:%02s", cast(int)(positionInSeconds / 60) % 60, cast(int)positionInSeconds % 60);
				
				//Move the position indicator
				_sclPosition.setValue(positionInSeconds);
				
				//Change the displayed time
				_lblCurrentTime.setText(currentTime);
			}

			//Time updated, now wait half a second to update it again
			Thread.sleep(dur!("msecs")(500));
		}
	}
}