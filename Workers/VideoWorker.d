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

import glib.Date;

import gtk.DrawingArea;
import gtk.Button;
import gtk.Image;
import gtk.Scale;

import gdk.X11;

import gobject.Value;

import gstreamer.gstreamer;
import gstreamer.Element;
import gstreamer.ElementFactory;
import gstreamer.Bus;

import gstinterfaces.VideoOverlay;

class VideoWorker
{
	Element _videoSink;
	Element _source;
	VideoOverlay _overlay;
	bool _isPlaying;

	this(ref DrawingArea videoArea, ref Button btnPlay, ref Image imgPlay, ref Scale sclPosition, string fileName)
	{
		//Very first step is to init gstreamer, need some fake args then just call .init to get it going
		string[] args;
		GStreamer.init(args);

		_videoSink = ElementFactory.make("xvimagesink", "videosink");

		//Link the video sink to the drawingArea
		_overlay = new VideoOverlay(_videoSink);
		_overlay.setWindowHandle(X11.windowGetXid(videoArea.getWindow()));

		//Create a playbin element and point it at the selected video
		_source = ElementFactory.make("playbin", "playBin");
		_source.setProperty("uri", fileName);

		//Work around to .setProperty not accepting Element type directly
		Value val = new Value();
		val.init(GType.OBJECT);
		val.setObject(_videoSink.getElementStruct());
		_source.setProperty("video-sink", val);

		//Get the gstreamer bus so can read async messages
		Bus videoBus = _source.getBus();

		//TODO
		//Create two threads, one to update the scale position every second, the other to change the btnPlay image back to play (i.e. stopped) when reaching EOF

		//Get first frame displayed and video ready to go
		_source.setState(GstState.PAUSED);

		//Wait here until video state changes to paused, this is necessary as length of video cannot be retrieved before video is ready
		videoBus.timedPopFiltered(GST_CLOCK_TIME_NONE, GstMessageType.ASYNC_DONE);

		//TODO call back code will go here to join back onto UI thread

		_isPlaying = false;
	}

	~this()
	{
		//Stop and get rid of video and all resources
		_source.setState(GstState.NULL);
		_source.destroy();
		_videoSink.destroy();
	}

	public void Play()
	{
		_source.setState(GstState.PLAYING);
		_isPlaying = true;
	}

	public void Pause()
	{
		_source.setState(GstState.PAUSED);
		_isPlaying = false;
	}

	public bool getIsPlaying()
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
}