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

debug alias std.stdio.writeln output;

import std.path;
import std.file;
import std.string;

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

	public static Library LoadOfflineLibrary()
	{
		debug output("LoadOfflineLibrary");
		Library offlineLibrary = RecurseOfflineLibrary(LoadLibrary(), GetDownloadedFiles());

		return offlineLibrary;
	}

	private static bool[string] GetDownloadedFiles()
	{
		//Load all existing mp4 files into hashtable then pass to RecurseOfflineLibrary
		//this is faster than accessing the disc everytime to check if a file exists
		bool[string] downloadedFiles;
		string downloadDirectory = expandTilde(G_DownloadFilePath);

		foreach(DirEntry file; dirEntries(downloadDirectory, "*.mp4", SpanMode.shallow, false))
		{
			downloadedFiles[file[file.lastIndexOf("/") .. $]] = true;
		}

		return downloadedFiles;
	}

	private static Library RecurseOfflineLibrary(Library currentLibrary, bool[string] downloadedFiles)
	{
		debug output("RecurseOfflineLibrary");
		//If current library has children, recurse down another level and replace it's children with updated values
		if (currentLibrary.Children !is null)
		{
			Library[] currentChildren = currentLibrary.Children;
			currentLibrary.Children = null;

			foreach(Library childLibrary; currentChildren)
			{
				Library newChildLibrary = RecurseOfflineLibrary(childLibrary, downloadedFiles);

				if (newChildLibrary !is null)
				{
					currentLibrary.AddChildLibrary(newChildLibrary);
				}
			}

			if (currentLibrary.Children is null)
			{
				return null;
			}
			else
			{
				return currentLibrary;
			}
		}
		//This is a video containing library, check if video exists on disc, if so return the library
		else if (currentLibrary.MP4[currentLibrary.MP4.lastIndexOf("/") .. $] in downloadedFiles)
		{
			return currentLibrary;
		}
		//Video isn't on disc return null
		else
		{
			return null;
		}
	}
}