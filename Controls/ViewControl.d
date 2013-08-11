/**
 * 
 * ViewControl.d
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
module kav.Controls.ViewControl;

import gtk.ScrolledWindow;

import kav.DataStructures.Library;
import kav.Controls.VideoControl;
import kav.DataStructures.Settings;

public abstract class ViewControl
{

public:

	bool getNextVideo(out Library, out string);
	void preloadCategory();

protected:

	Library			_completeLibrary;
	ScrolledWindow	_scrollChild;
	ScrolledWindow	_scrollParent;
	Settings		_settings;
	VideoControl	_vcVideo;

	/**
	 * Tell VideoControl to load a video, and set (or unset) continuous play mode.
	 * Also store the currently selected path if keeping position.
	 * 
	 * Params:
	 * video = the video to load.
	 * path = the currently selected path.
	 * startPlaying = start playing the video straight away, or just buffer it.
	 */
	void loadVideo(Library video, string path, bool startPlaying)
	{
		debug output(__FUNCTION__);
		//Continuous play?
		if (_settings && _settings.continuousPlay)
		{
			_vcVideo.startContinuousPlayMode(&playNextVideo);
		}
		else
		{
			_vcVideo.stopContinuousPlayMode();
		}

		//Save current treepath to settings
		if(_settings && _settings.keepPosition)
		{
			_settings.lastSelectedCategory = path;
		}

		_vcVideo.loadVideo(video, startPlaying, _settings);
	}

	/**
	 * If not at the end of the current branch of the library, load the next video on the branch and start playing it.
	 */
	void playNextVideo()
	{
		debug output(__FUNCTION__);
		string path;
		Library nextVideo;
		
		//If there is a next video start playing it
		//Otherwise just do nothing to end the playlist
		if (getNextVideo(nextVideo, path))
		{
			loadVideo(nextVideo, path, true);
		}
	}
}