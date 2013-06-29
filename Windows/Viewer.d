//
//  Viewer.d
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

module KhanAcademyViewer.Windows.Viewer;

alias std.stdio.writeln output;

import std.c.process;
import std.concurrency;

import core.thread;

import gtk.Builder;
import gtk.Widget;
import gtk.Window;
import gtk.MenuItem;
import gtk.ScrolledWindow;
import gtk.Label;
import gtk.DrawingArea;
import gtk.Button;
import gtk.Image;
import gtk.Scale;
import gtk.ButtonBox;
import gtk.Main;
import gtk.Fixed;
import gtk.EventBox;
import gtk.RadioMenuItem;
import gtk.CheckMenuItem;

import gdk.RGBA;
import gdk.Event;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.Settings;
import KhanAcademyViewer.Include.Enums;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Workers.DownloadWorker;
import KhanAcademyViewer.Workers.VideoWorker;
import KhanAcademyViewer.Workers.SettingsWorker;
import KhanAcademyViewer.Windows.Loading;
import KhanAcademyViewer.Windows.DownloadManager;
import KhanAcademyViewer.Windows.About;
import KhanAcademyViewer.Include.Functions;
import KhanAcademyViewer.Controls.TreeViewControl;
import KhanAcademyViewer.Controls.FlowViewControl;
import KhanAcademyViewer.Controls.ViewControl;

//TODO
//Only save settings on program exit, otherwise work with the variable

public final class Viewer
{
	private immutable string _gladeFile = "./Windows/Viewer.glade";
	
	private Library _completeLibrary;
	private Settings _settings;

	//UI controls
	private Window _wdwViewer;
	private ScrolledWindow _scrollParent;
	private ScrolledWindow _scrollChild;
	private MenuItem _miAbout;
	private MenuItem _miDownloadManager;
	private MenuItem _miExit;
	private Label _lblVideoTitle;
	private Label _lblVideoDescription;
	private EventBox _eventVideo;
	private Fixed _fixedVideo;
	private DrawingArea _drawVideo;
	private Label _lblCurrentTime;
	private Label _lblTotalTime;
	private VideoWorker _videoWorker;
	private Button _btnPlay;
	private Button _btnFullscreen;
	private Scale _sclPosition;
	private ButtonBox _bboxBreadCrumbs;
	private Loading _loadingWindow;
	private RadioMenuItem _imiFlow;
	private RadioMenuItem _imiTree;
	private CheckMenuItem _imiOffline;
	private CheckMenuItem _imiKeepPosition;
	private CheckMenuItem _imiContinuousPlay;
	private ViewControl _vcView;
	private DownloadManager _downloadManager;
	private About _about;

	public this()
	{
		debug output(__FUNCTION__);
		SetupWindow();
		LoadSettings();
		DownloadLibrary();
		LoadLibraryFromStorage();
		SetOnlineOrOffline();
		KillLoadingWindow();
	}

	private void PreloadCategory()
	{
		debug output(__FUNCTION__);
		if (_settings && _settings.KeepPosition && _settings.LastSelectedCategory != "")
		{
			_vcView.PreloadCategory(_settings.LastSelectedCategory);
		}
	}

	private void LoadSettings()
	{
		debug output(__FUNCTION__);
		_settings = SettingsWorker.LoadSettings();

		//Set menu items
		_imiOffline.setActive(_settings.IsOffline);
		_imiKeepPosition.setActive(_settings.KeepPosition);
		_imiContinuousPlay.setActive(_settings.ContinuousPlay);
	}

	private bool HasInternetConnection()
	{
		debug output(__FUNCTION__);
		bool onwards = false;
		bool hasInternetConnection;

		_loadingWindow.UpdateStatus("Checking for internet connection");
		_loadingWindow.DataDownloadedVisible = false;
		spawn(&DownloadWorker.HasInternetConnection);
		
		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(bool hasConnection)
				{
					hasInternetConnection = hasConnection;
					onwards = true;
				});
			
			RefreshUI();
		}

		return hasInternetConnection;
	}

	private void SetupWindow()
	{
		debug output(__FUNCTION__);
		Builder windowBuilder = new Builder();
		RGBA rgbaBlack = new RGBA(0,0,0);
		Image imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);

		windowBuilder.addFromFile(_gladeFile);

		//Load all controls from glade file, link to class level variables
		_wdwViewer = cast(Window)windowBuilder.getObject("wdwViewer");
		_wdwViewer.setTitle("Khan Academy Viewer");
		_wdwViewer.addOnDestroy(&wdwViewer_Destroy);

		_scrollParent = cast(ScrolledWindow)windowBuilder.getObject("scrollParent");

		_scrollChild = cast(ScrolledWindow)windowBuilder.getObject("scrollChild");

		_lblVideoTitle = cast(Label)windowBuilder.getObject("lblVideoTitle");
		_lblVideoTitle.setLineWrap(true);

		_lblVideoDescription = cast(Label)windowBuilder.getObject("lblVideoDescription");
		_lblVideoDescription.setLineWrap(true);

		_eventVideo = cast(EventBox)windowBuilder.getObject("eventVideo");
		_eventVideo.overrideBackgroundColor(GtkStateFlags.NORMAL, rgbaBlack);

		_fixedVideo = cast(Fixed)windowBuilder.getObject("fixedVideo");
		_fixedVideo.addOnSizeAllocate(&fixedVideo_SizeAllocate);

		_drawVideo = cast(DrawingArea)windowBuilder.getObject("drawVideo");

		_btnPlay = cast(Button)windowBuilder.getObject("btnPlay");
		_btnPlay.setImage(imgPlay);

		_btnFullscreen = cast(Button)windowBuilder.getObject("btnFullscreen");

		_sclPosition = cast(Scale)windowBuilder.getObject("sclPosition");

		_lblCurrentTime = cast(Label)windowBuilder.getObject("lblCurrentTime");

		_lblTotalTime = cast(Label)windowBuilder.getObject("lblTotalTime");

		_bboxBreadCrumbs = cast(ButtonBox)windowBuilder.getObject("bboxBreadCrumbs");

		_imiFlow = cast(RadioMenuItem)windowBuilder.getObject("imiFlow");
		_imiFlow.addOnButtonRelease(&imiFlow_ButtonRelease);

		_imiTree = cast(RadioMenuItem)windowBuilder.getObject("imiTree");
		_imiTree.addOnButtonRelease(&imiTree_ButtonRelease);
		//Link imiFlow and imiTree together so that they work like radio buttons
		_imiTree.setGroup(_imiFlow.getGroup());

		_imiOffline = cast(CheckMenuItem)windowBuilder.getObject("imiOffline");
		_imiOffline.addOnButtonRelease(&imiOffline_ButtonRelease);

		_imiKeepPosition = cast(CheckMenuItem)windowBuilder.getObject("imiKeepPosition");
		_imiKeepPosition.addOnButtonRelease(&imiKeepPosition_ButtonRelease);

		_imiContinuousPlay = cast(CheckMenuItem)windowBuilder.getObject("imiContinuousPlay");
		_imiContinuousPlay.addOnButtonRelease(&imiContinuousPlay_ButtonRelease);

		_miDownloadManager = cast(MenuItem)windowBuilder.getObject("miDownloadManager");
		_miDownloadManager.addOnButtonRelease(&miDownloadManager_ButtonRelease);

		_miAbout = cast(MenuItem)windowBuilder.getObject("miAbout");
		_miAbout.addOnButtonRelease(&miAbout_ButtonRelease);

		_miExit = cast(MenuItem)windowBuilder.getObject("miExit");
		_miExit.addOnButtonRelease(&miExit_ButtonRelease);

		_wdwViewer.showAll();
		RefreshUI();
	}

	private void SetOnlineOrOffline()
	{
		debug output(__FUNCTION__);
		//This is only called from the constructor - which also checks for internet connection when loading
		//so no need to double check
		_settings.IsOffline ? SetOffline : SetOnline(false);
	}

	private bool imiKeepPosition_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		_settings.KeepPosition = !cast(bool)_imiKeepPosition.getActive();
		SettingsWorker.SaveSettings(_settings);

		return false;
	}

	private bool imiContinuousPlay_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		//_settings.ContinuousPlay = !cast(bool)_imiContinuousPlay.getActive();
		//SettingsWorker.SaveSettings(_settings);

		if(_imiContinuousPlay.getActive())
		{
			_settings.ContinuousPlay = false;

			if (_videoWorker)
			{
				_videoWorker.StopContinuousPlayMode();
			}
		}
		else
		{
			_settings.ContinuousPlay = true;

			if (_videoWorker)
			{
				_videoWorker.StartContinuousPlayMode(&PlayNextVideo);
			}
		}

		SettingsWorker.SaveSettings(_settings);

		return false;
	}

	private bool imiOffline_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		//Clear the last selected category to stop bugs - online and offline libraries are different sizes usually
		//so the treepath stored here would be pointing to a different category
		_settings.LastSelectedCategory = "";
		SettingsWorker.SaveSettings(_settings);

		_imiOffline.getActive() ? SetOnline(true) : SetOffline();

		return false;
	}

	private void SetOnline(bool checkForInternetConnection)
	{
		debug output(__FUNCTION__);

		if (checkForInternetConnection)
		{
			_loadingWindow = new Loading();
			scope(exit) _loadingWindow.destroy();

			RefreshUI();

			if (!HasInternetConnection())
			{
				_imiOffline.setActive(true);
				return;
			}
		}

		_settings.IsOffline = false;
		SettingsWorker.SaveSettings(_settings);

		_imiOffline.setActive(false);

		_miDownloadManager.setSensitive(true);

		//Enable full library
		_completeLibrary = LibraryWorker.LoadLibrary();
		LoadNavigation();
	}

	private void SetOffline()
	{
		debug output(__FUNCTION__);
		bool onwards = false;

		_imiOffline.setActive(true);

		_settings.IsOffline = true;
		SettingsWorker.SaveSettings(_settings);

		_miDownloadManager.setSensitive(false);

		//Only show video's which are downloaded, need to change _completeLibrary to reflect this
		//Make async as might be slow on older computers
		spawn(&LibraryWorker.LoadOfflineLibrary);

		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(shared Library offlineLibrary)
				{
					_completeLibrary = cast(Library)offlineLibrary;
					onwards = true;
				});
			
			RefreshUI();
		}

		LoadNavigation();
	}

	private bool imiFlow_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		_settings.ViewModeSetting = ViewMode.Flow;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();

		return false;
	}

	private bool imiTree_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		_settings.ViewModeSetting = ViewMode.Tree;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();

		return false;
	}

	private void DownloadLibrary()
	{
		debug output(__FUNCTION__);
		bool onwards, needToDownLoadLibrary;

		//Show the loading window and make sure it's loaded before starting the download
		_loadingWindow = new Loading();
		RefreshUI();

		if (_settings.IsOffline)
		{
			//Set offline, don't bother checking library
			return;
		}

		if (!HasInternetConnection())
		{
			//No internet connection, don't download library, set to offline mode and clear last selected category
			_settings.IsOffline = true;
			_settings.LastSelectedCategory = "";
			SettingsWorker.SaveSettings(_settings);
		}

		//Async check if need to download library (async because sometimes it's really slow)
		onwards = false;
		_loadingWindow.UpdateStatus("Checking for library updates");
		spawn(&DownloadWorker.NeedToDownloadLibrary);

		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(bool refreshNeeded)
				{
					needToDownLoadLibrary = refreshNeeded;
					onwards = true;
				});

			RefreshUI();
		}

		//If library needs to downloaded do another async call to DownloadLibrary
		//keep _loadingWindow updated with progress
		if (needToDownLoadLibrary)
		{
			bool downloadSuccess;
			onwards = false;
			_loadingWindow.UpdateStatus("Downloading library");
			_loadingWindow.DataDownloadedVisible = true;
			spawn(&DownloadWorker.DownloadLibrary);

			while (!onwards)
			{
				receiveTimeout(
					dur!"msecs"(250),
					(bool quit)
					{
						//Download has finished
						downloadSuccess = quit;
						onwards = true;
					},
					(ulong amountDownloaded)
					{
						//Update the loading window with amount downloaded
						_loadingWindow.UpdateAmountDownloaded(amountDownloaded);
					});
				
				RefreshUI();
			}

			if (!downloadSuccess)
			{
				output("Could not download library");
				exit(1);
			}
		}
	}

	private void LoadLibraryFromStorage()
	{
		debug output(__FUNCTION__);
		//Maybe make this async in the future
		//Seems to be difficult to pass the loaded library around async
		//If passed in a message it locks the sending thread
		//And if passed as a shared variable it is always null in this thread
		//even after being set on the loading thread
		_loadingWindow.UpdateStatus("Processing library");
		_loadingWindow.DataDownloadedVisible = false;

		//The library takes a few seconds to write to disc after being downloaded
		//loop and wait until it shows up, otherwise cannot load library and program
		//crashes
		while(!LibraryWorker.LibraryFileExists())
		{
			RefreshUI();
			Thread.sleep(dur!"msecs"(250));
		}

		_completeLibrary = LibraryWorker.LoadLibrary();
	}

	private void ClearVideo()
	{
		debug output(__FUNCTION__);

		//Reset all video details
		_lblVideoTitle.setText("");
		_lblVideoDescription.setText("");
		_lblTotalTime.setText("");
		_lblCurrentTime.setText("");

		//And the video itself
		_videoWorker.ResetVideo();
	}

	private void LoadNavigation()
	{
		debug output(__FUNCTION__);
		//Stop any playing video
		if (_videoWorker)
		{
			ClearVideo();
		}

		if (_vcView)
		{
			_vcView.destroy();
		}

		final switch (_settings.ViewModeSetting)
		{
			case ViewMode.Flow:
				_imiFlow.setActive(true);
				_vcView = new FlowViewControl(_scrollParent, _scrollChild, _bboxBreadCrumbs, _completeLibrary, &LoadVideo);
				break;

			case ViewMode.Tree:
				_imiTree.setActive(true);
				_vcView = new TreeViewControl(_scrollParent, _scrollChild, _completeLibrary, &LoadVideo);
				break;
		}

		PreloadCategory();
	}

	private void KillLoadingWindow()
	{
		debug output(__FUNCTION__);
		_loadingWindow.destroy();
	}
	
	private void LoadVideo(Library currentVideo, string path)
	{
		debug output(__FUNCTION__);
		assert(currentVideo.MP4 != "", "No video data! There should be as this item is at the end of the tree");

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

		_lblVideoTitle.setText(currentVideo.Title);

		//Add authors and date added to description
		_lblVideoDescription.setText(currentVideo.Description ~ "\n\nAuthor(s): " ~ authors ~ "\n\nDate Added: " ~ currentVideo.DateAdded.date.toString());

		//Create a new video worker if needed
		if (!_videoWorker)
		{
			_videoWorker = new VideoWorker(_fixedVideo, _drawVideo, _btnPlay, _btnFullscreen, _sclPosition, _lblCurrentTime, _lblTotalTime);
		}

		//Continuous play?
		if (_settings && _settings.ContinuousPlay)
		{
			_videoWorker.StartContinuousPlayMode(&PlayNextVideo);
		}
		else
		{
			_videoWorker.StopContinuousPlayMode();
		}

		_videoWorker.LoadVideo(currentVideo.MP4);

		//Save current treepath to settings
		_settings.LastSelectedCategory = path;
		SettingsWorker.SaveSettings(_settings);
	}

	private void PlayNextVideo()
	{
		debug output(__FUNCTION__);
		string path;
		Library nextVideo;

		//If there is a next video start playing it
		//Otherwise just do nothing to end the playlist
		if (_vcView.GetNextVideo(nextVideo, path))
		{
			LoadVideo(nextVideo, path);
			_videoWorker.Play();
		}
	}

	private bool miAbout_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
	
		if (_about)
		{
			_about.GetWindow().present();
		}
		else
		{
			_about = new About(&DisposeAbout);
		}

		return true;
	}

	private void DisposeAbout()
	{
		debug output(__FUNCTION__);
		_about = null;
	}

	private bool miDownloadManager_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		//Stop any playing videos as it's possible to delete a video that's playing
		if (_videoWorker)
		{
			ClearVideo();
		}

		DownloadManager downloadManager = new DownloadManager();
		return true;
	}

	private bool miExit_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		exit(0);
		return true;
	}

	private void fixedVideo_SizeAllocate(GdkRectangle* newSize, Widget sender)
	{
		debug output(__FUNCTION__);
		//Need to keep drawVideo the same size as it's parent - the fixed widget
		//this has to be done manually
		_drawVideo.setSizeRequest(newSize.width, newSize.height);
	}

	private void wdwViewer_Destroy(Widget sender)
	{
		debug output(__FUNCTION__);
		exit(0);
	}
}