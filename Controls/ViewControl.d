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
module KhanAcademyViewer.Controls.ViewControl;

import gtk.ScrolledWindow;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Controls.VideoControl;
import KhanAcademyViewer.Workers.SettingsWorker;
import KhanAcademyViewer.DataStructures.Settings;

protected abstract class ViewControl
{
	public void PreloadCategory(string);
	public bool GetNextVideo(out Library, out string);
	protected ScrolledWindow _scrollParent;
	protected ScrolledWindow _scrollChild;
	protected Library _completeLibrary;
	protected VideoControl _vcVideo;
	protected Settings _settings;

	protected void LoadVideo(Library currentVideo, string path, bool startPlaying)
	{
		debug output(__FUNCTION__);
		assert(currentVideo.MP4 != "", "No video data! There should be as this item is at the end of the tree");
		
		_vcVideo.LoadVideo(currentVideo, startPlaying);

		//Continuous play?
		if (_settings && _settings.ContinuousPlay)
		{
			_vcVideo.StartContinuousPlayMode(&PlayNextVideo);
		}
		else
		{
			_vcVideo.StopContinuousPlayMode();
		}

		//Save current treepath to settings
		_settings.LastSelectedCategory = path;
		SettingsWorker.SaveSettings(_settings);
	}

	protected void PlayNextVideo()
	{
		debug output(__FUNCTION__);
		string path;
		Library nextVideo;
		
		//If there is a next video start playing it
		//Otherwise just do nothing to end the playlist
		if (GetNextVideo(nextVideo, path))
		{
			LoadVideo(nextVideo, path, true);
		}
	}
}