/*
 * FlowViewControl.d
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

module kav.Controls.FlowViewControl;

debug alias std.stdio.writeln output;

import gdk.Event;

import gtk.Button;
import gtk.ButtonBox;
import gtk.CellRendererText;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeSelection;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;

import kav.DataStructures.BreadCrumb;
import kav.DataStructures.Library;
import kav.DataStructures.Settings;
import kav.Controls.VideoControl;
import kav.Controls.ViewControl;

import std.conv:to;
import std.string:split;

public final class FlowViewControl : ViewControl
{

public:
		
	this(ScrolledWindow scrollParent, ScrolledWindow scrollChild, ButtonBox bboxBreadCrumbs, Library completeLibrary, VideoControl videoControl, Settings settings)
	{
		debug output(__FUNCTION__);
		_scrollParent = scrollParent;
		_scrollChild = scrollChild;
		_bboxBreadCrumbs = bboxBreadCrumbs;
		_completeLibrary = completeLibrary;
		_parentLibrary = completeLibrary;
		_vcVideo = videoControl;
		_settings = settings;

		buildView();
	}
	
	~this()
	{
		debug output(__FUNCTION__);
		_scrollParent.removeAll();
		_scrollChild.removeAll();
		_bboxBreadCrumbs.removeAll();
	}

	/*
	 * Check if there is another item on the current library branch, if so, return the path to the next video.
	 * 
	 * Params:
	 * returnVideo = a Library object for the next video to load.
	 * returnPath = a string containing a treepath value for the next video.
	 * 
	 * Returns: bool of whether or not there is another video to load.
	 */
	override bool getNextVideo(out Library returnVideo, out string returnPath)
	{
		debug output(__FUNCTION__);
		//Get current path and set path to next node
		TreeIter selectedItem = _tvChild.getSelectedIter();
		TreePath treePath = selectedItem.getTreePath();
		treePath.next;
		
		//Set tvTree to next node if possible - if this is the end of the current category
		//then tvTree doesn't change
		_tvChild.getSelection().selectPath(treePath);
		
		//Check if next node was actually selected
		if (treePath.compare(_tvChild.getSelectedIter().getTreePath()) == 0)
		{
			//Generate equivalent of treepath.toString()
			foreach(BreadCrumb breadCrumb; _breadCrumbs)
			{
				returnPath ~= to!(string)(breadCrumb.rowIndex);
				returnPath ~= ":";
			}
			
			returnPath = returnPath[0 .. $ - 1];
			
			int rowIndex = _tvChild.getSelectedIter().getValueInt(0);
			returnVideo = _childLibrary.children[rowIndex];
			
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

	/*
	 * Automatically select the last video category the user was watching a video from.
	 */
	override void preloadCategory()
	{
		debug output(__FUNCTION__);
		if (_settings && _settings.keepPosition && _settings.lastSelectedCategory != "")
		{
			//There's a variety of things that can go wrong while preloading - but none really matter
			//So if something goes wrong abandon the preload
			try
			{
				int childRowIndex;
				string[] paths = split(_settings.lastSelectedCategory, ":");

				_parentLibrary = _completeLibrary;

				//Set the parent library(ies)
				foreach(string path; paths[0 .. $ - 1])
				{
					childRowIndex = to!int(path);
					_parentLibrary = _parentLibrary.children[childRowIndex];

					//Add the parent item breadcrumbs
					BreadCrumb crumb = new BreadCrumb();

					crumb.rowIndex = childRowIndex;
					crumb.title = _parentLibrary.title;

					_breadCrumbs ~= crumb;
				}
				
				_tvParent.setModel(createModel(true));
				
				//Set child library to last breadcrumb item
				childRowIndex = to!int(paths[$ - 1]);

				//Set the child library
				_childLibrary = _parentLibrary.children[childRowIndex];

				//Add the final item to the breadcrumbs
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.rowIndex = childRowIndex;
				crumb.title = _childLibrary.title;
				
				_breadCrumbs ~= crumb;

				//Load the child library model
				_tvChild.setModel(createModel(false));
				
				//Pre-set the selected item in parent treeview
				TreeSelection selection = _tvParent.getSelection();
				selection.selectPath(new TreePath(childRowIndex));
			}
			//If anything goes wrong with the preloading just swallow the error and don't load breadcumbs (or preload)
			catch
			{
				return;
			}

			//Refresh bread crumbs
			loadBreadCrumbs();
		}
	}
  
private:

	ButtonBox		_bboxBreadCrumbs;
	int				_breadCrumbAvailableWidth;
	BreadCrumb[]	_breadCrumbs;
	Library			_childLibrary;
	Library			_parentLibrary;
	TreeView		_tvChild;
	TreeView		_tvParent;

	/*
	 * One of the breadcrumb buttons have been clicked by the user, load the selected library category.
	 * 
	 * Params:
	 * sender = the breadcrumb button clicked.
	 */
	void breadButton_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		//Cut _breadCrumbs down to breadCrumbIndex length, then set the parent and child to the last two breadcrumb items
		int breadCrumbNewLength = to!int(sender.getName());
		_breadCrumbs.length = breadCrumbNewLength;
		
		//Set parent library to 2nd to last breadcrumb item
		_parentLibrary = _completeLibrary;
		
		//foreach(size_t breadCrumbCounter; 0 .. _breadCrumbs.length - 1)
		foreach(BreadCrumb crumb; _breadCrumbs[0 .. $ - 1])
		{
			//_parentLibrary = _parentLibrary.Children[_breadCrumbs[breadCrumbCounter].RowIndex];
			_parentLibrary = _parentLibrary.children[crumb.rowIndex];
		}
		
		_tvParent.setModel(createModel(true));
		
		//Set child library to last breadcrumb item
		int childRowIndex = _breadCrumbs[$ - 1].rowIndex;
		
		_childLibrary = _parentLibrary.children[childRowIndex];
		_tvChild.setModel(createModel(false));
		
		//Pre-set the selected item in parent treeview
		TreePath path = new TreePath(childRowIndex);
		TreeSelection selection = _tvParent.getSelection();
		selection.selectPath(path);
		
		//Refresh bread crumbs
		loadBreadCrumbs();
	}

	/*
	 * Create and show all the controls needed to show the flow view.
	 */
	void buildView()
	{
		debug output(__FUNCTION__);
		_tvParent = new TreeView(createModel(true));

		_tvParent.setHeadersVisible(false);
		_tvParent.setEnableSearch(false);
		_tvParent.show();
		_tvParent.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		_tvChild = new TreeView();

		_tvChild.setHeadersVisible(false);
		_tvChild.setEnableSearch(false);
		_tvChild.show();
		_tvChild.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		//Setup flow mode
		createColumns(_tvParent);
		createColumns(_tvChild);

		_tvParent.addOnButtonRelease(&tvParent_ButtonRelease);
		_tvChild.addOnButtonRelease(&tvChild_ButtonRelease);

		_breadCrumbAvailableWidth = _scrollParent.getWidth() + _scrollChild.getWidth();

		_scrollParent.add(_tvParent);
		_scrollChild.add(_tvChild);
	}

	/*
	 * Create columns for a TreeView object that will allow loading the Library objects.
	 * 
	 * Params:
	 * treeView = the TreeView object to create columns for.
	 */
	void createColumns(TreeView treeView)
	{
		debug output(__FUNCTION__);
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("Index", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		
		indexColumn.setVisible(false);
		
		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	/*
	 * Create and load the model for the TreeView object displaying the Library objects.
	 * 
	 * Params:
	 * isParentTree = Whether this is the parent treeview (the left hand one) or the child (the right), they load different libraries.
	 * 
	 * Returns: A ListStore object for the TreeView to display.
	 */
	ListStore createModel(bool isParentTree)
	{
		debug output(__FUNCTION__);
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
		
		if (!workingLibrary)
		{
			return null;
		}

		foreach(size_t index; 0 .. workingLibrary.children.length)
		{
			listStore.append(tree);
			listStore.setValue(tree, 0, cast(int)index);
			listStore.setValue(tree, 1, workingLibrary.children[index].title);
		}
		
		return listStore;
	}

	/*
	 * Load the breadcrumb buttons by iterating over the _breadCrumbs object.
	 */
	void loadBreadCrumbs()
	{
		debug output(__FUNCTION__);
		//Clear existing breadcrumb buttons
		_bboxBreadCrumbs.removeAll();
		
		//Get the size available for each bread crumb button, and the maximum length allowed for the title
		if (_breadCrumbs && _breadCrumbs.length != 0)
		{
			int breadCrumbWidth = _breadCrumbAvailableWidth / cast(int)_breadCrumbs.length - 8;
			int titleLength = breadCrumbWidth / 8;
			
			foreach(size_t breadCrumbIndex; 0 .. _breadCrumbs.length)
			{
				string title = _breadCrumbs[breadCrumbIndex].title;
				
				if (title.length > titleLength)
				{
					title = title[0 .. titleLength - 3] ~ "...";
				}
				
				Button breadButton = new Button(title, false);
				
				breadButton.setName(to!string(breadCrumbIndex + 1));
				breadButton.setTooltipText(_breadCrumbs[breadCrumbIndex].title);
				breadButton.setAlignment(0.0, 0.5);
				breadButton.setSizeRequest(breadCrumbWidth, -1);
				breadButton.show();
				breadButton.addOnClicked(&breadButton_Clicked);
				
				_bboxBreadCrumbs.add(breadButton);
			}
		}
	}

	/*
	 * When the user clicks on an item in the child treeview, either move the current items in the child treeview into the parent treeview and load
	 * this item's child libraries, or, if this library has no children, load the item's associated video.
	 * 
	 */
	bool tvChild_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvChild.getSelectedIter();
		
		if (selectedItem)
		{
			int rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);
			
			//If this child has children then make this a parent and it's child the new child
			//Otherwise this is the end of the tree - play the video
			if (_childLibrary.children[rowIndex].children)
			{
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.rowIndex = rowIndex;
				crumb.title = title;
				_breadCrumbs ~= crumb;
				
				//Update parent and child libraries - this will move the current child library over to the parent position
				//and set the new child to be the child's chlid library
				_parentLibrary = _childLibrary;
				_childLibrary = _parentLibrary.children[rowIndex];
				
				_tvParent.setModel(createModel(true));
				_tvChild.setModel(createModel(false));
				
				loadBreadCrumbs();
			}
			else
			{
				//Generate equivalent of treepath.toString()
				string path;
				
				foreach(BreadCrumb breadCrumb; _breadCrumbs)
				{
					path ~= to!(string)(breadCrumb.rowIndex);
					path ~= ":";
				}
				
				loadVideo(_childLibrary.children[rowIndex], path[0 .. $ - 1], false);
			}
		}
		
		//Stop any more signals being called
		return true;
	}

	/*
	 * When the user clicks on an item in the parent treeview load up the item's child libraries into the child treeview.
	 */
	bool tvParent_ButtonRelease(Event, Widget)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvParent.getSelectedIter();
		
		if (selectedItem)
		{
			size_t rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);
			
			//If there are no breadcrumbs yet create a new breadcrumb
			if (_breadCrumbs.length == 0)
			{
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.rowIndex = cast(int)rowIndex;
				crumb.title = title;

				_breadCrumbs ~= crumb;
			}
			//But usually there will be some breadcrumbs, as this is a parent item there will already be a breadcrumb
			//entry for it, so overwrite that entry
			else
			{
				_breadCrumbs[$ - 1].rowIndex = cast(int)rowIndex;
				_breadCrumbs[$ - 1].title = title;
			}
			
			//Parent library doesn't change, just set child library then reload child treeview
			_childLibrary = _parentLibrary.children[rowIndex];
			_tvChild.setModel(createModel(false));
			
			loadBreadCrumbs();
		}
		
		//Stop any more signals being called
		return true;
	}
}