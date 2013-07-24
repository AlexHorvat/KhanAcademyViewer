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

import gtk.Widget;
import gtk.Window;
import gtk.MenuItem;
import gtk.ScrolledWindow;
import gtk.ButtonBox;
import gtk.RadioMenuItem;
import gtk.CheckMenuItem;
import gtk.SeparatorMenuItem;
import gtk.Grid;
import gtk.Menu;
import gtk.MenuBar;

import gdk.Event;

import glib.ListSG;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.Settings;
import KhanAcademyViewer.Include.Enums;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Workers.DownloadWorker;
import KhanAcademyViewer.Workers.SettingsWorker;
import KhanAcademyViewer.Windows.Loading;
import KhanAcademyViewer.Windows.DownloadManager;
import KhanAcademyViewer.Windows.About;
import KhanAcademyViewer.Include.Functions;
import KhanAcademyViewer.Controls.TreeViewControl;
import KhanAcademyViewer.Controls.FlowViewControl;
import KhanAcademyViewer.Controls.ViewControl;
import KhanAcademyViewer.Controls.VideoControl;

//TODO
//Only save settings on program exit, otherwise work with the variable

//There's a crash when in continuous play mode - once one video finishes and the next is playing if you change
//view mode the program crashes

public final class Viewer
{
	private Library _completeLibrary;
	private Settings _settings;

	//UI controls
	private Window _wdwViewer;
	private ScrolledWindow _swParent;
	private ScrolledWindow _swChild;
	private MenuItem _miDownloadManager;
	private ButtonBox _bboxBreadCrumbs;
	private Loading _loadingWindow;
	private RadioMenuItem _rmiFlow;
	private RadioMenuItem _rmiTree;
	private CheckMenuItem _cmiOffline;
	private CheckMenuItem _cmiKeepPosition;
	private CheckMenuItem _cmiContinuousPlay;
	private ViewControl _vcView;
	private DownloadManager _downloadManager;
	private About _about;
	private VideoControl _vcVideo;

	public this()
	{
		debug output(__FUNCTION__);
		SetupWindow();
		LoadSettings();
		DownloadLibrary();
		LoadLibraryFromStorage();
		_settings.IsOffline ? SetOffline : SetOnline(false); //No need to double check for internet connection
		KillLoadingWindow();
		HookUpOptionHandlers();
	}

	private void SetupWindow()
	{
		debug output(__FUNCTION__);
		//Create the window
		_wdwViewer = new Window("Khan Academy Viewer");
		_wdwViewer.setPosition(GtkWindowPosition.POS_CENTER);
		_wdwViewer.addOnDestroy(&wdwViewer_Destroy);

		//Main body grid
		Grid grdMain = new Grid();
		grdMain.insertColumn(0);
		grdMain.insertRow(0);
		grdMain.insertRow(0);
		_wdwViewer.add(grdMain);

		//Menu
		MenuBar mbMain = new MenuBar();
		grdMain.attach(mbMain, 0, 0, 1, 1);

		MenuItem miOptions = new MenuItem("_Options", true);
		mbMain.add(miOptions);

		Menu mSubOptions = new Menu();
		miOptions.setSubmenu(mSubOptions);

		ListSG lsgViewMode;
		_rmiFlow = new RadioMenuItem(lsgViewMode, "Flow View", false);
		mSubOptions.add(_rmiFlow);
				
		_rmiTree = new RadioMenuItem(_rmiFlow, "Tree View", false);
		mSubOptions.add(_rmiTree);

		SeparatorMenuItem smi1 = new SeparatorMenuItem();
		mSubOptions.add(smi1);

		_cmiOffline = new CheckMenuItem("Offline Mode", false);
		_cmiOffline.setTooltipText("Go to offline mode, you can only play videos you have downloaded.");
		mSubOptions.add(_cmiOffline);

		SeparatorMenuItem smi2 = new SeparatorMenuItem();
		mSubOptions.add(smi2);

		_cmiKeepPosition = new CheckMenuItem("Keep Position", false);
		_cmiKeepPosition.setTooltipText("Start showing the last category you watched a video in.");
		mSubOptions.add(_cmiKeepPosition);

		_cmiContinuousPlay = new CheckMenuItem("Continuous Play", false);
		_cmiContinuousPlay.setTooltipText("Play all videos in a category automatically.");
		mSubOptions.add(_cmiContinuousPlay);
				
		_miDownloadManager = new MenuItem("_Download Manager", true);
		_miDownloadManager.addOnButtonPress(&miDownloadManager_ButtonPress);
		_miDownloadManager.addOnButtonRelease(&miDownloadManager_ButtonRelease);
		mbMain.add(_miDownloadManager);
				
		MenuItem miAbout = new MenuItem("_About", true);
		miAbout.addOnButtonPress(&miAbout_ButtonPress);
		miAbout.addOnButtonRelease(&miAbout_ButtonRelease);
		mbMain.add(miAbout);

		MenuItem miExit = new MenuItem("_Exit", true);
		miExit.addOnButtonRelease(&miExit_ButtonRelease);
		mbMain.add(miExit);

		//Video selection grid
		Grid grdBody = new Grid();
		grdBody.insertColumn(0);
		grdBody.insertColumn(0);
		grdBody.insertRow(0);
		grdMain.attach(grdBody, 0, 1, 1, 1);

		Grid grdSelection = new Grid();
		grdSelection.insertColumn(0);
		grdSelection.insertColumn(0);
		grdSelection.insertRow(0);
		grdSelection.insertRow(0);
		grdBody.attach(grdSelection, 0, 0, 1, 1);

		_bboxBreadCrumbs = new ButtonBox(GtkOrientation.HORIZONTAL);
		_bboxBreadCrumbs.setLayout(GtkButtonBoxStyle.START);
		_bboxBreadCrumbs.setSizeRequest(-1, 33);
		grdSelection.attach(_bboxBreadCrumbs, 0, 0, 2, 1);
		
		_swParent = new ScrolledWindow();
		_swParent.setSizeRequest(300, 650);
		_swParent.setVexpand(true);
		grdSelection.attach(_swParent, 0, 1, 1, 1);
		
		_swChild = new ScrolledWindow();
		_swChild.setSizeRequest(300, 650);
		_swChild.setVexpand(true);
		grdSelection.attach(_swChild, 1, 1, 1, 1);

		//Video player widgets
		_vcVideo = new VideoControl();
		grdBody.attach(_vcVideo, 1, 0, 1, 1);

		_wdwViewer.showAll();

		//Widgets shown, now add the video overlays
		_vcVideo.AddOverlays();
	}

	private void HookUpOptionHandlers()
	{
		debug output(__FUNCTION__);
		//The option handlers don't play nice when being set in LoadSettings() they fire when set to active
		//and using GtkD there seems to be no way to temporarily disable the firing, so add the handlers after
		//everything is loaded.
		_rmiFlow.addOnActivate(&rmiFlow_Activate);
		_rmiTree.addOnActivate(&rmiTree_Activate);
		_cmiOffline.addOnActivate(&cmiOffline_Activate);
		_cmiKeepPosition.addOnActivate(&cmiKeepPosition_Activate);
		_cmiContinuousPlay.addOnActivate(&cmiContinuousPlay_Activate);
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
		final switch (_settings.ViewModeSetting)
		{
			case ViewMode.Flow:
				_rmiFlow.setActive(true);
				break;
				
			case ViewMode.Tree:
				_rmiTree.setActive(true);
				break;
		}

		_cmiOffline.setActive(_settings.IsOffline);
		_cmiKeepPosition.setActive(_settings.KeepPosition);
		_cmiContinuousPlay.setActive(_settings.ContinuousPlay);
	}

	private bool HasInternetConnection()
	{
		debug output(__FUNCTION__);
		bool onwards = false;
		bool hasInternetConnection;

		_loadingWindow.UpdateStatus("Checking for internet connection");
		_loadingWindow.SetDataDownloadedVisible(false);
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

	private void cmiKeepPosition_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.KeepPosition = cast(bool)_cmiKeepPosition.getActive();
		SettingsWorker.SaveSettings(_settings);
	}

	private void cmiContinuousPlay_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.ContinuousPlay = cast(bool)_cmiContinuousPlay.getActive();
		SettingsWorker.SaveSettings(_settings);

		if(_settings.ContinuousPlay)
		{
			_vcVideo.StartContinuousPlayMode(&_vcView.PlayNextVideo);
		}
		else
		{
			_vcVideo.StopContinuousPlayMode();
		}
	}

	private void cmiOffline_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		//Clear the last selected category to stop bugs - online and offline libraries are different sizes usually
		//so the treepath stored here would be pointing to a different category
		_settings.LastSelectedCategory = "";
		SettingsWorker.SaveSettings(_settings);

		_cmiOffline.getActive() ? SetOffline() : SetOnline(true);
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
				//Disable the listener before calling setActive or it will be fired
				_cmiOffline.onActivateListeners.destroy();
				_cmiOffline.setActive(true);
				_cmiOffline.addOnActivate(&cmiOffline_Activate);
				return;
			}
		}

		_settings.IsOffline = false;
		SettingsWorker.SaveSettings(_settings);

		_miDownloadManager.setSensitive(true);

		//Enable full library
		_completeLibrary = LibraryWorker.LoadLibrary();
		LoadNavigation();
	}

	private void SetOffline()
	{
		debug output(__FUNCTION__);
		bool onwards = false;

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

	private void rmiFlow_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.ViewModeSetting = ViewMode.Flow;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();
	}

	private void rmiTree_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.ViewModeSetting = ViewMode.Tree;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();
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
			_loadingWindow.SetDataDownloadedVisible(true);
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
		_loadingWindow.SetDataDownloadedVisible(false);

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

	private void LoadNavigation()
	{
		debug output(__FUNCTION__);
		//Stop any loaded video
		_vcVideo.UnloadVideo();

		if (_vcView)
		{
			_vcView.destroy();
		}

		final switch (_settings.ViewModeSetting)
		{
			case ViewMode.Flow:
				_vcView = new FlowViewControl(_swParent, _swChild, _bboxBreadCrumbs, _completeLibrary, _vcVideo, _settings);
				break;

			case ViewMode.Tree:
				_vcView = new TreeViewControl(_swParent, _swChild, _completeLibrary, _vcVideo, _settings);
				break;
		}

		PreloadCategory();
	}

	private void KillLoadingWindow()
	{
		debug output(__FUNCTION__);
		_loadingWindow.destroy();
	}

	private bool miAbout_ButtonPress(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Don't know why this works but it does:
		//Just so long as this handler is here and just returns true, then the about window is focused when created.
		return true;
	}

	private bool miAbout_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		if (_about)
		{
			_about.Show();
		}
		else
		{
			_about = new About(&DisposeAbout);
		}

		return false;
	}

	private void DisposeAbout()
	{
		debug output(__FUNCTION__);
		_about = null;
	}

	private bool miDownloadManager_ButtonPress(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Again don't know why this works but it does put download manager into focus just so long as this handler exists and returns true
		return true;
	}

	private bool miDownloadManager_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Stop any playing videos as it's possible to delete a video that's playing
		_vcVideo.UnloadVideo();

		DownloadManager downloadManager = new DownloadManager();
		return true;
	}

	private bool miExit_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		exit(0);
		return true;
	}
	
	private void wdwViewer_Destroy(Widget)
	{
		debug output(__FUNCTION__);
		exit(0);
	}
}