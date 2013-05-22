//
//  LibraryWorker.d
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

module KhanAcademyViewer.Workers.LibraryWorker;

import std.path;
import std.file;

import msgpack;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Include.Config;

public static class LibraryWorker
{
	public static bool LibraryFileExists()
	{
		string libraryFileName = expandTilde(G_LibraryFilePath);

		return exists(libraryFileName);
	}

	public static Library LoadLibrary()
	{
		Library completeLibrary;
		string libraryFileName = expandTilde(G_LibraryFilePath);
		ubyte[] serialised = cast(ubyte[])read(libraryFileName);

		//Convert the serialised library back into a Library object
		unpack(serialised, completeLibrary);

		return completeLibrary;
	}
}