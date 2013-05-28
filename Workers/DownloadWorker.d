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

//TODO testing only
import std.datetime;

import std.json;
import std.net.curl;
import std.path;
import std.datetime;
import std.string;
import std.file;
import std.concurrency;

import msgpack;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Include.Config;

alias std.stdio.writeln output;

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

		long startTime = Clock.currStdTime;
		completeLibrary = ConvertJsonToLibrary(parseJSON(jsonValues).object);
		long endTime = Clock.currStdTime;
		output("Time taken to create complete library: ", (endTime - startTime) / 1000);

		SaveLibrary(completeLibrary);

		//Send the kill signal back to the parent of this thread
		//Can't just send bool as this seems to get interpreted as a ulong
		//so sending back parentThread just to have something to send
		parentThread.send(parentThread);
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
		//If the node still has children load the current title and recurse again
		if ("children" in json && json["children"].type !is JSON_TYPE.NULL)
		{
			debug output("Found a node library");
			Library library = new Library();

			//Every entry has a title, no need to null check
			debug output("adding title ", json["title"].str);
			library.Title = json["title"].str;

			//Get all children of this library
			foreach(JSONValue jsonChild; json["children"].array)
			{
				Library returnedLibrary = ConvertJsonToLibrary(jsonChild.object);

				//returnedLibrary will be null if it is an exercise
				//in that case don't add it to the main library
				if (returnedLibrary !is null)
				{
					library.AddChildLibrary(returnedLibrary);
				}
			}

			//If all children were exercises, then don't return the parent
			if (library.Children is null)
			{
				return null;
			}
			else
			{
				return library;
			}
		}
		//If no children then check if there's download links, if there are then this is a video
		else if ("download_urls" in json && json["download_urls"].type !is JSON_TYPE.NULL)
		{
			debug output("Found a video");

			Library library = new Library();
			
			//Every entry has a title, no need to null check
			debug output("adding title ", json["title"].str);
			library.Title = json["title"].str;
			
			//Check if there is an author_names object at all
			if ("author_names" in json)
			{
				JSONValue[] jsonAuthorNames = json["author_names"].array;
				
				//Now check if there are any entries in the author_names
				if (jsonAuthorNames.length != 0)
				{
					//There are author_names, loop thru and add them to library
					library.AuthorNamesLength = jsonAuthorNames.length;
					
					foreach(authorCounter; 0 .. jsonAuthorNames.length)
					{
						library.AuthorNames[authorCounter] = jsonAuthorNames[authorCounter].str;
					}
				}
			}
			
			if ("date_added" in json)
			{
				//Have to cut off the trailing 'Z' from date as D library doesn't like it
				library.DateAdded = DateTime.fromISOExtString(chomp(json["date_added"].str, "Z"));
			}
			
			if ("description" in json)
			{
				library.Description = json["description"].str;
			}

			//Get the download urls
			JSONValue[string] urls = json["download_urls"].object;

			if ("mp4" in urls)
			{
				library.MP4 = urls["mp4"].str;
			}

			return library;
		}
		//No children, but no video's as well, must be an exercice - don't load it
		else
		{
			debug output("Found an exercise");
			return null;
		}
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

	public static bool VideoIsDownloaded(string localFileName)
	{
		debug output("Checking for file ", localFileName);

		return exists(localFileName);
	}

	public static void DownloadVideo(string fileName, string localFileName, Tid parentThread)
	{
		debug output("Downloading file ", fileName, " to ", localFileName);
		//Download whole library in json format
		HTTP connection = HTTP();

		connection.onProgress = delegate int(ulong dltotal, ulong dlnow, ulong ultotal, ulong ulnow)
		{
			//Send a progress update to the parent of this thread
			parentThread.send(dlnow);
			return 0;
		};

		//TODO this isn't saving the video corretly - it's corrupted, might need to save byte[] instead of char[]
		char[] video = get(fileName, connection);
		connection.destroy();
		debug output("video downloaded, saving");
		write(localFileName, video);

		debug output("video saved");
		//Send the kill signal back to the parent of this thread
		//Can't just send bool as this seems to get interpreted as a ulong
		//so sending back parentThread just to have something to send
		parentThread.send(parentThread);
	}

	public static void DeleteVideo(string localFileName)
	{
		debug output("Deleting file ", localFileName);

		//Double check file exists just in case it's been deleted manually
		if (exists(localFileName))
		{
			remove(localFileName);
		}
	}
}