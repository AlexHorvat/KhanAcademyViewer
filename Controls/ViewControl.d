/**
 * 
 * ViewControl.d
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
module KhanAcademyViewer.Controls.IViewControl;

import gtk.TreeView;
import gtk.ScrolledWindow;

import KhanAcademyViewer.DataStructures.Library;

protected interface IViewControl
{
	protected static ScrolledWindow _scrollParent;
	protected static ScrolledWindow _scrollChild;
	protected static Library _completeLibrary;

	protected static void delegate(Library) LoadVideo;

	protected void BuildView();

	protected void CreateColumns(TreeView treeView);
}