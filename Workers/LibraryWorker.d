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

module kav.Workers.LibraryWorker;

debug alias std.stdio.writeln output;

import kav.DataStructures.Library;
import kav.Include.Config;
import kav.Include.Functions;

import msgpack;

import std.array;
import std.concurrency;
import std.file;
import std.path;
import std.string;

public static class LibraryWorker
{

public:

	/**
	 * Check if the library is on local storage.
	 * 
	 * Returns: Bool of whether or not the file is on local storage.
	 */
	static bool libraryFileExists()
	{
		debug output(__FUNCTION__);
		string libraryFileName = expandTilde(LIBRARY_FILE_PATH);

		return exists(libraryFileName);
	}

	/**
	 * Retrieve the library from local storage.
	 * Sends a true bool on failure.
	 * Sends the library on success.
	 */
	static void loadLibraryAsync()
	{
		debug output(__FUNCTION__);
		shared Library onlineLibrary;

		scope(success)ownerTid.send(onlineLibrary);
		scope(failure)ownerTid.send(true); //Handle error in this thread

		onlineLibrary = cast(shared)loadLibrary();
	}

	/**
	 * Load the library from local storage, but then parse it to only show downloaded videos.
	 * Sends a true bool on failure.
	 * Sends the library on success.
	 */
	static void loadOfflineLibraryAsync()
	{
		debug output(__FUNCTION__);
		shared Library offlineLibrary;

		scope(success)ownerTid.send(offlineLibrary);
		scope(failure)ownerTid.send(true); //Handle error in this thread

		offlineLibrary = cast(shared)recurseOfflineLibrary(loadLibrary(), Functions.getDownloadedFiles());
	}

private:
	/**
	 * Load the library file from local storage and de-serialise it.
	 * 
	 * Returns: The Library object.
	 */
	static Library loadLibrary()
	{
		debug output(__FUNCTION__);
		Library completeLibrary;
		string libraryFileName = expandTilde(LIBRARY_FILE_PATH);
		ubyte[] serialised = cast(ubyte[])read(libraryFileName);

		//Convert the serialised library back into a Library object
		unpack(serialised, completeLibrary);

		return completeLibrary;
	}

	/**
	 * Create a new empty Library then loop over each item in a supplied Library object and check if the Library object's video is downloaded.
	 * If it is add that Library object to the new Library, if not ignore it.
	 * 
	 * Params:
	 * currentLibrary = the complete library to loop over.
	 * downloadedFiles = a hashtable containing all downloaded files.
	 * 
	 * Returns: A Library containing only Library objects with downloaded videos (or the parents them).
	 */
	static Library recurseOfflineLibrary(Library currentLibrary, bool[string] downloadedFiles)
	{
		debug output(__FUNCTION__);
		//If current library has children, recurse down another level and replace it's children with updated values
		if (currentLibrary.children)
		{
			Appender!(Library[], Library) appendLibrary = appender!(Library[], Library);

			foreach(Library childLibrary; currentLibrary.children)
			{
				Library newChildLibrary = recurseOfflineLibrary(childLibrary, downloadedFiles);

				if (newChildLibrary)
				{
					appendLibrary.put(newChildLibrary);
				}
			}

			if (appendLibrary.data)
			{
				currentLibrary.children = appendLibrary.data;
				return currentLibrary;
			}
			else
			{
				return null;
			}
		}
		//This is a video containing library, check if video exists on disc, if so return the library
		else if (currentLibrary.mp4 != null && currentLibrary.mp4[currentLibrary.mp4.lastIndexOf("/") .. $] in downloadedFiles)
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