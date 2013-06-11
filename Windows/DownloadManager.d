/**
 * 
 * DownloadManager.d
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
module KhanAcademyViewer.Windows.DownloadManager;

debug alias std.stdio.writeln output;

import std.file;
import std.path;
import std.string;
import std.conv;

import gtk.Window;
import gtk.Builder;
import gtk.Button;
import gtk.Statusbar;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRendererPixbuf;
import gtk.Image;
import gtk.Widget;

import gdk.Pixbuf;
import gdk.Event;

import gobject.Value;

import gobject.ObjectG;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Include.Config;
import KhanAcademyViewer.Include.Functions;

//TODO - Rest of project, not just here
//IMPORTANT
//Should be able to put whole objects into treeview (i.e. a library model) then pull that back directly
//So no need to iterate over tree to get values
//http://www.mono-project.com/GtkSharp_TreeView_Tutorial

public final class DownloadManager
{
	private immutable string _gladeFile = "./Windows/DownloadManager.glade";
	private immutable string _imageColumnName = "ImageColumn";
	
	private Library _completeLibrary;
	private Window _wdwDownloadManager;
	private Statusbar _statusDownloads;
	private TreeView _tvVideos;
	private Button _btnDone;
	private Pixbuf _downloadImage;
	private Pixbuf _deleteImage;
	private Pixbuf _stopImage;
	private bool _isOnline; //TODO don't allow downloads if offline

	public this(bool isOnline)
	{
		debug output(__FUNCTION__);
		_completeLibrary = LibraryWorker.LoadLibrary();
		_isOnline = isOnline;

		SetupWindow();
		LoadTree();
		DownloadedVideoSize();
	}

	public ~this()
	{
		debug output(__FUNCTION__);
		_wdwDownloadManager.hide();
		destroy(_wdwDownloadManager);
	}

	private void SetupWindow()
	{
		debug output(__FUNCTION__);
		Builder windowBuilder = new Builder();
		Image imageSetter = new Image();

		_downloadImage = imageSetter.renderIconPixbuf("gtk-save", GtkIconSize.MENU);

		_deleteImage = imageSetter.renderIconPixbuf("gtk-delete", GtkIconSize.MENU);

		_stopImage = imageSetter.renderIconPixbuf("gtk-stop", GtkIconSize.MENU);
		
		windowBuilder.addFromFile(_gladeFile);
		
		_wdwDownloadManager = cast(Window)windowBuilder.getObject("wdwDownloadManager");

		_statusDownloads = cast(Statusbar)windowBuilder.getObject("statusDownloads");

		_tvVideos = cast(TreeView)windowBuilder.getObject("tvVideos");
		
		_btnDone = cast(Button)windowBuilder.getObject("btnDone");
		_btnDone.addOnClicked(&btnDone_Clicked);
		
		_wdwDownloadManager.showAll();
	}

	private void LoadTree()
	{
		CreateColumns(_tvVideos);
		_tvVideos.setModel(CreateModel());
		_tvVideos.addOnButtonRelease(&tvVideos_ButtonRelease);
	}

	private bool tvVideos_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvVideos.getSelectedIter();

		assert(selectedItem, "Selected item is null"); //TODO why does this crash instead of throwing error?

		//If there is a selected item, and it's value in column 0 is true then get the video details
		if (!selectedItem.getValueString(0))
		{
			debug output("Not a video node");
			return false;
		}

		double xPos, yPos;
	
		//If getting coords fails exit this method
		if (!e.getCoords(xPos, yPos))
		{
			debug output("Failed getting coords");
			return false;
		}

		TreePath path;
		TreeViewColumn column;
		int xRelative, yRelative;

		//If getting column fails exit this method
		if (!_tvVideos.getPathAtPos(cast(int)xPos, cast(int)yPos, path, column, xRelative, yRelative))
		{
			debug output("Failed getting path at pos");
			return false;
		}

		debug output("got path and column");
		debug output(path);
		debug output(column.getTitle());

		//If user has not clicked on the third column exit this method
		if (column.getTitle() != _imageColumnName)
		{
			debug output("Not image column");
			return false;
		}

		int columnMidPoint = column.getWidth() / 2;

		//If user has clicked outside the download/delete icon exit this method
		if (xRelative < columnMidPoint - 10 || xRelative > columnMidPoint + 10)
		{
			debug output("Not clicked in image bounds");
			return false;
		}

		//So the image is stored in the treeview object as a pointer to GdkPixbuf
		//to find out what image is being clicked on compare it's GdkPixbuf to that
		//of the fixed images (remember to use pointers)
		Value value = new Value();

		selectedItem.getValue(2, value);

		GdkPixbuf* selectedImage = cast(GdkPixbuf*)value.getObject();
		TreeStore store = new TreeStore(cast(GtkTreeStore*)selectedItem.gtkTreeModel); //Works
		//TreeStore store = ObjectG.getDObject!(TreeStore)(cast(GtkTreeStore*)selectedItem.gtkTreeModel); //Creates treemodel
		//TreeStore store = cast(TreeStore)_tvVideos.getModel(); //store is null

		debug output("Store: ", store);

		//Check which image the user has clicked on to determine what to do
		if (selectedImage == _downloadImage.getPixbufStruct())
		{
			debug output("Download image");
			store.setValue(selectedItem, 2, _stopImage);

			//TODO Download video
			debug output("Video file name ", selectedItem.getValueString(0));
		}
		else if (selectedImage == _stopImage.getPixbufStruct())
		{
			debug output("Stop image");
			store.setValue(selectedItem, 2, _downloadImage);

			//TODO stop download - this might need to go in it's own thread
		}
		else if (selectedImage == _deleteImage.getPixbufStruct())
		{
			debug output("Delete image");
			store.setValue(selectedItem, 2, _downloadImage);

			//TODO Delete video
			debug output("Video file name ", selectedItem.getValueString(0));
		}
		else
		{
			assert(0, "Invalid image type detected");
		}

		return false;
	}

	private TreeStore CreateModel()
	{
		debug output(__FUNCTION__);
		if (!_completeLibrary)
		{
			return null;
		}

		TreeStore treeStore = new TreeStore([GType.STRING, GType.STRING, Pixbuf.getType()]);

		RecurseTreeChildren(treeStore, _completeLibrary, null, GetDownloadedFiles());

		return treeStore;
	}
	
	private void RecurseTreeChildren(TreeStore treeStore, Library library, TreeIter parentIter, bool[string] downloadedFiles)
	{
		debug output(__FUNCTION__);

		foreach(Library childLibrary; library.Children)
		{
			TreeIter iter;
			
			if (parentIter)
			{
				iter = treeStore.append(parentIter);
			}
			else
			{
				iter = treeStore.createIter();
			}

			//Fill the rows
			treeStore.setValue(iter, 1, childLibrary.Title);

			//If there is a video link, see if the video already exists, if it does, show the delete icon
			//otherwise show the download icon
			if (childLibrary.MP4 != "")
			{
				//TODO can putting the file name in the treeviewcolumn 0 work in other places?
				treeStore.setValue(iter, 0, childLibrary.MP4);

				if (childLibrary.MP4[childLibrary.MP4.lastIndexOf("/") .. $] in downloadedFiles)
				{
					treeStore.setValue(iter, 2, _deleteImage);
				}
				//Only show download icon when online
				else if (_isOnline)
				{
					treeStore.setValue(iter, 2, _downloadImage);
				}
			}
						
			RecurseTreeChildren(treeStore, childLibrary, iter, downloadedFiles);
		}
	}
	
	private void CreateColumns(TreeView treeView)
	{
		debug output(__FUNCTION__);
		CellRendererText renderer = new CellRendererText();
		CellRendererPixbuf imageRenderer = new CellRendererPixbuf();

		//TODO add image column
		//Add download icon for when video not downloaded
		//Add spinner or progress item when downloading
		//Add delete image when video is downloaded to delete it
		TreeViewColumn indexColumn = new TreeViewColumn("VideoUrl", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		TreeViewColumn imageColumn = new TreeViewColumn(_imageColumnName, imageRenderer, "pixbuf", 2);

		indexColumn.setVisible(false);

		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
		treeView.appendColumn(imageColumn);
	}

	private void btnDone_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		destroy(this);
	}

	private void DownloadedVideoSize()
	{
		debug output(__FUNCTION__);
		//Set item on status bar with total size of videos in download directory
		string downloadDirectory = expandTilde(G_DownloadFilePath);
		ulong totalFileSize;

		foreach(DirEntry file; dirEntries(downloadDirectory, "*.mp4", SpanMode.shallow, false))
		{
			totalFileSize += getSize(file);
		}

		uint contextID = _statusDownloads.getContextId("Total File Size");
		_statusDownloads.push(contextID, format("Total size of downloaded videos: %sKB", totalFileSize / 1024));
	}
}