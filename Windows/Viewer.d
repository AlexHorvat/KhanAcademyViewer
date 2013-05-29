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
import std.conv;
import std.concurrency;
import std.array;

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
import gtk.RadioMenuItem;
import gtk.ImageMenuItem;
import gtk.TreeStore;

import gdk.RGBA;
import gdk.Event;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.BreadCrumb;
import KhanAcademyViewer.DataStructures.Settings;
import KhanAcademyViewer.Include.Enums;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Workers.DownloadWorker;
import KhanAcademyViewer.Workers.VideoWorker;
import KhanAcademyViewer.Workers.SettingsWorker;
import KhanAcademyViewer.Windows.Loading;
import KhanAcademyViewer.Windows.About;
import KhanAcademyViewer.Include.Functions;

protected final class Viewer
{
	private const string _gladeFile = "./Windows/Viewer.glade";
	
	private Library _completeLibrary;
	private Library _parentLibrary;
	private Library _childLibrary;
	private BreadCrumb[] _breadCrumbs;
	private int _breadCrumbAvailableWidth;
	private Settings _settings;

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
	private RadioMenuItem _imiFlow;
	private RadioMenuItem _imiTree;
	private ImageMenuItem _miOnline;

	this()
	{
		debug output("this");
		LoadSettings();
		SetupWindow();
		SetupLoader();
		LoadLibraryFromStorage();
		SetOnlineOrOffline();
		KillLoadingWindow();
	}

	private void LoadSettings()
	{
		debug output("LoadSettings");
		_settings = SettingsWorker.LoadSettings();
	}

	private void SetupWindow()
	{
		debug output("SetupWindow");
		Builder windowBuilder = new Builder();
		RGBA rgbaBlack = new RGBA(0,0,0);
		Image imgPlay = new Image(StockID.MEDIA_PLAY, GtkIconSize.BUTTON);

		windowBuilder.addFromFile(_gladeFile);

		//Load all controls from glade file, link to class level variables
		_wdwViewer = cast(Window)windowBuilder.getObject("wdwViewer");
		_wdwViewer.setTitle("Khan Academy Viewer");
		_wdwViewer.addOnDestroy(&wdwViewer_Destroy);

		_tvParent = cast(TreeView)windowBuilder.getObject("tvParent");

		_tvChild = cast(TreeView)windowBuilder.getObject("tvChild");

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

		_miOnline = cast(ImageMenuItem)windowBuilder.getObject("miOnline");
		_miOnline.addOnButtonRelease(&miOnline_ButtonRelease);

		_miAbout = cast(MenuItem)windowBuilder.getObject("miAbout");
		_miAbout.addOnButtonRelease(&miAbout_ButtonRelease);

		_miExit = cast(MenuItem)windowBuilder.getObject("miExit");
		_miExit.addOnButtonRelease(&miExit_ButtonRelease);

		_wdwViewer.showAll();
		RefreshUI();
	}

	private void SetOnlineOrOffline()
	{
		debug output("SetOnlineOrOffline");
		_settings.IsOnline ? SetOnline() : SetOffline();
	}

	private bool miOnline_ButtonRelease(Event e, Widget sender)
	{
		debug output("miOnline_ButtonRelease");
		_settings.IsOnline ? SetOffline() : SetOnline();

		return false;
	}

	private void SetOnline()
	{
		debug output("SetOnline");
		Image imgOnline = new Image(StockID.CONNECT, GtkIconSize.BUTTON);

		_settings.IsOnline = true;
		SettingsWorker.SaveSettings(_settings);
		//Enable full library
		_completeLibrary = LibraryWorker.LoadLibrary();
		LoadNavigation();
		
		_miOnline.setImage(imgOnline);
		_miOnline.setTooltipText("Working Online");
	}

	private void SetOffline()
	{
		debug output("SetOffline");
		Image imgOffline = new Image(StockID.DISCONNECT, GtkIconSize.BUTTON);

		_settings.IsOnline = false;
		SettingsWorker.SaveSettings(_settings);
		//Only show video's which are downloaded, need to change _completeLibrary to reflect this
		_completeLibrary = LibraryWorker.LoadOfflineLibrary();
		LoadNavigation();

		_miOnline.setImage(imgOffline);
		_miOnline.setTooltipText("Working Offline");
	}

	private bool imiFlow_ButtonRelease(Event e, Widget sender)
	{
		debug output("imiFlow_ButtonRelease");
		_settings.ViewModeSetting = ViewMode.Flow;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();

		return false;
	}

	private bool imiTree_ButtonRelease(Event e, Widget sender)
	{
		debug output("imiTree_ButtonRelease");
		_settings.ViewModeSetting = ViewMode.Tree;
		SettingsWorker.SaveSettings(_settings);
		LoadNavigation();

		return false;
	}

	private void SetupLoader()
	{
		debug output("SetupLoader");
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
		debug output("LoadLibraryFromStorage");
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
			Thread.sleep(dur!"msecs"(250));
		}

		_completeLibrary = LibraryWorker.LoadLibrary();
	}

	private void LoadNavigation()
	{
		debug output("LoadNavigation");

		ClearNavigationControls();

		switch (_settings.ViewModeSetting)
		{
			case ViewMode.Flow:
				LoadFlowNavigation();
				break;

			case ViewMode.Tree:
				LoadTreeNavigation();
				break;

			default:
				return;
		}
	}

	private void LoadFlowNavigation()
	{
		debug output("LoadFlowNavigation");
		_imiFlow.setActive(true);
		_tvChild.getParent().setVisible(true);

		//Set tvParent's width to match tvChild's width
		_tvParent.getParent().setSizeRequest(_tvChild.getParent().getWidth(), -1);

		//Setup flow mode
		CreateFlowColumns(_tvParent);
		CreateFlowColumns(_tvChild);

		_parentLibrary = _completeLibrary;
		_tvParent.setModel(CreateFlowModel(true));

		_tvParent.addOnButtonRelease(&tvParent_Flow_ButtonRelease);
		_tvChild.addOnButtonRelease(&tvChild_Flow_ButtonRelease);
		
		_breadCrumbAvailableWidth = _tvParent.getParent().getWidth() + _tvChild.getParent().getWidth();
	}

	private void ClearNavigationControls()
	{
		debug output("ClearNavigationControls");
		_tvParent.onButtonReleaseListeners.destroy();
		_tvParent.onRowActivatedListeners.destroy();
		_tvChild.onButtonReleaseListeners.destroy();

		_breadCrumbs.destroy();
		LoadBreadCrumbs();

		_tvParent.setModel(null);
		_tvChild.setModel(null);

		//Stop any playing video
		if (_videoWorker !is null)
		{
			_videoWorker.destroy();
			debug output("_videoWorker destroyed");
		}
		
		for (int columnCounter = _tvParent.getNColumns() - 1; columnCounter >= 0; columnCounter--)
		{
			_tvParent.removeColumn(_tvParent.getColumn(columnCounter));
		}

		for (int columnCounter = _tvChild.getNColumns() - 1; columnCounter >= 0; columnCounter--)
		{
			_tvChild.removeColumn(_tvChild.getColumn(columnCounter));
		}
	}

	private void LoadTreeNavigation()
	{
		debug output("LoadTreeNavigation");
		_imiTree.setActive(true);
		_tvChild.getParent().setVisible(false);

		//tvChild is the reference width, tvParent is always the same width, so it's safe to assume that
		//both treeviews together are tvChild.width * 2
		//So stretch tvParent to take up both spaces to give the tree room to grow
		_tvParent.getParent().setSizeRequest(_tvChild.getParent().getWidth() * 2, -1);
		_tvParent.addOnButtonRelease(&tvParent_Tree_ButtonRelease);
		CreateTreeColumns(_tvParent);
		_tvParent.setModel(CreateTreeModel());
	}

	private void CreateTreeColumns(TreeView treeView)
	{
		debug output("CreateTreeColumns");
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("HasVideo", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);

		indexColumn.setVisible(false);

		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private TreeStore CreateTreeModel()
	{
		debug output("CreateTreeModel");
		if (_completeLibrary is null)
		{
			return null;
		}

		TreeStore treeStore = new TreeStore([GType.INT, GType.STRING]);

		RecurseTreeChildren(treeStore, _completeLibrary, null);

		return treeStore;
	}

	private void RecurseTreeChildren(TreeStore treeStore, Library library, TreeIter parentIter)
	{
		debug output("RecurseTreeChildren");
		foreach(Library childLibrary; library.Children)
		{
			TreeIter iter;

			if (parentIter is null)
			{
				iter = treeStore.createIter();
			}
			else
			{
				iter = treeStore.append(parentIter);
			}

			treeStore.setValue(iter, 0, childLibrary.MP4 != "");
			treeStore.setValue(iter, 1, childLibrary.Title);

			RecurseTreeChildren(treeStore, childLibrary, iter);
		}
	}

	private ListStore CreateFlowModel(bool isParentTree)
	{
		debug output("CreateFlowModel");
		ListStore listStore = new ListStore([GType.INT, GType.STRING]);
		TreeIter tree = new TreeIter();
		Library workingLibrary;
		
		if (isParentTree)
		{
			workingLibrary = _parentLibrary;
		}
		else
		{
			workingLibrary = _childLibrary;
		}

		if (workingLibrary is null)
		{
			return null;
		}

		for(int index = 0; index < workingLibrary.Children.length; index++)
		{
			listStore.append(tree);
			listStore.setValue(tree, 0, index);
			listStore.setValue(tree, 1, workingLibrary.Children[index].Title);
		}
		
		return listStore;
	}
	
	private bool tvParent_Tree_ButtonRelease(Event e, Widget sender)
	{
		debug output("tvParent_Tree_ButtonRelease");
		TreeIter selectedItem = _tvParent.getSelectedIter();

		//If there is a selected item, and it's value in column 0 is true then get the video details
		if (selectedItem !is null && selectedItem.getValueInt(0))
		{
			debug output("selected item has video");
			//Use TreePath to iterate over library to get the selected value, can then get video details from this
			Library currentVideo = _completeLibrary;
			string[] paths = split(selectedItem.getTreePath().toString(), ":");

			foreach (string path; paths)
			{
				currentVideo = currentVideo.Children[to!long(path)];
			}

			LoadVideo(currentVideo);
		}
		//TODO remove this else once debugging done
		else
		{
			debug output("selecteditem is null");
		}

		return false;
	}

	private void KillLoadingWindow()
	{
		debug output("KillLoadingWindow");
		_loadingWindow.destroy();
	}
	
	private void CreateFlowColumns(ref TreeView treeView)
	{
		debug output("CreateFlowColumns");
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("Index", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);

		indexColumn.setVisible(false);

		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private void LoadBreadCrumbs()
	{
		debug output("LoadBreadCrumbs");
		//Clear existing breadcrumb buttons
		_bboxBreadCrumbs.removeAll();

		//Get the size available for each bread crumb button, and the maximum length allowed for the title
		if (_breadCrumbs !is null && _breadCrumbs.length != 0)
		{
			int breadCrumbWidth = _breadCrumbAvailableWidth / cast(int)_breadCrumbs.length - 8;
			int titleLength = breadCrumbWidth / 8;

			foreach(ulong breadCrumbIndex; 0 .. _breadCrumbs.length)
			{
				string title = _breadCrumbs[breadCrumbIndex].Title;

				if (title.length > titleLength)
				{
					title.length = titleLength - 3;
					title ~= "...";
				}

				Button breadButton = new Button(title, false);
				
				breadButton.setName(to!string(breadCrumbIndex + 1));
				breadButton.setTooltipText(_breadCrumbs[breadCrumbIndex].Title);
				breadButton.setAlignment(0.0, 0.5);
				breadButton.setSizeRequest(breadCrumbWidth, -1);
				breadButton.setVisible(true);
				breadButton.addOnClicked(&breadButton_Clicked);
				
				_bboxBreadCrumbs.add(breadButton);
			}
		}
	}

	private bool tvParent_Flow_ButtonRelease(Event e, Widget sender)
	{
		debug output("tvParent_Flow_ButtonRelease");
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
			_childLibrary = _parentLibrary.Children[rowIndex];
			_tvChild.setModel(CreateFlowModel(false));

			LoadBreadCrumbs();
		}

		//Stop any more signals being called
		return true;
	}

	private bool tvChild_Flow_ButtonRelease(Event e, Widget sender)
	{
		debug output("tvChild_Flow_ButtonRelease");
		TreeIter selectedItem = _tvChild.getSelectedIter();
		
		if (selectedItem !is null)
		{
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);

			//If this child has children then make this a parent and it's child the new child
			//Otherwise this is the end of the tree - play the video
			if (_childLibrary.Children[rowIndex].Children !is null)
			{
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.RowIndex = rowIndex;
				crumb.Title = title;

				_breadCrumbs.length = _breadCrumbs.length + 1;
				_breadCrumbs[_breadCrumbs.length - 1] = crumb;

				//Update parent and child libraries - this will move the current child library over to the parent position
				//and set the new child to be the child's chlid library
				_parentLibrary = _childLibrary;
				_childLibrary = _parentLibrary.Children[rowIndex];

				_tvParent.setModel(CreateFlowModel(true));
				_tvChild.setModel(CreateFlowModel(false));

				LoadBreadCrumbs();
			}
			else
			{
				LoadVideo(_childLibrary.Children[rowIndex]);
			}
		}

		//Stop any more signals being called
		return true;
	}

	private void LoadVideo(Library currentVideo)
	{
		debug output("LoadVideo");
		debug output("Video to play ", currentVideo.MP4);
		//If a video is already playing, dispose of it
		if (_videoWorker !is null)
		{
			_videoWorker.destroy();
		}

		//Get the authors
		string authors;

		foreach (string author; currentVideo.AuthorNames)
		{
			authors ~= author;
			authors ~= ", ";
		}
		//Cut off trailing ", "
		authors.length = authors.length - 2;

		_lblVideoTitle.setText(currentVideo.Title);
		//Add authors and date added to description
		_lblVideoDescription.setText(currentVideo.Description ~ "\n\nAuthor(s): " ~ authors ~ "\n\nDate Added: " ~ currentVideo.DateAdded.date.toString());
		_videoWorker = new VideoWorker(currentVideo.MP4, _fixedVideo, _drawVideo, _btnPlay, _btnFullscreen, _sclPosition, _lblCurrentTime, _lblTotalTime);
	}

	private bool miAbout_ButtonRelease(Event e, Widget sender)
	{
		debug output("miAbout_ButtonRelease");
		About about = new About();

		return true;
	}

	private bool miExit_ButtonRelease(Event e, Widget sender)
	{
		debug output("miExit_ButtonRelease");
		exit(0);
		return true;
	}

	private void breadButton_Clicked(Button sender)
	{
		debug output("breadButton_Clicked");
		//Cut _breadCrumbs down to breadCrumbIndex length, then set the parent and child to the last two breadcrumb items
		int breadCrumbNewLength = to!int(sender.getName());
		_breadCrumbs.length = breadCrumbNewLength;

		//Set parent library to 2nd to last breadcrumb item
		_parentLibrary = _completeLibrary;

		foreach(ulong breadCrumbCounter; 0 .. _breadCrumbs.length - 1)
		{
			_parentLibrary = _parentLibrary.Children[_breadCrumbs[breadCrumbCounter].RowIndex];
		}

		_tvParent.setModel(CreateFlowModel(true));

		//Set child library to last breadcrumb item
		int childRowIndex = _breadCrumbs[_breadCrumbs.length - 1].RowIndex;

		_childLibrary = _parentLibrary.Children[childRowIndex];
		_tvChild.setModel(CreateFlowModel(false));

		//Pre-set the selected item in parent treeview
		TreePath path = new TreePath(childRowIndex);
		TreeSelection selection = _tvParent.getSelection();
		selection.selectPath(path);

		//Refresh bread crumbs
		LoadBreadCrumbs();
	}

	private void fixedVideo_SizeAllocate(GdkRectangle* newSize, Widget sender)
	{
		debug output("fixedVideo_SizeAllocate");
		//Need to keep drawVideo the same size as it's parent - the fixed widget
		//this has to be done manually
		_drawVideo.setSizeRequest(newSize.width, newSize.height);
	}

	private void wdwViewer_Destroy(Widget sender)
	{
		debug output("wdwViewer_Destroy");
		exit(0);
	}
}