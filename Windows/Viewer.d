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

import gtk.Builder;
import gtk.Widget;
import gtk.Main;
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
import gtk.Range;

import gdk.Event;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.BreadCrumb;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Workers.VideoWorker;
import KhanAcademyViewer.Windows.Fullscreen;

class Viewer
{
	private string _gladeFile = "./Windows/Viewer.glade";
	private Library _completeLibrary;
	private Library _parentLibrary;
	private Library _childLibrary;
	private BreadCrumb[] _breadCrumbs;

	//UI controls
	private Window _wdwViewer;
	private TreeView _tvParent;
	private TreeView _tvChild;
	private MenuItem _miExit;
	private Label _lblVideoTitle;
	private Label _lblVideoDescription;
	private DrawingArea _drawVideo;
	private VideoWorker _videoWorker;
	private Button _btnPlay;
	private Button _btnFullscreen;
	private Image _imgPlay;
	private Image _imgPause;
	private Scale _sclPosition;
	private double _maxRange;

	this()
	{
		//TODO loading spinner or something
		writeln("Loading library");
		_completeLibrary = LibraryWorker.LoadLibrary();
		//Set initial library reference
		_parentLibrary = _completeLibrary;
		writeln("Library loaded");

		SetupWindow();
	}

	private void SetupWindow()
	{
		Builder windowBuilder = new Builder();
		
		if (!windowBuilder.addFromFile(_gladeFile))
		{
			writeln("Could not load viewer glade file (./Windows/Viewer.glade), does it exist?");
			exit(0);
		}

		//Load all controls from glade file, link to class level variables
		_wdwViewer = cast(Window)windowBuilder.getObject("wdwViewer");

		//Quit if can't load base gtk window for whatever reason
		if (_wdwViewer is null)
		{
			writeln("Could not load window, is the window name correct? Should be wdwViewer");
			exit(0);
		}
			
		_wdwViewer.setTitle("Khan Academy Viewer");
		_wdwViewer.addOnDestroy(&wdwViewer_Destroy);

		_tvParent = cast(TreeView)windowBuilder.getObject("tvParent");
		CreateTreeViewColumns(_tvParent);
		_tvParent.setModel(CreateModel(true));
		_tvParent.addOnButtonRelease(&tvParent_ButtonRelease);

		_tvChild = cast(TreeView)windowBuilder.getObject("tvChild");
		CreateTreeViewColumns(_tvChild);
		_tvChild.addOnButtonRelease(&tvChild_ButtonRelease);

		_lblVideoTitle = cast(Label)windowBuilder.getObject("lblVideoTitle");
		_lblVideoTitle.setLineWrap(true);

		_lblVideoDescription = cast(Label)windowBuilder.getObject("lblVideoDescription");
		_lblVideoDescription.setLineWrap(true);

		_drawVideo = cast(DrawingArea)windowBuilder.getObject("drawVideo");
		_drawVideo.addOnButtonRelease(&btnPlay_ButtonRelease);

		_btnPlay = cast(Button)windowBuilder.getObject("btnPlay");
		_btnPlay.addOnButtonRelease(&btnPlay_ButtonRelease);

		_btnFullscreen = cast(Button)windowBuilder.getObject("btnFullscreen");
		_btnFullscreen.addOnButtonRelease(&btnFullscreen_ButtonRelease);

		_imgPlay = cast(Image)windowBuilder.getObject("imgPlay");

		_imgPause = cast(Image)windowBuilder.getObject("imgPause");

		_sclPosition = cast(Scale)windowBuilder.getObject("sclPosition");
		_sclPosition.addOnChangeValue(&sclPosition_ChangeValue);

		_miExit = cast(MenuItem)windowBuilder.getObject("miExit");
		_miExit.addOnActivate(&miItem_Activate);

		_wdwViewer.showAll();
	}

	private void wdwViewer_Destroy(Widget sender)
	{
		exit(0);
	}

	private void miItem_Activate(MenuItem sender)
	{
		exit(0);
	}

	private ListStore CreateModel(bool isParentTree)
	{
		Library workingLibrary; // = _completeLibrary;
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

//		if (_breadCrumbs.length != 0)
//		{
//			writeln("Model has breadcrumbs");
//			int treeDepth;
//
//			if (isParentTree)
//			{
//				treeDepth = to!int(_breadCrumbs.length) - 1;
//				writeln("Parent tree depth is ", treeDepth);
//			}
//			else
//			{
//				treeDepth = to!int(_breadCrumbs.length);
//				writeln("Child treedepth is ", treeDepth);
//			}
//
//			for(int depth = 0; depth < treeDepth; depth++)
//			{
//				workingLibrary = workingLibrary.children[_breadCrumbs[depth].RowIndex];
//			}
//		}

		for(int index = 0; index < to!int(workingLibrary.children.length); index++)
		{
			listStore.append(tree);
			listStore.setValue(tree, 0, index);
			listStore.setValue(tree, 1, workingLibrary.children[index].title);
		}
		
		return listStore;
	}

	private void CreateTreeViewColumns(ref TreeView treeView)
	{
		writeln("Creating columns");
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("Index", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);

		indexColumn.setVisible(false);

		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private bool tvParent_ButtonRelease(Event e, Widget sender)
	{
		writeln("Parent button press");

		TreeIter selectedItem = _tvParent.getSelectedIter();

		if (selectedItem !is null)
		{
			writeln("Row selected");
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);
			writeln(rowIndex, title);

			//Store breadcrumb
			if (_breadCrumbs.length == 0)
			{
				writeln("New breadcrumb");
				BreadCrumb crumb = new BreadCrumb();

				crumb.RowIndex = rowIndex;
				crumb.Title = title;

				_breadCrumbs.length = 1;
				_breadCrumbs[0] = crumb;
			}
			else
			{
				writeln("Editing old breadcrumb");
				_breadCrumbs[_breadCrumbs.length - 1].RowIndex = rowIndex;
				_breadCrumbs[_breadCrumbs.length - 1].Title = title;
			}

			//Parent library doesn't change, just set child library then reload child treeview
			writeln("Set child model");
			_childLibrary = _parentLibrary.children[rowIndex];
			_tvChild.setModel(CreateModel(false));
		}

		//Stop any more signals being called
		return true;
	}

	private bool tvChild_ButtonRelease(Event e, Widget sender)
	{
		writeln("Child button press");

		TreeIter selectedItem = _tvChild.getSelectedIter();
		
		if (selectedItem !is null)
		{
			writeln("Row selected");
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);
			writeln(rowIndex, title);

			//If this child has children then make this a parent and it's child the new child
			//Otherwise this is the end of the tree - play the video
			if (_childLibrary.children[rowIndex].children !is null)
			{
				writeln("Child has children!");

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

				/*
				 * TODO
				 * Put loading videoworker on it's own thread so that the ui isn't tied up while waiting for connection to video
				 * First step is to disable all video controls and show a loading spinner
				 * Next call the loading thread
				 * When the load completes do a callback to this class to re-enable the controls and hide the spinner
				 * Thread object will need to be a class level variable
				 */

				_videoWorker = new VideoWorker(_drawVideo, _btnPlay, _imgPlay, _sclPosition, currentVideo.download_urls.mp4);
				double vidLength = _videoWorker.GetDuration();
				writeln("Video length ", vidLength);
				_sclPosition.setRange(0, vidLength);
				_maxRange = vidLength;
			}
		}

		//Stop any more signals being called
		return true;
	}

	private bool btnPlay_ButtonRelease(Event e, Widget sender)
	{
		//Check that a video is loaded
		if (_videoWorker !is null)
		{
			if (_videoWorker.getIsPlaying())
			{
				_videoWorker.Pause();
				_btnPlay.setImage(_imgPlay);
			}
			else
			{
				_videoWorker.Play();
				_btnPlay.setImage(_imgPause);
			}
		}

		return true;
	}

	private bool btnFullscreen_ButtonRelease(Event e, Widget sender)
	{
		if (_videoWorker !is null)
		{
			Fullscreen screen = new Fullscreen(_videoWorker, _btnPlay, _imgPlay, _imgPause, _drawVideo);
		}

		return true;
	}

	private bool sclPosition_ChangeValue(GtkScrollType scrollType, double position, Range range)
	{
		if (scrollType == GtkScrollType.JUMP)
		{
			if (position > _maxRange)
			{
				position = _maxRange;
			}

			writeln("Seeking to ", position);
			_videoWorker.SeekTo(position);
		}

		return false;
	}
}