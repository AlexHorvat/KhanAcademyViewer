/*
 * DownloadManager.d
 * 
 * Author: Alex Horvat <alex.horvat9@gmail.com>
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

module kav.Windows.DownloadManager;

debug alias std.stdio.writeln output;

import core.time;

import gdk.Event;
import gdk.Pixbuf;

import gobject.Value;

import gtk.Button;
import gtk.CellRendererText;
import gtk.CellRendererPixbuf;
import gtk.Dialog;
import gtk.Fixed;
import gtk.Grid;
import gtk.Image;
import gtk.ScrolledWindow;
import gtk.Statusbar;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;

import kav.DataStructures.Library;
import kav.DataStructures.Settings;
import kav.Include.Config;
import kav.Include.Functions;
import kav.Workers.DownloadWorker;
import kav.Workers.LibraryWorker;

import std.concurrency;
import std.file;
import std.path:expandTilde;
import std.string:format;

public final class DownloadManager
{

public:

	this(Settings settings, void delegate() downloadManager_Closed)
	{
		debug output(__FUNCTION__);
		bool onwards = false;

		_isOffline = settings.isOffline;
		this.downloadManager_Closed = downloadManager_Closed;

		setupWindow();

		//Load the online or offline library as needed
		_isOffline ? spawn(&LibraryWorker.loadOfflineLibraryAsync) : spawn(&LibraryWorker.loadLibraryAsync);
		
		while (!onwards)
		{
			receiveTimeout(
				dur!"msecs"(250),
				(shared Library library)
				{
				_completeLibrary = cast(Library)library;
				onwards = true;
			},
			(bool failed)
			{
				throw new Exception("FATAL ERROR: Cannot load library, try deleting the library file from user data.");
			});
			
			Functions.refreshUI();
		}

		loadTree();
		downloadedVideoSize();
	}

private:

	immutable string	_imageColumnName = "ImageColumn";
	immutable bool		_isOffline;

	TreeIter[string]	_activeIters; //Keep track of which videos are downloading by tracking their TreeIter
	Button				_btnDone;
	Library				_completeLibrary;
	Pixbuf				_deleteImage;
	Pixbuf				_downloadImage;
	uint				_statusBarContextID;
	Statusbar			_statusDownloads;
	Pixbuf				_stopImage;
	TreeView			_tvVideos;
	Window				_wdwDownloadManager;

	/*
	 * Close the download window, and if any videos are downloading, cancel them.
	 */
	void btnDone_Clicked(Button)
	{
		debug output(__FUNCTION__);
		//Check if there are still videos downloading
		if (_activeIters.length >  0)
		{
			//Prompt user to cancel downloads
			Dialog cancelDownloads = new Dialog("Stop downloads?", _wdwDownloadManager, GtkDialogFlags.MODAL, [StockID.YES, StockID.NO], [ResponseType.YES, ResponseType.NO]);
			
			int cancelResponse = cancelDownloads.run();
			cancelDownloads.destroy();
			
			if (cancelResponse == ResponseType.NO)
			{
				return;
			}
			
			//There are still downloads going, cancel them all
			foreach( url; _activeIters.keys)
			{
				_activeIters[url].destroy();
				_activeIters.remove(url);
			}
		}

		_wdwDownloadManager.destroy();
	}

	/*
	 * Create the columns for the treeview.
	 * 
	 * Params:
	 * treeview = the treeview to create the columns for.
	 */
	void createColumns(TreeView treeView)
	{
		debug output(__FUNCTION__);
		CellRendererText renderer = new CellRendererText();
		CellRendererPixbuf imageRenderer = new CellRendererPixbuf();
		
		TreeViewColumn urlColumn = new TreeViewColumn("VideoUrl", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		TreeViewColumn imageColumn = new TreeViewColumn(_imageColumnName, imageRenderer, "pixbuf", 2);
		TreeViewColumn progressColumn = new TreeViewColumn("Progress", renderer, "text", 3);
		
		urlColumn.setVisible(false);
		
		treeView.appendColumn(urlColumn);
		treeView.appendColumn(titleColumn);
		treeView.appendColumn(imageColumn);
		treeView.appendColumn(progressColumn);
	}

	/*
	 * Define and load the model to be displayed in the treeview.
	 */
	TreeStore createModel()
	{
		debug output(__FUNCTION__);
		if (!_completeLibrary)
		{
			return null;
		}
		
		TreeStore treeStore = new TreeStore([GType.STRING, GType.STRING, Pixbuf.getType(), GType.STRING]);
		
		recurseTreeChildren(treeStore, _completeLibrary, null, Functions.getDownloadedFiles());
		
		return treeStore;
	}

	/*
	 * Calculate and display the total size of all videos currently downloaded.
	 */
	void downloadedVideoSize()
	{
		debug output(__FUNCTION__);
		//Set item on status bar with total size of videos in download directory
		string downloadDirectory = expandTilde(DOWNLOAD_FILE_PATH);
		ulong totalFileSize;
		
		if (_statusBarContextID != 0)
		{
			_statusDownloads.removeAll(_statusBarContextID);
		}

		foreach(DirEntry file; dirEntries(downloadDirectory, "*.mp4", SpanMode.shallow, false))
		{
			totalFileSize += getSize(file);
		}
		
		_statusBarContextID = _statusDownloads.getContextId("Total File Size");
		_statusDownloads.push(_statusBarContextID, format("Total size of downloaded videos: %sKB", totalFileSize / 1024));
	}

	/*
	 * Delegate method to call on closing the download window, this method needs to dispose of the download widget
	 * correctly and, if offline, refresh the available video list.
	 */
	void delegate() downloadManager_Closed;

	/*
	 * Get the treeview displaying all videos and options to download or delete them loaded up.
	 */
	void loadTree()
	{
		createColumns(_tvVideos);
		_tvVideos.setModel(createModel());
		_tvVideos.addOnButtonRelease(&tvVideos_ButtonRelease);
	}

	/*
	 * Recurse through each item in the Khan Academy library adding the item to the treeview's model, along with setting
	 * whether the item can be downloaded, deleted or neither if it's just a library node, not a video node.
	 * 
	 * Params:
	 * treeStore = the container to add library nodes into.
	 * library = the library to recurse over to extract nodes.
	 * parentIter = the parent node to add child nodes to, if this is null it's assumed that a root node needs to be created.
	 * downloadedFiles = a hashtable of already downloaded videos, these have their icon set to a delete icon.
	 */
	void recurseTreeChildren(TreeStore treeStore, Library library, TreeIter parentIter, bool[string] downloadedFiles)
	{
		debug output(__FUNCTION__);
		foreach(Library childLibrary; library.children)
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
			treeStore.setValue(iter, 1, childLibrary.title);
			
			//If there is a video link, see if the video already exists, if it does, show the delete icon
			//otherwise show the download icon
			if (childLibrary.mp4 != "")
			{
				treeStore.setValue(iter, 0, childLibrary.mp4);
				
				if (childLibrary.mp4[childLibrary.mp4.lastIndexOf("/") .. $] in downloadedFiles)
				{
					treeStore.setValue(iter, 2, _deleteImage);
				}
				else
				{
					treeStore.setValue(iter, 2, _downloadImage);
				}
			}
			
			recurseTreeChildren(treeStore, childLibrary, iter, downloadedFiles);
		}
	}

	/*
	 * Load all the widgets for the download window.
	 */
	void setupWindow()
	{
		debug output(__FUNCTION__);
		Image imageSetter = new Image();

		_downloadImage = imageSetter.renderIconPixbuf("gtk-save", GtkIconSize.MENU);

		_deleteImage = imageSetter.renderIconPixbuf("gtk-delete", GtkIconSize.MENU);

		_stopImage = imageSetter.renderIconPixbuf("gtk-stop", GtkIconSize.MENU);

		_wdwDownloadManager = new Window("Download Videos");
		_wdwDownloadManager.setModal(true);
		_wdwDownloadManager.setDestroyWithParent(true);
		_wdwDownloadManager.setTypeHint(GdkWindowTypeHint.DIALOG);
		_wdwDownloadManager.setSizeRequest(800, 600);
		_wdwDownloadManager.addOnDestroy(&wdwDownloadManager_Destroyed);

		Grid grdDownloadManager = new Grid();
		grdDownloadManager.insertColumn(0);
		grdDownloadManager.insertColumn(0);
		grdDownloadManager.insertRow(0);
		grdDownloadManager.insertRow(0);
		_wdwDownloadManager.add(grdDownloadManager);

		_statusDownloads = new Statusbar();
		_statusDownloads.setMarginLeft(5);
		grdDownloadManager.attach(_statusDownloads, 0, 1, 1, 1);

		ScrolledWindow swVideos = new ScrolledWindow();
		swVideos.setHexpand(true);
		swVideos.setVexpand(true);
		grdDownloadManager.attach(swVideos, 0, 0, 2,  1);

		_tvVideos = new TreeView();
		_tvVideos.setHeadersVisible(false);
		_tvVideos.setEnableSearch(false);
		swVideos.add(_tvVideos);

		Fixed fixDone = new Fixed();
		fixDone.setSizeRequest(105, 50);
		fixDone.setHalign(GtkAlign.END);
		grdDownloadManager.attach(fixDone, 1, 1, 1, 1);
		
		_btnDone = new Button("Done", &btnDone_Clicked, false);
		_btnDone.setSizeRequest(100, 40);
		fixDone.put(_btnDone, 0, 5);
		
		_wdwDownloadManager.showAll();
	}

	/*
	 * When the user clicks on any of the nodes in the treeview, find which node was clicked, and which column.
	 * If it was a video containing node, and the column was the one with the download/delete images, then either download or delete
	 * the video.
	 */
	bool tvVideos_ButtonRelease(Event e, Widget)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvVideos.getSelectedIter();

		if (!selectedItem)
		{
			return false;
		}

		//If there is a selected item, and it's value in column 0 is true then get the video details
		if (!selectedItem.getValueString(0))
		{
			return false;
		}

		double xPos, yPos;
		
		//If getting coords fails exit this method
		if (!e.getCoords(xPos, yPos))
		{
			return false;
		}

		TreePath path;
		TreeViewColumn column;
		int xRelative, yRelative;

		//If getting column fails exit this method
		if (!_tvVideos.getPathAtPos(cast(int)xPos, cast(int)yPos, path, column, xRelative, yRelative))
		{
			return false;
		}

		//If user has not clicked on the third column exit this method
		if (column.getTitle() != _imageColumnName)
		{
			return false;
		}

		int columnMidPoint = column.getWidth() / 2;

		//If user has clicked outside the download/delete icon exit this method
		if (xRelative < columnMidPoint - 10 || xRelative > columnMidPoint + 10)
		{
			return false;
		}

		//Get the treestore back out of the treeview
		//HACK In theory TreeStore store = cast(TreeStore)_tvVideos.GetModel(); should give the TreeStore, but is just returning null. BUG???
		TreeStore store = new TreeStore(cast(GtkTreeStore*)selectedItem.gtkTreeModel);

		//Get video url
		string url = selectedItem.getValueString(0);

		//Get the selected cell
		Value value = new Value();
		selectedItem.getValue(2, value);

		//Extract the image from the selected cell
		GdkPixbuf* selectedImage = cast(GdkPixbuf*)value.getObject();

		//So the image is stored in the treeview object as a pointer to GdkPixbuf
		//to find out what image is being clicked on compare it's GdkPixbuf to that
		//of the fixed images (remember to use pointers)
		if (selectedImage == _downloadImage.getPixbufStruct())
		{
			//When the user clicks the download image:
			//Change image to stop image and set progress column text to downloading
			//Store reference to current TreeIter for use while still downloading
			//Start downloading in another thread, this will report progress until download is complete
			//Update progress in progress column
			//Once download complete remove reference to TreeIter
			bool onwards = false;

			store.setValue(selectedItem, 2, _stopImage);
			store.setValue(selectedItem, 3, "Downloading...");

			_activeIters[url] = selectedItem;
			spawn(&DownloadWorker.downloadVideoAsync, url);

			while (!onwards)
			{
				receiveTimeout(
					dur!"msecs"(250),
					(ulong amountDownloaded, string childUrl, Tid childTid)
					{
					if (childUrl in _activeIters)
					{
						store.setValue(_activeIters[childUrl], 3, format("%s KB", amountDownloaded / 1024));
					}
					else
					{
						childTid.send(true);
					}
				},
				(bool success, string childUrl)
				{
					//Only reason filename wouldn't be in iters is if it was removed by stopImage in which case image and text have been updated already
					if (childUrl in _activeIters)
					{
						if (success)
						{
							store.setValue(_activeIters[childUrl], 2, _deleteImage);
						}
						else
						{
							store.setValue(_activeIters[childUrl], 2, _downloadImage);
						}
						
						store.setValue(_activeIters[childUrl], 3, "");
						
						_activeIters[childUrl].destroy();
						_activeIters.remove(childUrl);
					}
					
					onwards = true;
				});

				Functions.refreshUI();
			}

			//If user closes window before all downloads are done then code will crash here
			//unless ejected
			if (!_wdwDownloadManager)
			{
				//Window has been destroyed
				return false;
			}

			downloadedVideoSize();
		}
		else if (selectedImage == _stopImage.getPixbufStruct())
		{
			//When the user clicks the stop image:
			//Change the icon back to the download image and clear the process column
			//Remove the TreeIter item from activeIters this will cause the download receiver to respond
			//with a kill signal for the download thread, stopping it.
			store.setValue(_activeIters[url], 2, _downloadImage);
			store.setValue(_activeIters[url], 3, "");

			_activeIters[url].destroy();
			_activeIters.remove(url);
		}
		else if (selectedImage == _deleteImage.getPixbufStruct())
		{
			//When the user clicks the delete image:
			//If online
			//	Change the icon back to the download icon
			//If offline
			//	Remove the item from the tree
			//Delete the file
			//Recalc total video size on disk
			if (_isOffline)
			{
				store.remove(selectedItem);
			}
			else
			{
				store.setValue(selectedItem, 2, _downloadImage);
			}

			DownloadWorker.deleteVideo(url);
			downloadedVideoSize();
		}
		else
		{
			assert(0, "Invalid image type detected");
		}

		return false;
	}

	/*
	 * When user closes the download manager window by either the 'Done' button or forcing the window closed call the downloadManager_Closed method.
	 */
	void wdwDownloadManager_Destroyed(Widget)
	{
		debug output(__FUNCTION__);
		if (downloadManager_Closed)
		{
			downloadManager_Closed();
		}
	}
}