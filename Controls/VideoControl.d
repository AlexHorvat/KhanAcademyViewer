/*
 * VideoControl.d
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
import kav.DataStructures.Settings;
import kav.Include.Functions;
import kav.Windows.Fullscreen;

import pango.PgFontDescription;

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

		//For some reason if the images are created new everytime, or held in an non-immutable variable the program eventually
		//crashes, I suspect some GC evilness and the only way I can find to fix this is to make the images immutable.
		_playImage = cast(immutable) new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);
		_pauseImage = cast(immutable) new Image(StockID.MEDIA_PAUSE, GtkIconSize.BUTTON);

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
		
		_lblTitle = new Label("", false);
		_lblTitle.setMaxWidthChars(50);
		_lblTitle.setSizeRequest(-1, 60);
		_lblTitle.overrideFont(new PgFontDescription("", 14));
		_lblTitle.setLineWrap(true);
		super.attach(_lblTitle, 0, 0, 4, 1);
		
		_ebVideo = new EventBox();
		_ebVideo.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(0, 0, 0));
		_ebVideo.setSizeRequest(600, 400);
		_ebVideo.setVexpand(true);
		_ebVideo.setHexpand(true);
		super.attach(_ebVideo, 0, 1, 4, 1);

		_vsScreen = new VideoScreen(&playPause);
		_ebVideo.add(_vsScreen);
		
		_btnPlay = new Button(StockID.MEDIA_PLAY, &btnPlay_Clicked, true);
		_btnPlay.setHalign(GtkAlign.START);
		_btnPlay.setSensitive(false);
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
		_lblDescription.setLineWrap(true);
		
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

	/*
	 * Passing the addOverlays call through to VideoScreen.d
	 */
	void addOverlays()
	{
		debug output(__FUNCTION__);
		_vsScreen.addOverlays();
	}

	/*
	 * Get gstreamer to load a video (either from local storage or a url), buffer it and basically be ready to play.
	 * 
	 * Params:
	 * currentVideo = the library with the url to play. The url is converted to a local file name to check if that exists, if it doesn't the url is played.
	 * startPlaying = whether to start playing straight away, or just get the video ready to play.
	 * useGPU = whether to use xvimagesink (gpu accelerated) or ximagesink (cpu based) playback, xvimagesink sometimes has compatibility issues, and ximagesink uses a lot of cpu.
	 */
	void loadVideo(Library currentVideo, bool startPlaying, bool useGPU)
	{
		debug output(__FUNCTION__);
		//Always stop current video before playing another as otherwise can end up with two videos playing at once
		unloadVideo(); //Try moving this???

		//Get the spinner going before buffering starts when first loading video - otherwise there is a time where it
		//looks like nothing is happening
		_vsScreen.showSpinner();

		//Load the text for the video
		loadVideoDetails(currentVideo);

		//Spinner's going so get the video ready to play
		if (!GStreamer.isInitialized)
		{
			string[] args;
			GStreamer.init(args);
		}
		
		//Allow switching between CPU and GPU imagesink as sometimes one will work better than the other
		Element elVideoSink = ElementFactory.make(useGPU ? "xvimagesink" : "ximagesink", "videosink");
		
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

		//Normally the spinner is hidden when buffering is complete - but when offline there is no buffering so the spinner is not hidden
		_vsScreen.hideSpinner();

		if (startPlaying)
		{
			play();
		}
	}

	/*
	 * Set boolean for continuous play to true, thus enabling continuous play.
	 * 
	 * Params:
	 * playNextVideoMethod = the method to be called which will find and load the next video.
	 */
	void startContinuousPlayMode(void delegate() playNextVideoMethod)
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = true;
		playNextVideo = playNextVideoMethod;
	}

	/*
	 * Stop continuous play by setting the boolean to false.
	 */
	void stopContinuousPlayMode()
	{
		debug output(__FUNCTION__);
		_isContinuousPlay = false;
		playNextVideo = null;
	}

	/*
	 * Unload all the video related objects, this is important for stopping crashes and more than one video playing at a time.
	 */
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

			//Reset UI to base state
			_btnPlay.setImage(cast(Image)_playImage);
			_btnPlay.setSensitive(false);
			_sclPosition.setValue(0);
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
	immutable Image _playImage;
	immutable Image _pauseImage;

	Button			_btnFullscreen;
	Button			_btnPlay;
	EventBox		_ebVideo;
	Element			_elSource;
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

	/*
	 * Create a fullscreen object and pass the video off to it.
	 */
	void btnFullscreen_Clicked(Button)
	{
		debug output(__FUNCTION__);
		Fullscreen fullScreen = new Fullscreen(_vsScreen, &exitFullscreen);
		isFullscreen = true;
	}

	/*
	 * Start playing the video.
	 */
	void btnPlay_Clicked(Button)
	{
		debug output(__FUNCTION__);
		playPause();
	}

	/*
	 * When in continuous play mode this is called to call the find and load next video method.
	 * The reason this is seperate is so that it can be called on a new thread, the reason it's called on a new thread is so that the original
	 * video can close itself properly, otherwise two videos (or more) end up playing at once.
	 */
	void callNextVideo()
	{
		debug output(__FUNCTION__);
		playNextVideo();
	}

	/*
	 * Handle messages coming from the gstreamer video bus.
	 * 
	 * Params:
	 * message = a message from the bus.
	 * 
	 * Returns: a boolean which if set to false kills the bus messaging system.
	 */
	bool elSource_Watch(Message message)
	{
		//debug output(__FUNCTION__);
		scope(failure) return false; //Kill the watch if something goes horribly wrong.

		switch (message.type)
		{
			case GstMessageType.BUFFERING:
				//When buffering starts show the spinner, then once buffering hits 100% hide the spinner.
				int bufferPercent;

				_vsScreen.showSpinner();

				message.parseBuffering(bufferPercent);

				if (bufferPercent == 100)
				{
					_vsScreen.hideSpinner();
				}

				break;

			case GstMessageType.EOS: //End of video, either stop or load the next video depending on isContinuousPlay
				pause();
				
				if (_isContinuousPlay)
				{
					//Call next video from another thread, make sure this watch doesn't get kept going forever
					Thread callNextVideoThread = new Thread(&callNextVideo);
					callNextVideoThread.start();
					callNextVideoThread = null;

					return false;
				}
				else
				{
					//Seek but don't change sclPosition, so if user clicks play the video will start again, but still looks like it's finished
					//Keep the watch alive if video has just ended - otherwise if it's played again the watch is not active
					seekTo(0);

					return true;
				}
				
				//return false;
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

	/*
	 * Destroy the fullscreen object and move the video screen back into the main program window.
	 */
	void exitFullscreen()
	{
		debug output(__FUNCTION__);
		_vsScreen.hideTitle();
		_vsScreen.reparent(_ebVideo);
		isFullscreen = false;
	}

	/*
	 * Fill out all the text fields in the main window with video details like the title and author.
	 * 
	 * Params:
	 * currentVideo = the details to display are taken from this library object.
	 */
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

	/*
	 * Pause the video.
	 * Make sure the elapsed time thread joins so that there are no wierd side effects.
	 */
	void pause()
	{
		debug output(__FUNCTION__);
		_elSource.setState(GstState.PAUSED);
		isPlaying = false;

		_btnPlay.setImage(cast(Image)_playImage);
				
		_updateElapsedTimeThread.join();
		_updateElapsedTimeThread = null;
	}

	/*
	 * Play the video.
	 * Create a new elapsed time thread which keeps track of the video's current time, this needs to be on it's own thread.
	 */
	void play()
	{
		debug output(__FUNCTION__);
		//Get the video playing
		_elSource.setState(GstState.PLAYING);
		isPlaying = true;

		_btnPlay.setImage(cast(Image)_pauseImage);
				
		//Add the loop to update the elapsed time on it's own thread
		_updateElapsedTimeThread = new Thread(&updateElapsedTime);
		_updateElapsedTimeThread.start();
	}

	/*
	 * Placeholder for the method to find and play the next video when in continuous play mode.
	 */
	void delegate() playNextVideo;

	/*
	 * Play or pause the video depending on whether currently playing.
	 */
	void playPause()
	{
		debug output(__FUNCTION__);
		isPlaying ? pause() : play();
	}

	/*
	 * When the user drags the scale position pointer, call the function to set the video to this position.
	 */
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

	/*
	 * Set the video to the selected position.
	 * 
	 * Params:
	 * seconds = the position to set the video to in seconds.
	 */
	void seekTo(double seconds)
	{
		debug output(__FUNCTION__);
		long nanoSeconds = cast(long)seconds * _oneSecond;

		_elSource.seek(nanoSeconds);
	}

	/*
	 * Update the current video time every half second. This is output to the current time label.
	 * Must be run on it's own thread as otherwise it'll lock the main thread.
	 */
	void updateElapsedTime()
	{
		//NOTE:
		//Might be worth using LLVM/LDC to compile this, then can use LLDB to debug - might be a better debugger.
		//Or maybe install a windows VM with VS2010, GTK+ for windows and VisualD and try and use it's debugger.


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