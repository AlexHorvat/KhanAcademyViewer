/**
 * 
 * DownloadWorker.d
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

module KhanAcademyViewer.Workers.DownloadWorker;

import std.json;
import std.net.curl;
import std.path;
import std.datetime;
import std.string;
import std.file;
import std.concurrency;

import msgpack;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.DownloadUrl;
import KhanAcademyViewer.Include.Config;

debug alias std.stdio.writeln output;

public static class DownloadWorker
{
	public static void NeedToDownloadLibrary(Tid parentThread)
	{
		string eTag;
		
		if (LoadETagFromDisk(eTag) && LibraryExists())
		{
			HTTP connection = HTTP(G_TopicTreeUrl);

			connection.method = HTTP.Method.head;
			connection.perform();
			
			string newETag = connection.responseHeaders["etag"];

			parentThread.send(newETag != eTag);
		}
		else
		{
			parentThread.send(true);
		}
	}

	public static void DownloadLibrary(Tid parentThread)
	{
		string eTag, jsonValues;
		Library completeLibrary;

		DownloadJson(eTag, jsonValues, parentThread);
		SaveETag(eTag);
		completeLibrary = ConvertJsonToLibrary(parseJSON(jsonValues).object);
		SaveLibrary(completeLibrary);
	}

	private static bool LoadETagFromDisk(out string eTag)
	{
		string eTagFileName = expandTilde(G_ETagFilePath);
		
		if (exists(eTagFileName))
		{
			eTag = readText(eTagFileName);
			return true;
		}
		else
		{
			return false;
		}
	}

	private static bool LibraryExists()
	{
		string libraryFileName = expandTilde(G_LibraryFilePath);

		return exists(libraryFileName);
	}

	private static void DownloadJson(out string eTag, out string jsonValues, Tid parentThread)
	{
		//Download whole library in json format
		HTTP connection = HTTP();

		connection.onProgress = delegate int(ulong dltotal, ulong dlnow, ulong ultotal, ulong ulnow)
		{
			//Send a progress update to the parent of this thread
			parentThread.send(dlnow);
			return 0;
		};

		jsonValues = cast(string)get(G_TopicTreeUrl, connection);
		eTag = connection.responseHeaders["etag"];
		connection.destroy();

		//Send the kill signal back to the parent of this thread
		//Can't just send bool as this seems to get interpreted as a ulong
		//so sending back parentThread just to have something to send
		parentThread.send(parentThread);
	}

	private static void SaveETag(string eTag)
	{	
		string eTagFileName = expandTilde(G_ETagFilePath);
		string filePath = dirName(eTagFileName);
		
		//Create directory if it doesn't exist
		if (!exists(filePath))
		{
			mkdirRecurse(filePath);
		}
		
		//Write the file - overwrite if already exists
		write(eTagFileName, eTag);
	}

	private static Library ConvertJsonToLibrary(JSONValue[string] json)
	{
		Library library = new Library();
		
		//Check if there is an author_names object at all
		if ("author_names" in json)
		{
			JSONValue[] jsonAuthorNames = json["author_names"].array;
			
			//Now check if there are any entries in the author_names
			if (jsonAuthorNames.length != 0)
			{
				//There are author_names, loop thru and add them to library
				debug output("setting authors length to ", jsonAuthorNames.length);
				library.AuthorNamesLength = jsonAuthorNames.length;
				
				foreach(authorCounter; 0 .. jsonAuthorNames.length)
				{
					library.AuthorNames[authorCounter] = jsonAuthorNames[authorCounter].str;
				}
			}
		}
		
		if ("date_added" in json)
		{
			debug output("adding date ", DateTime.fromISOExtString(chomp(json["date_added"].str, "Z")));
			//Have to cut off the trailing 'Z' from date as D library doesn't like it
			library.DateAdded = DateTime.fromISOExtString(chomp(json["date_added"].str, "Z"));
		}
		
		if ("description" in json)
		{
			debug output("adding description ", json["description"].str);
			library.Description = json["description"].str;
		}
		
		if ("download_urls" in json && json["download_urls"].type !is JSON_TYPE.NULL)
		{
			debug output("adding download urls");

			JSONValue[string] urls = json["download_urls"].object;
			DownloadUrl downloadUrl = new DownloadUrl;

			if ("mp4" in urls)
			{
				debug output("adding mp4 ", urls["mp4"].str);
				downloadUrl.MP4 = urls["mp4"].str;
			}
			
			if ("png" in urls)
			{
				debug output("adding png ", urls["png"].str);
				downloadUrl.PNG = urls["png"].str;
			}
			
			if ("m3u8" in urls)
			{
				debug output("adding m3u8 ", urls["m3u8"].str);
				downloadUrl.M3U8 = urls["m3u8"].str;
			}

			debug output("storing new download url");
			library.DownloadUrls = downloadUrl;
		}
		
		if ("duration" in json)
		{
			debug output("adding duration ", json["duration"].integer);
			library.Duration = json["duration"].integer;
		}
		
		//Every entry has a title, no need to null check
		debug output("adding title ", json["title"].str);
		library.Title = json["title"].str;
		
		//If the node still has children recurse again
		if ("children" in json)
		{
			debug output("adding children");
			//Get the json child values
			JSONValue[] jsonChildren = json["children"].array;
			
			//Set the array of Library objects length to the same length as the jsonChildren
			debug output("Setting child length to ", jsonChildren.length);
			library.ChildrenLength = jsonChildren.length;
			
			//Recurse and build a new library for each child
			foreach(childCounter; 0 .. jsonChildren.length)
			{
				debug output("child recursing");
				library.Children[childCounter] = ConvertJsonToLibrary(jsonChildren[childCounter].object);
			}
		}

		debug output("Library returning");
		return library;
	}

	private static void SaveLibrary(Library completeLibrary)
	{
		//No need to check for save directory existance here as it was checked and created if needed in SaveETag()
		
		//Use msgpack to serialise _completeLibrary
		//Storing the raw json string takes 13.3mb and takes ~2s to load
		//The msgpack file takes 2.2mb and a fraction of a second to load
		string libraryFileName = expandTilde(G_LibraryFilePath);
		ubyte[] serialised = pack(completeLibrary);

		write(libraryFileName, serialised);
	}
}