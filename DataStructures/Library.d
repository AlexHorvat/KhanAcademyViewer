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

import KhanAcademyViewer.DataStructures.DownloadUrl;

import std.datetime;

public final class Library
{
	//TODO which of these fields am I going to use?

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

	public @property {
		long ChildrenLength() { return _children.length; }
		void ChildrenLength(long new_Length) { _children.length = new_Length; }
	}

	private string _description;
	public @property {
		string Description() { return _description; }
		void Description(string new_Description) { _description = new_Description; }
	}

	//TODO probably don't need this as calculating it when loading video
	private long _duration;
	public @property {
		long Duration() { return _duration; }
		void Duration(long new_Duration) { _duration = new_Duration; }
	}

	private int _views;
	public @property {
		int Views() { return _views; }
		void Views(int new_Views) { _views = new_Views; }
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

	private DownloadUrl _downloadUrls;
	public @property {
		DownloadUrl DownloadUrls() { return _downloadUrls; }
		void DownloadUrls(DownloadUrl new_DownloadUrls) { _downloadUrls = new_DownloadUrls; }
	}
}