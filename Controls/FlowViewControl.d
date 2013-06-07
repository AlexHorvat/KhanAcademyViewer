/**
 * 
 * FlowControl.d
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
module KhanAcademyViewer.Controls.FlowViewControl;

debug alias std.stdio.writeln output;

import std.conv;
import std.string;

import gtk.ScrolledWindow;
import gtk.ButtonBox;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreePath;
import gtk.TreeIter;
import gtk.TreeSelection;
import gtk.ListStore;
import gtk.Widget;
import gtk.CellRendererText;
import gtk.Button;

import gdk.Event;

import KhanAcademyViewer.Controls.ViewControl;
import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.BreadCrumb;

public final class FlowViewControl : ViewControl
{
	private ButtonBox _bboxBreadCrumbs;
	private Library _parentLibrary;
	private Library _childLibrary;
	private TreeView _tvParent;
	private TreeView _tvChild;
	private int _breadCrumbAvailableWidth;
	private BreadCrumb[] _breadCrumbs;

	public this(ScrolledWindow scrollParent, ScrolledWindow scrollChild, ButtonBox bboxBreadCrumbs, Library completeLibrary, void delegate(Library) loadVideoMethod)
	{
		debug output(__FUNCTION__);
		_scrollParent = scrollParent;
		_scrollChild = scrollChild;
		_bboxBreadCrumbs = bboxBreadCrumbs;
		_completeLibrary = completeLibrary;
		_parentLibrary = completeLibrary;
		LoadVideo = loadVideoMethod;

		BuildView();
	}
	
	public ~this()
	{
		debug output(__FUNCTION__);
		_scrollParent.removeAll();
		_scrollChild.removeAll();
		_bboxBreadCrumbs.removeAll();
	}
	
	private void BuildView()
	{
		debug output(__FUNCTION__);
		_tvParent = new TreeView(CreateModel(true));

		_tvParent.setHeadersVisible(false);
		_tvParent.setEnableSearch(false);
		_tvParent.setVisible(true);
		_tvParent.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		_tvChild = new TreeView();

		_tvChild.setHeadersVisible(false);
		_tvChild.setEnableSearch(false);
		_tvChild.setVisible(true);
		_tvChild.addEvents(GdkEventMask.BUTTON_RELEASE_MASK);

		//Setup flow mode
		CreateColumns(_tvParent);
		CreateColumns(_tvChild);

		_tvParent.addOnButtonRelease(&tvParent_ButtonRelease);
		_tvChild.addOnButtonRelease(&tvChild_ButtonRelease);

		_breadCrumbAvailableWidth = _scrollParent.getWidth() + _scrollChild.getWidth();

		_scrollParent.add(_tvParent);
		_scrollChild.add(_tvChild);
	}

	private ListStore CreateModel(bool isParentTree)
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

		foreach(size_t index; 0 .. workingLibrary.Children.length)
		{
			listStore.append(tree);
			listStore.setValue(tree, 0, cast(int)index);
			listStore.setValue(tree, 1, workingLibrary.Children[index].Title);
		}
		
		return listStore;
	}

	private void CreateColumns(TreeView treeView)
	{
		debug output(__FUNCTION__);
		CellRendererText renderer = new CellRendererText();
		TreeViewColumn indexColumn = new TreeViewColumn("Index", renderer, "text", 0);
		TreeViewColumn titleColumn = new TreeViewColumn("Topic", renderer, "text", 1);
		
		indexColumn.setVisible(false);
		
		treeView.appendColumn(indexColumn);
		treeView.appendColumn(titleColumn);
	}

	private bool tvParent_ButtonRelease(Event e, Widget sender)
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
				
				crumb.RowIndex = cast(int)rowIndex;
				crumb.Title = title;
				
				_breadCrumbs.length = 1;
				_breadCrumbs[0] = crumb;
			}
			//But usually there will be some breadcrumbs, as this is a parent item there will already be a breadcrumb
			//entry for it, so overwrite that entry
			else
			{
				_breadCrumbs[_breadCrumbs.length - 1].RowIndex = cast(int)rowIndex;
				_breadCrumbs[_breadCrumbs.length - 1].Title = title;
			}
			
			//Parent library doesn't change, just set child library then reload child treeview
			_childLibrary = _parentLibrary.Children[rowIndex];
			_tvChild.setModel(CreateModel(false));
			
			LoadBreadCrumbs();
		}
		
		//Stop any more signals being called
		return true;
	}
	
	private bool tvChild_ButtonRelease(Event e, Widget sender)
	{
		debug output(__FUNCTION__);
		TreeIter selectedItem = _tvChild.getSelectedIter();
		
		if (selectedItem)
		{
			size_t rowIndex = selectedItem.getValueInt(0);
			string title = selectedItem.getValueString(1);
			
			//If this child has children then make this a parent and it's child the new child
			//Otherwise this is the end of the tree - play the video
			if (_childLibrary.Children[rowIndex].Children)
			{
				BreadCrumb crumb = new BreadCrumb();
				
				crumb.RowIndex = cast(int)rowIndex;
				crumb.Title = title;
				
				_breadCrumbs.length = _breadCrumbs.length + 1;
				_breadCrumbs[_breadCrumbs.length - 1] = crumb;
				
				//Update parent and child libraries - this will move the current child library over to the parent position
				//and set the new child to be the child's chlid library
				_parentLibrary = _childLibrary;
				_childLibrary = _parentLibrary.Children[rowIndex];
				
				_tvParent.setModel(CreateModel(true));
				_tvChild.setModel(CreateModel(false));
				
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

	private void LoadBreadCrumbs()
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

	private void breadButton_Clicked(Button sender)
	{
		debug output(__FUNCTION__);
		//Cut _breadCrumbs down to breadCrumbIndex length, then set the parent and child to the last two breadcrumb items
		int breadCrumbNewLength = to!int(sender.getName());
		_breadCrumbs.length = breadCrumbNewLength;
		
		//Set parent library to 2nd to last breadcrumb item
		_parentLibrary = _completeLibrary;
		
		foreach(size_t breadCrumbCounter; 0 .. _breadCrumbs.length - 1)
		{
			_parentLibrary = _parentLibrary.Children[_breadCrumbs[breadCrumbCounter].RowIndex];
		}
		
		_tvParent.setModel(CreateModel(true));
		
		//Set child library to last breadcrumb item
		int childRowIndex = _breadCrumbs[_breadCrumbs.length - 1].RowIndex;
		
		_childLibrary = _parentLibrary.Children[childRowIndex];
		_tvChild.setModel(CreateModel(false));
		
		//Pre-set the selected item in parent treeview
		TreePath path = new TreePath(childRowIndex);
		TreeSelection selection = _tvParent.getSelection();
		selection.selectPath(path);
		
		//Refresh bread crumbs
		LoadBreadCrumbs();
	}
}