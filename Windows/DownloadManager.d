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

import gtk.Window;
import gtk.Builder;
import gtk.Button;
import gtk.Statusbar;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TreeStore;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRendererPixbuf;
import gtk.CellRendererProgress;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Workers.LibraryWorker;

//TODO
//Images for tree, also act as buttons
//Total downloaded files size for status bar

public final class DownloadManager
{
	private immutable string _gladeFile = "./Windows/DownloadManager.glade";

	private Library _completeLibrary;
	private Window _wdwDownloadManager;
	private Statusbar _statusDownloads;
	private TreeView _tvVideos;
	private Button _btnDone;

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
	}

	private TreeStore CreateModel()
	{
		debug output(__FUNCTION__);
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
			
			treeStore.setValue(iter, 0, childLibrary.MP4 != "");
			treeStore.setValue(iter, 1, childLibrary.Title);
			
			RecurseTreeChildren(treeStore, childLibrary, iter);
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

		indexColumn.setVisible(false);
		
		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private void btnDone_Clicked(Button sender)
	{
		destroy(this);
	}

	private void DownloadedVideoSize()
	{
		//TODO
		//Set item on status bar with total size of videos in download directory
	}
}