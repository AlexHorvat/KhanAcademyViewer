//
//  Library.d
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

module KhanAcademyViewer.DataStructures.Library;

import std.datetime;

public final class Library
{
	private string _title;
	public @property {
		string Title() { return _title; }
		void Title(string new_Title) { _title = new_Title; }
	}

	private Library[] _children;
	public @property {
		Library[] Children() { return _children; }
		void Children(Library[] new_Children) { _children = new_Children; }
	}

	private string _description;
	public @property {
		string Description() { return _description; }
		void Description(string new_Description) { _description = new_Description; }
	}

	private string[] _authorNames;
	public @property {
		string[] AuthorNames() { return _authorNames; }
		void AuthorNames(string[] new_AuthorNames) { _authorNames = new_AuthorNames; }
	}

	public @property {
		long AuthorNamesLength() { return _authorNames.length; }
		void AuthorNamesLength(long new_Length) { _authorNames.length = new_Length; }
	}

	private DateTime _dateAdded;
	public @property {
		DateTime DateAdded() { return _dateAdded; }
		void DateAdded(DateTime new_DateAdded) { _dateAdded = new_DateAdded; }
	}

	private string _mp4;
	public @property {
		string MP4() { return _mp4; }
		void MP4(string new_MP4) { _mp4 = new_MP4; }
	}

	public void AddChildLibrary(Library new_ChildLibrary)
	{
		_children.length++;
		_children[_children.length - 1] = new_ChildLibrary;
	}
}