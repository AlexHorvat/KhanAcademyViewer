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

debug alias std.stdio.writeln output;

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
import gtk.Dialog;

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
//Why doesn't going offline message show in loading window (possibly just too fast?)
//Why check for internet pins cpu?

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
	private VideoControl _vcVideo;

	public this()
	{
		debug output(__FUNCTION__);
		SetupWindow();
		LoadSettings();
		CreateLoadingWindow();
		HookUpOptionHandlers();
		_settings.IsOffline ? SetOffline() : SetOnline();
		KillLoadingWindow();
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

		if (!hasInternetConnection)
		{
			//Pop up warning that there is no internet connection, and will be going offline
			Dialog noConnectionDialog = new Dialog("No internet connection, going offline.", _wdwViewer, GtkDialogFlags.MODAL, [StockID.OK], [ResponseType.OK]);
			noConnectionDialog.setSizeRequest(350, -1);
			noConnectionDialog.run();
			noConnectionDialog.destroy();
		}

		return hasInternetConnection;
	}

	private void cmiKeepPosition_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.KeepPosition = cast(bool)_cmiKeepPosition.getActive();

		if (!_cmiKeepPosition.getActive())
		{
			//Clear last selected when turning off keep position
			_settings.LastSelectedCategory = "";
		}
	}

	private void cmiContinuousPlay_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.ContinuousPlay = cast(bool)_cmiContinuousPlay.getActive();

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

		CreateLoadingWindow();
		_cmiOffline.getActive() ? SetOffline() : SetOnline();
		KillLoadingWindow();
	}

	private void SetOnline()
	{
		debug output(__FUNCTION__);
		_loadingWindow.UpdateStatus("Going online");

		//If there's no internet connection go back offline
		if (!HasInternetConnection())
		{
			_cmiOffline.setActive(true);
		}
		else
		{
			_settings.IsOffline = false;

			DownloadLibrary();
			LoadLibraryFromStorage();
			LoadNavigation();
		}
	}

	private void SetOffline()
	{
		debug output(__FUNCTION__);
		_loadingWindow.UpdateStatus("Going offline");

		_settings.IsOffline = true;

		LoadLibraryFromStorage();
		LoadNavigation();
	}

	private void rmiFlow_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		if (_rmiFlow.getActive()) //Activate handler includes de-activate so make sure it is actually activated
		{
			_settings.ViewModeSetting = ViewMode.Flow;

			LoadNavigation();
		}
	}

	private void rmiTree_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		if (_rmiTree.getActive()) //Activate handler includes de-activate so make sure it is actually activated
		{
			_settings.ViewModeSetting = ViewMode.Tree;

			LoadNavigation();
		}
	}

	private void CreateLoadingWindow()
	{
		debug output(__FUNCTION__);
		//If loading window already exists don't create a new one
		if (!_loadingWindow)
		{
			//Load the window and refresh the UI to make sure it shows
			_loadingWindow = new Loading();
			RefreshUI();
		}
	}

	private void DownloadLibrary()
	{
		debug output(__FUNCTION__);
		bool onwards, needToDownLoadLibrary;

		//Async check if need to download library (async because sometimes it's really slow)
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
				//Show warning about not being able to download library
				Dialog noConnectionDialog = new Dialog("Could not download library.", _wdwViewer, GtkDialogFlags.MODAL, [StockID.OK], [ResponseType.OK]);
				noConnectionDialog.setSizeRequest(300, -1);
				noConnectionDialog.run();
				noConnectionDialog.destroy();
			}
		}
	}

	private void LoadLibraryFromStorage()
	{
		debug output(__FUNCTION__);
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

		//Load the online or offline library based on whether currently on or offline...
		_completeLibrary = _settings.IsOffline ? LibraryWorker.LoadOfflineLibrary() : LibraryWorker.LoadLibrary();
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

		_vcView.PreloadCategory();
	}

	private void KillLoadingWindow()
	{
		debug output(__FUNCTION__);
		_loadingWindow.destroy();
		_loadingWindow = null;
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
		About about = new About();

		return false;
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

		DownloadManager downloadManager = new DownloadManager(_settings, &OnDownloadManager_Closed);
		return true;
	}

	private void OnDownloadManager_Closed()
	{
		debug output(__FUNCTION__);
		//If offline need to refresh the views so that any videos which have been deleted are removed
		if(_settings.IsOffline)
		{
			bool onwards = false;

			_loadingWindow = new Loading();
			scope(exit) _loadingWindow.destroy();

			_loadingWindow.UpdateStatus("Refreshing library");

			spawn(&LibraryWorker.LoadOfflineLibraryAsync);
			
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
	}

	private bool miExit_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		SettingsWorker.SaveSettings(_settings);
		exit(0);
		return true;
	}
	
	private void wdwViewer_Destroy(Widget)
	{
		debug output(__FUNCTION__);
		SettingsWorker.SaveSettings(_settings);
		exit(0);
	}
}