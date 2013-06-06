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
import gtk.CellRendererProgress;
import gtk.Image;

import gdk.Pixbuf;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Workers.LibraryWorker;
import KhanAcademyViewer.Include.Config;
import KhanAcademyViewer.Include.Functions;

//TODO
//Images for tree, also act as buttons

public final class DownloadManager
{
	private immutable string _gladeFile = "./Windows/DownloadManager.glade";
	
	private Library _completeLibrary;
	private Window _wdwDownloadManager;
	private Statusbar _statusDownloads;
	private TreeView _tvVideos;
	private Button _btnDone;
	private Pixbuf _downloadImage;
	private Pixbuf _deleteImage;

	public this()
	{
		debug output(__FUNCTION__);
		_completeLibrary = LibraryWorker.LoadLibrary();

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

		_downloadImage = imageSetter.renderIconPixbuf("gtk-save", GtkIconSize.DND);

		_deleteImage = imageSetter.renderIconPixbuf("gtk-delete", GtkIconSize.DND);
		
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
		_tvVideos.addOnRowActivated(&tvVideos_RowActivated);
	}

	private void tvVideos_RowActivated(TreePath path, TreeViewColumn column, TreeView tree)
	{
		debug output("Tree clicked");
		debug output("Path ", path, " Column ", column, " Tree ", tree);
		debug output(column.getTitle());

		//TODO
		//Check if column is image column and if it has a video and what the icon is
		//If is image column and has video then
			//If icon is download then download file (show progress?)
			//If icon is delete then delete file
		//In both cases change the icon
	}

	private TreeStore CreateModel()
	{
		debug output(__FUNCTION__);
		if (_completeLibrary is null)
		{
			return null;
		}
		
		TreeStore treeStore = new TreeStore([GType.INT, GType.STRING, Pixbuf.getType()]);

		debug output("treestore ", treeStore);
		
		RecurseTreeChildren(treeStore, _completeLibrary, null, GetDownloadedFiles());
		
		return treeStore;
	}
	
	private void RecurseTreeChildren(TreeStore treeStore, Library library, TreeIter parentIter, bool[string] downloadedFiles)
	{
		debug output(__FUNCTION__);

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

			//Fill the rows
			treeStore.setValue(iter, 1, childLibrary.Title);

			//If there is no video link just load a text only row
			if (childLibrary.MP4 == "")
			{
				treeStore.setValue(iter, 0, false);
			}
			//If there is a video link, see if the video already exists, if it does, show the delete icon
			//otherwise show the download icon
			else
			{
				treeStore.setValue(iter, 0, true);

				if (childLibrary.MP4[childLibrary.MP4.lastIndexOf("/") .. $] in downloadedFiles)
				{
					treeStore.setValue(iter, 2, _deleteImage);
				}
				else
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
		TreeViewColumn indexColumn = new TreeViewColumn("HasVideo", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		TreeViewColumn imageColumn = new TreeViewColumn("Image", imageRenderer, "pixbuf", 2);

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