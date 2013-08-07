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

module kav.Windows.Viewer;

debug alias std.stdio.writeln output;

import core.thread;

import glib.ListSG;

import gdk.Event;

import gtk.ButtonBox;
import gtk.MenuItem;
import gtk.ScrolledWindow;
import gtk.Widget;
import gtk.Window;

import gtk.CheckMenuItem;
import gtk.Dialog;
import gtk.Grid;
import gtk.Menu;
import gtk.MenuBar;
import gtk.RadioMenuItem;
import gtk.SeparatorMenuItem;

import kav.Controls.FlowViewControl;
import kav.Controls.TreeViewControl;
import kav.Controls.ViewControl;
import kav.Controls.VideoControl;
import kav.DataStructures.Library;
import kav.DataStructures.Settings;
import kav.Include.Enums;
import kav.Include.Functions;
import kav.Windows.About;
import kav.Windows.DownloadManager;
import kav.Windows.Loading;
import kav.Workers.DownloadWorker;
import kav.Workers.LibraryWorker;
import kav.Workers.SettingsWorker;

import std.concurrency;
import std.c.process;

//TODO
//Why doesn't going offline message show in loading window (possibly just too fast?)
//Why check for internet pins cpu?
//Choose one of load library and load library async, no point having both...

public final class Viewer
{

public:

	this()
	{
		debug output(__FUNCTION__);
		setupWindow();
		loadSettings();
		createLoadingWindow();
		hookUpOptionHandlers();
		_settings.isOffline ? setOffline() : setOnline();
		killLoadingWindow();
	}

private:

	ButtonBox		_bboxBreadCrumbs;
	CheckMenuItem	_cmiOffline;
	CheckMenuItem	_cmiKeepPosition;
	CheckMenuItem	_cmiContinuousPlay;
	Library			_completeLibrary;
	Loading			_loadingWindow;
	MenuItem		_miDownloadManager;
	RadioMenuItem	_rmiFlow;
	RadioMenuItem	_rmiTree;
	Settings		_settings;
	ScrolledWindow	_swParent;
	ScrolledWindow	_swChild;
	ViewControl		_vcView;
	VideoControl	_vcVideo;
	Window			_wdwViewer;

	void cmiContinuousPlay_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.continuousPlay = cast(bool)_cmiContinuousPlay.getActive();
		
		if(_settings.continuousPlay)
		{
			_vcVideo.startContinuousPlayMode(&_vcView.playNextVideo);
		}
		else
		{
			_vcVideo.stopContinuousPlayMode();
		}
	}

	void cmiKeepPosition_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		_settings.keepPosition = cast(bool)_cmiKeepPosition.getActive();
		
		if (!_cmiKeepPosition.getActive())
		{
			//Clear last selected when turning off keep position
			_settings.lastSelectedCategory = "";
		}
	}
	
	void cmiOffline_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		//Clear the last selected category to stop bugs - online and offline libraries are different sizes usually
		//so the treepath stored here would be pointing to a different category
		_settings.lastSelectedCategory = "";
		
		createLoadingWindow();
		_cmiOffline.getActive() ? setOffline() : setOnline();
		killLoadingWindow();
	}

	void createLoadingWindow()
	{
		debug output(__FUNCTION__);
		//If loading window already exists don't create a new one
		if (!_loadingWindow)
		{
			//Load the window and refresh the UI to make sure it shows
			_loadingWindow = new Loading();
			Functions.refreshUI();
		}
	}

	void downloadLibrary()
	{
		debug output(__FUNCTION__);
		bool onwards, needToDownLoadLibrary;
		
		//Async check if need to download library (async because sometimes it's really slow)
		_loadingWindow.updateStatus("Checking for library updates");
		spawn(&DownloadWorker.needToDownloadLibrary);
		
		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(bool refreshNeeded)
				{
				needToDownLoadLibrary = refreshNeeded;
				onwards = true;
			});
			
			Functions.refreshUI();
		}
		
		//If library needs to downloaded do another async call to DownloadLibrary
		//keep _loadingWindow updated with progress
		if (needToDownLoadLibrary)
		{
			bool downloadSuccess;
			onwards = false;
			_loadingWindow.updateStatus("Downloading library");
			_loadingWindow.setDataDownloadedVisible(true);
			spawn(&DownloadWorker.downloadLibrary);
			
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
					_loadingWindow.updateAmountDownloaded(amountDownloaded);
				});
				
				Functions.refreshUI();
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
	
	void downloadManager_Closed()
	{
		debug output(__FUNCTION__);
		//If offline need to refresh the views so that any videos which have been deleted are removed
		if(_settings.isOffline)
		{
			bool onwards = false;
			
			_loadingWindow = new Loading();
			scope(exit) _loadingWindow.destroy();
			
			_loadingWindow.updateStatus("Refreshing library");
			
			spawn(&LibraryWorker.loadOfflineLibraryAsync);
			
			while (!onwards)
			{
				receiveTimeout(
					dur!"msecs"(250),
					(shared Library offlineLibrary)
					{
					_completeLibrary = cast(Library)offlineLibrary;
					onwards = true;
				});
				
				Functions.refreshUI();
			}
			
			loadNavigation();
		}
	}

	bool hasInternetConnection()
	{
		debug output(__FUNCTION__);
		bool onwards = false;
		bool hasInternetConnection;
		
		_loadingWindow.updateStatus("Checking for internet connection");
		_loadingWindow.setDataDownloadedVisible(false);
		spawn(&DownloadWorker.hasInternetConnection);
		
		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(bool hasConnection)
				{
				hasInternetConnection = hasConnection;
				onwards = true;
			});
			
			Functions.refreshUI();
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

	void hookUpOptionHandlers()
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

	void killLoadingWindow()
	{
		debug output(__FUNCTION__);
		_loadingWindow.destroy();
		_loadingWindow = null;
	}

	void loadLibraryFromStorage()
	{
		debug output(__FUNCTION__);
		_loadingWindow.updateStatus("Processing library");
		_loadingWindow.setDataDownloadedVisible(false);
		
		//The library takes a few seconds to write to disc after being downloaded
		//loop and wait until it shows up, otherwise cannot load library and program
		//crashes
		while(!LibraryWorker.libraryFileExists())
		{
			Functions.refreshUI();
			Thread.sleep(dur!"msecs"(250));
		}
		
		//Load the online or offline library based on whether currently on or offline...
		_completeLibrary = _settings.isOffline ? LibraryWorker.loadOfflineLibrary() : LibraryWorker.loadLibrary();
	}

	void loadSettings()
	{
		debug output(__FUNCTION__);
		_settings = SettingsWorker.loadSettings();
		
		//Set menu items
		final switch (_settings.viewModeSetting)
		{
			case ViewMode.flow:
				_rmiFlow.setActive(true);
				break;
				
			case ViewMode.tree:
				_rmiTree.setActive(true);
				break;
		}
		
		_cmiOffline.setActive(_settings.isOffline);
		_cmiKeepPosition.setActive(_settings.keepPosition);
		_cmiContinuousPlay.setActive(_settings.continuousPlay);
	}

	void loadNavigation()
	{
		debug output(__FUNCTION__);
		//Stop any loaded video
		_vcVideo.unloadVideo();
		
		if (_vcView)
		{
			_vcView.destroy();
		}
		
		final switch (_settings.viewModeSetting)
		{
			case ViewMode.flow:
				_vcView = new FlowViewControl(_swParent, _swChild, _bboxBreadCrumbs, _completeLibrary, _vcVideo, _settings);
				break;
				
			case ViewMode.tree:
				_vcView = new TreeViewControl(_swParent, _swChild, _completeLibrary, _vcVideo, _settings);
				break;
		}
		
		_vcView.preloadCategory();
	}

	bool miAbout_ButtonPress(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Don't know why this works but it does:
		//Just so long as this handler is here and just returns true, then the about window is focused when created.
		return true;
	}
	
	bool miAbout_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		About about = new About();
		
		return false;
	}
	
	bool miDownloadManager_ButtonPress(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Again don't know why this works but it does put download manager into focus just so long as this handler exists and returns true
		return true;
	}
	
	bool miDownloadManager_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		//Stop any playing videos as it's possible to delete a video that's playing
		_vcVideo.unloadVideo();
		
		DownloadManager downloadManager = new DownloadManager(_settings, &downloadManager_Closed);
		return true;
	}
	
	bool miExit_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		SettingsWorker.saveSettings(_settings);
		exit(0);
		return true;
	}

	void rmiFlow_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		if (_rmiFlow.getActive()) //Activate handler includes de-activate so make sure it is actually activated
		{
			_settings.viewModeSetting = ViewMode.flow;
			
			loadNavigation();
		}
	}
	
	void rmiTree_Activate(MenuItem)
	{
		debug output(__FUNCTION__);
		if (_rmiTree.getActive()) //Activate handler includes de-activate so make sure it is actually activated
		{
			_settings.viewModeSetting = ViewMode.tree;
			
			loadNavigation();
		}
	}

	void setOffline()
	{
		debug output(__FUNCTION__);
		_loadingWindow.updateStatus("Going offline");
		
		_settings.isOffline = true;
		
		loadLibraryFromStorage();
		loadNavigation();
	}

	void setOnline()
	{
		debug output(__FUNCTION__);
		_loadingWindow.updateStatus("Going online");
		
		//If there's no internet connection go back offline
		if (!hasInternetConnection())
		{
			_cmiOffline.setActive(true);
		}
		else
		{
			_settings.isOffline = false;
			
			downloadLibrary();
			loadLibraryFromStorage();
			loadNavigation();
		}
	}

	void setupWindow()
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
		_vcVideo.addOverlays();
	}
		
	void wdwViewer_Destroy(Widget)
	{
		debug output(__FUNCTION__);
		SettingsWorker.saveSettings(_settings);
		exit(0);
	}
}