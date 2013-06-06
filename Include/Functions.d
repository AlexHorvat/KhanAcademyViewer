/**
 * 
 * Functions.d
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
module KhanAcademyViewer.Include.Functions;

debug alias std.stdio.writeln output;

import std.file;
import std.path;
import std.string;

import gtk.Main;

import KhanAcademyViewer.Include.Config;

protected final void RefreshUI()
{
	//Run any gtk events pending to refresh the UI
	while (Main.eventsPending)
	{
		Main.iteration();
	}
}

protected bool[string] GetDownloadedFiles()
{
	debug output(__FUNCTION__);
	//Load all existing mp4 files into hashtable then pass to RecurseOfflineLibrary
	//this is faster than accessing the disc everytime to check if a file exists
	bool[string] downloadedFiles;
	string downloadDirectory = expandTilde(G_DownloadFilePath);
	
	foreach(DirEntry file; dirEntries(downloadDirectory, "*.mp4", SpanMode.shallow, false))
	{
		downloadedFiles[file[file.lastIndexOf("/") .. $]] = true;
	}
	
	downloadedFiles.rehash();
	
	return downloadedFiles;
}