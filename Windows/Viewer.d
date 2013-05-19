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

import std.stdio;
import std.c.process;
import std.conv;
import std.concurrency;

import core.time;
import core.thread;

import gtk.Builder;
import gtk.Widget;
import gtk.Window;
import gtk.MenuItem;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.ListStore;
import gtk.CellRendererText;
import gtk.TreeSelection;
import gtk.TreePath;
import gtk.Label;
import gtk.DrawingArea;
import gtk.Button;
import gtk.Image;
import gtk.Scale;
import gtk.ButtonBox;
import gtk.Main;
import gtk.Fixed;
import gtk.EventBox;

import gdk.RGBA;
import gdk.Event;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.BreadCrumb;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Workers.DownloadWorker;
import KhanAcademyViewer.Workers.VideoWorker;
import KhanAcademyViewer.Windows.Fullscreen;
import KhanAcademyViewer.Windows.Loading;
import KhanAcademyViewer.Windows.About;

protected final class Viewer
{
	private const string _gladeFile = "./Windows/Viewer.glade";
	
	private Library _completeLibrary;
	private Library _parentLibrary;
	private Library _childLibrary;
	private BreadCrumb[] _breadCrumbs;

	//UI controls
	private Window _wdwViewer;
	private TreeView _tvParent;
	private TreeView _tvChild;
	private MenuItem _miAbout;
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

	this()
	{
		SetupWindow();
		SetupLoader();
		LoadLibraryFromStorage();
		LoadInitialTreeViewState();
		KillLoadingWindow();
	}

	private ListStore CreateModel(bool isParentTree)
	{
		Library workingLibrary;
		ListStore listStore = new ListStore([GType.INT, GType.STRING]);
		TreeIter tree = new TreeIter();
		
		if (isParentTree)
		{
			workingLibrary = _parentLibrary;
		}
		else
		{
			workingLibrary = _childLibrary;
		}
		
		for(int index = 0; index < workingLibrary.children.length; index++)
		{
			listStore.append(tree);
			listStore.setValue(tree, 0, index);
			listStore.setValue(tree, 1, workingLibrary.children[index].title);
		}
		
		return listStore;
	}

	private void SetupWindow()
	{
		Builder windowBuilder = new Builder();
		RGBA rgbaBlack = new RGBA(0,0,0);
		Image imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);

		if (!windowBuilder.addFromFile(_gladeFile))
		{
			writeln("Could not load viewer glade file (./Windows/Viewer.glade), does it exist?");
			exit(0);
		}

		//Load all controls from glade file, link to class level variables
		_wdwViewer = cast(Window)windowBuilder.getObject("wdwViewer");
		_wdwViewer.setTitle("Khan Academy Viewer");
		_wdwViewer.addOnDestroy(&wdwViewer_Destroy);

		_tvParent = cast(TreeView)windowBuilder.getObject("tvParent");
		_tvParent.addOnButtonRelease(&tvParent_ButtonRelease);

		_tvChild = cast(TreeView)windowBuilder.getObject("tvChild");
		_tvChild.addOnButtonRelease(&tvChild_ButtonRelease);

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
		_btnPlay.setSensitive(false);

		_btnFullscreen = cast(Button)windowBuilder.getObject("btnFullscreen");
		_btnFullscreen.addOnClicked(&btnFullscreen_Clicked);

		_sclPosition = cast(Scale)windowBuilder.getObject("sclPosition");

		_lblCurrentTime = cast(Label)windowBuilder.getObject("lblCurrentTime");

		_lblTotalTime = cast(Label)windowBuilder.getObject("lblTotalTime");

		_bboxBreadCrumbs = cast(ButtonBox)windowBuilder.getObject("bboxBreadCrumbs");

		_miAbout = cast(MenuItem)windowBuilder.getObject("miAbout");
		_miAbout.addOnButtonRelease(&miAbout_ButtonRelease);

		_miExit = cast(MenuItem)windowBuilder.getObject("miExit");
		_miExit.addOnButtonRelease(&miExit_ButtonRelease);

		_wdwViewer.showAll();
		RefreshUI();
	}

	private void SetupLoader()
	{
		bool onwards, needToDownLoadLibrary;

		//Show the loading window and make sure it's loaded before starting the download
		_loadingWindow = new Loading();
		RefreshUI();

		//Async check if need to download library (async because sometimes it's really slow)
		onwards = false;
		spawn(&DownloadWorker.NeedToDownloadLibrary, thisTid);

		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(500),
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
			onwards = false;

			_loadingWindow.UpdateStatus("Downloading library");

			spawn(&DownloadWorker.DownloadLibrary, thisTid);

			while (!onwards)
			{
				receiveTimeout(
					dur!"msecs"(500),
					(ulong amountDownloaded)
					{
						//Update the loading window with amount downloaded
						_loadingWindow.UpdateAmountDownloaded(amountDownloaded);
					},
					(Tid deathSignal)
					{
						//Been sent the TID of death, exit the loading loop
						onwards = true;
					});
				
				RefreshUI();
			}
		}
	}

	private void LoadLibraryFromStorage()
	{
		//Maybe make this async in the future
		//Seems to be difficult to pass the loaded library around async
		//If passed in a message it locks the sending thread
		//And if passed as a shared variable it is always null in this thread
		//even after being set on the loading thread

		_loadingWindow.UpdateStatus("Processing library");

		//The library takes a few seconds to write to disc after being downloaded
		//loop and wait until it shows up, otherwise cannot load library and program
		//crashes
		while(!LibraryWorker.LibraryFileExists())
		{
			RefreshUI();
			Thread.sleep(dur!"msecs"(500));
		}

		_completeLibrary = LibraryWorker.LoadLibrary();
	}

	private void LoadInitialTreeViewState()
	{
		CreateTreeViewColumns(_tvParent);
		CreateTreeViewColumns(_tvChild);

		_parentLibrary = cast(Library)_completeLibrary;
		_tvParent.setModel(CreateModel(true));
	}

	private void KillLoadingWindow()
	{
		_loadingWindow.destroy();
	}

	private void RefreshUI()
	{
		//Run any gtk events pending to refresh the UI
		while (Main.eventsPending)
		{
			Main.iteration();
		}
	}
	
	private void CreateTreeViewColumns(ref TreeView treeView)
	{
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("Index", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);

		indexColumn.setVisible(false);

		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private void LoadBreadCrumbs()
	{
		//Clear existing breadcrumb buttons
		_bboxBreadCrumbs.removeAll();
		
		//Create new breadcrumb buttons
		for (int breadCrumbIndex = 0; breadCrumbIndex < _breadCrumbs.length; breadCrumbIndex++)
		{
			Button breadButton = new Button(_breadCrumbs[breadCrumbIndex].Title, false);
			
			breadButton.setName(to!(string)(breadCrumbIndex + 1));
			breadButton.setVisible(true);
			breadButton.addOnClicked(&breadButton_Clicked);
			
			_bboxBreadCrumbs.add(breadButton);
		}
	}

	private bool tvParent_ButtonRelease(Event e, Widget sender)
	{
		TreeIter selectedItem = _tvParent.getSelectedIter();

		if (selectedItem !is null)
		{
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);

			//If there are no breadcrumbs yet create a new breadcrumb
			if (_breadCrumbs.length == 0)
			{
				BreadCrumb crumb = new BreadCrumb();

				crumb.RowIndex = rowIndex;
				crumb.Title = title;

				_breadCrumbs.length = 1;
				_breadCrumbs[0] = crumb;
			}
			//But usually there will be some breadcrumbs, as this is a parent item there will already be a breadcrumb
			//entry for it, so overwrite that entry
			else
			{
				_breadCrumbs[_breadCrumbs.length - 1].RowIndex = rowIndex;
				_breadCrumbs[_breadCrumbs.length - 1].Title = title;
			}

			//Parent library doesn't change, just set child library then reload child treeview
			_childLibrary = _parentLibrary.children[rowIndex];
			_tvChild.setModel(CreateModel(false));

			LoadBreadCrumbs();
		}

		//Stop any more signals being called
		return true;
	}

	private bool tvChild_ButtonRelease(Event e, Widget sender)
	{
		TreeIter selectedItem = _tvChild.getSelectedIter();
		
		if (selectedItem !is null)
		{
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);

			//If this child has children then make this a parent and it's child the new child
			//Otherwise this is the end of the tree - play the video
			if (_childLibrary.children[rowIndex].children !is null)
			{
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.RowIndex = rowIndex;
				crumb.Title = title;

				_breadCrumbs.length = _breadCrumbs.length + 1;
				_breadCrumbs[_breadCrumbs.length - 1] = crumb;

				//Update parent and child libraries - this will move the current child library over to the parent position
				//and set the new child to be the child's chlid library
				_parentLibrary = _childLibrary;
				_childLibrary = _parentLibrary.children[rowIndex];

				_tvParent.setModel(CreateModel(true));
				_tvChild.setModel(CreateModel(false));

				LoadBreadCrumbs();
			}
			else
			{
				Library currentVideo = _childLibrary.children[rowIndex];

				writeln("Video to play ", currentVideo.download_urls.mp4);

				_lblVideoTitle.setText(currentVideo.title);
				_lblVideoDescription.setText(currentVideo.description);

				//If a video is already playing, dispose of it
				if (_videoWorker !is null)
				{
					_videoWorker.destroy();
				}

				_videoWorker = new VideoWorker(currentVideo.download_urls.mp4, _fixedVideo, _drawVideo, _btnPlay, _sclPosition, _lblCurrentTime, _lblTotalTime);
			}
		}

		//Stop any more signals being called
		return true;
	}

	private bool miAbout_ButtonRelease(Event e, Widget sender)
	{
		About about = new About();

		return true;
	}

	private bool miExit_ButtonRelease(Event e, Widget sender)
	{
		exit(0);
		return true;
	}

	private void btnFullscreen_Clicked(Button sender)
	{
		if (_videoWorker !is null)
		{
			Fullscreen screen = new Fullscreen(_videoWorker, _btnPlay, _drawVideo);
		}
	}

	private void breadButton_Clicked(Button sender)
	{
		//Cut _breadCrumbs down to breadCrumbIndex length, then set the parent and child to the last two breadcrumb items
		int breadCrumbNewLength = to!(int)(sender.getName());
		_breadCrumbs.length = breadCrumbNewLength;

		//Set parent library to 2nd to last breadcrumb item
		_parentLibrary = cast(Library)_completeLibrary;

		for (int breadCrumbCounter = 0; breadCrumbCounter < _breadCrumbs.length - 1; breadCrumbCounter++)
		{
			_parentLibrary = _parentLibrary.children[_breadCrumbs[breadCrumbCounter].RowIndex];
		}

		_tvParent.setModel(CreateModel(true));

		//Set child library to last breadcrumb item
		int childRowIndex = _breadCrumbs[_breadCrumbs.length - 1].RowIndex;

		_childLibrary = _parentLibrary.children[childRowIndex];
		_tvChild.setModel(CreateModel(false));

		//Pre-set the selected item in parent treeview
		TreePath path = new TreePath(childRowIndex);
		TreeSelection selection = _tvParent.getSelection();
		selection.selectPath(path);

		//Refresh bread crumbs
		LoadBreadCrumbs();
	}

	private void fixedVideo_SizeAllocate(GdkRectangle* newSize, Widget sender)
	{
		//Need to keep drawVideo the same size as it's parent - the fixed widget
		//this has to be done manually
		_drawVideo.setSizeRequest(newSize.width, newSize.height);
	}

	private void wdwViewer_Destroy(Widget sender)
	{
		exit(0);
	}
}