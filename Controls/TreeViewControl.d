/**
 * 
 * TreeViewControl.d
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
module KhanAcademyViewer.Controls.TreeViewControl;

debug alias std.stdio.writeln output;

import std.conv;
import std.string;

import gtk.ScrolledWindow;
import gtk.ButtonBox;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeStore;
import gtk.TreeIter;
import gtk.Widget;
import gtk.CellRendererText;

import gdk.Event;

import KhanAcademyViewer.Controls.ViewControl;
import KhanAcademyViewer.DataStructures.Library;

protected final class TreeViewControl : ViewControl
{
	private TreeView _tvTree;
	
	this(ScrolledWindow scrollParent, ScrolledWindow scrollChild, Library completeLibrary, void delegate(Library) loadVideoMethod)
	{
		debug output(__FUNCTION__);
		_scrollParent = scrollParent;
		_scrollChild = scrollChild;
		_completeLibrary = completeLibrary;
		LoadVideo = loadVideoMethod;

		BuildView();
	}

	~this()
	{
		debug output(__FUNCTION__);
		_scrollParent.removeAll();
		_scrollParent.setSizeRequest(_scrollChild.getWidth(), -1);
		_scrollChild.setVisible(true);
	}
	
	private void BuildView()
	{
		debug output(__FUNCTION__);
		_tvTree = new TreeView(CreateModel());

		_tvTree.setHeadersVisible(false);
		_tvTree.setEnableSearch(false);
		_tvTree.setVisible(true);
		_tvTree.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		CreateColumns(_tvTree);
		_tvTree.addOnButtonRelease(&tvTree_ButtonRelease);

		_scrollChild.setVisible(false);
		_scrollParent.setSizeRequest(_scrollChild.getWidth() * 2, -1);

		_scrollParent.add(_tvTree);
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
		TreeViewColumn indexColumn = new TreeViewColumn("HasVideo", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		
		indexColumn.setVisible(false);
		
		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private bool tvTree_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvTree.getSelectedIter();
		
		//If there is a selected item, and it's value in column 0 is true then get the video details
		if (selectedItem !is null && selectedItem.getValueInt(0))
		{
			//Use TreePath to iterate over library to get the selected value, can then get video details from this
			Library currentVideo = _completeLibrary;
			string[] paths = split(selectedItem.getTreePath().toString(), ":");
			
			foreach (string path; paths)
			{
				currentVideo = currentVideo.Children[to!size_t(path)];
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
}