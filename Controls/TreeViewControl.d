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

import std.conv:to;
import std.array:split;
import std.string:lastIndexOf;

import gtk.ScrolledWindow;
import gtk.ButtonBox;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.Widget;
import gtk.CellRendererText;

import gdk.Event;

import KhanAcademyViewer.Controls.ViewControl;
import KhanAcademyViewer.Controls.VideoControl;
import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.Settings;

public final class TreeViewControl : ViewControl
{
	private TreeView _tvTree;
	private string _currentTreePath;

	public this(ScrolledWindow scrollParent, ScrolledWindow scrollChild, Library completeLibrary, VideoControl videoControl, Settings settings)
	{
		debug output(__FUNCTION__);
		_scrollParent = scrollParent;
		_scrollChild = scrollChild;
		_completeLibrary = completeLibrary;
		_vcVideo = videoControl;
		_settings = settings;

		BuildView();
	}

	public ~this()
	{
		debug output(__FUNCTION__);
		_scrollParent.removeAll();
		_scrollParent.setSizeRequest(_scrollChild.getWidth(), -1);
		_scrollChild.show();
	}

	public override void PreloadCategory(string treePath)
	{
		debug output(__FUNCTION__);
		_tvTree.expandToPath(new TreePath(treePath));
	}

	public override bool GetNextVideo(out Library returnVideo, out string returnPath)
	{
		debug output(__FUNCTION__);
		//Get current path and set path to next node
		TreeIter selectedItem = _tvTree.getSelectedIter();
		TreePath treePath = selectedItem.getTreePath();
		treePath.next;

		//Set tvTree to next node if possible - if this is the end of the current category
		//then tvTree doesn't change
		_tvTree.getSelection().selectPath(treePath);

		//Check if next node was actually selected
		if (treePath.compare(_tvTree.getSelectedIter().getTreePath()) == 0)
		{
			//New node has been selected, so set the library and path
			//Get the new nodes path
			string treePathString = treePath.toString();

			//Set current tree path to compare against when checking whether to load another video or not in button release method
			_currentTreePath = treePathString;

			//Iterate other the library to get the corrent video using the new treepath
			string[] paths = split(treePathString, ":");

			returnVideo = _completeLibrary;

			foreach (string path; paths)
			{
				returnVideo = returnVideo.Children[to!size_t(path)];
			}

			//Set returnPath to current treepath minus last item as this is used for the category not the video itself
			returnPath = treePathString[0 .. treePathString.lastIndexOf(":")];

			//Both the new video library and path have been set by here, so return true to tell the video player to keep
			//going with the next video
			return true;
		}
		else
		{
			//No next video so return false to tell the video player to stop
			return false;
		}
	}
	
	private void BuildView()
	{
		debug output(__FUNCTION__);
		_tvTree = new TreeView(CreateModel());

		_tvTree.setHeadersVisible(false);
		_tvTree.setEnableSearch(false);
		_tvTree.show();
		_tvTree.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		CreateColumns(_tvTree);
		_tvTree.addOnButtonRelease(&tvTree_ButtonRelease);

		_scrollChild.hide();
		_scrollParent.setSizeRequest(_scrollChild.getWidth() * 2, -1);

		_scrollParent.add(_tvTree);
	}
	
	private TreeStore CreateModel()
	{
		debug output(__FUNCTION__);
		if (!_completeLibrary)
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
			
			if (parentIter)
			{
				iter = treeStore.append(parentIter);
			}
			else
			{
				iter = treeStore.createIter();
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

	private bool tvTree_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvTree.getSelectedIter();

		//If there is a selected item, and it's value in column 0 is true then get the video details
		if (selectedItem && selectedItem.getValueInt(0))
		{
			string treePath = selectedItem.getTreePath().toString();

			//Only reload libray if the selection has changed i.e. don't load if clicking a parent item
			if (_currentTreePath != treePath)
			{
				//Use TreePath to iterate over library to get the selected value, can then get video details from this
				string[] paths = split(treePath, ":");
				Library currentVideo = _completeLibrary;
				
				foreach (string path; paths)
				{
					currentVideo = currentVideo.Children[to!size_t(path)];
				}

				//Pass in current treepath minus last item as this is used for the category not the video itself
				LoadVideo(currentVideo, treePath[0 .. treePath.lastIndexOf(":")], false);

				//Set current tree path to compare against when checking whether to load another video or not
				_currentTreePath = treePath;
			}
		}
		
		return false;
	}
}