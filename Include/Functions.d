/*
 * Functions.d
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

module kav.Include.Functions;

debug alias std.stdio.writeln output;

import gtk.Main;

import kav.Include.Config;

import std.file;
import std.path:expandTilde;
import std.string:lastIndexOf;

public static class Functions
{

public:
	
	/**
	 * Get a hashtable of all currently downloaded files.
	 * Returns: Hashtable containing all paths of downloaded files.
	 */
	static bool[string] getDownloadedFiles()
	{
		debug output(__FUNCTION__);
		//Load all existing mp4 files into hashtable then pass to RecurseOfflineLibrary
		//this is faster than accessing the disc everytime to check if a file exists
		bool[string] downloadedFiles;
		string downloadDirectory = expandTilde(DOWNLOAD_FILE_PATH);

		foreach(DirEntry file; dirEntries(downloadDirectory, "*.mp4", SpanMode.shallow, false))
		{
			downloadedFiles[file[file.lastIndexOf("/") .. $]] = true;
		}

		downloadedFiles.rehash();
				
		return downloadedFiles;
	}

	/**
	 * Find the local file name of a supplied url.
	 * This is where a file would be stored if it has been downloaded.
	 * 
	 * Params:
	 * url = the remote file name.
	 * 
	 * Returns: The local file name - regardless of whether the file exists or not.
	 */
	static string getLocalFileName(string url)
	{
		return expandTilde(DOWNLOAD_FILE_PATH) ~ url[url.lastIndexOf("/") .. $];
	}

	/**
	 * Call the main gtk thread and process any pending UI updates.
	 * This makes sure the UI doesn't freeze up while other stuff is going on.
	 */
	static void refreshUI()
	{
		while (Main.eventsPending)
		{
			Main.iteration();
		}
	}
}