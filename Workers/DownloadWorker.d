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

debug alias std.stdio.writeln output;

import std.json;
import std.net.curl;
import std.path;
import std.datetime;
import std.string;
import std.file;
import std.concurrency;
import std.array;

import msgpack;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.Include.Config;
import KhanAcademyViewer.Include.Functions;

public static class DownloadWorker
{
	public static void HasInternetConnection()
	{
		debug output(__FUNCTION__);
		HTTP connection = HTTP(G_TopicTreeUrl);
		scope(success)ownerTid.send(true);
		scope(failure)ownerTid.send(false);
		scope(exit)connection.destroy();

		connection.method = HTTP.Method.head;
		connection.connectTimeout(G_ConnectionTimeOut);
		connection.perform();
	}

	public static void NeedToDownloadLibrary()
	{
		debug output(__FUNCTION__);
		string eTag;
		scope(failure)ownerTid.send(true);
		
		if (LoadETagFromDisk(eTag) && LibraryExists())
		{
			HTTP connection = HTTP(G_TopicTreeUrl);
			scope(exit)connection.destroy();

			connection.method = HTTP.Method.head;
			connection.perform();
			
			string newETag = connection.responseHeaders["etag"];

			ownerTid.send(newETag != eTag);
		}
		else
		{
			ownerTid.send(true);
		}
	}

	public static void DownloadLibrary()
	{
		debug output(__FUNCTION__);
		string eTag, jsonValues;

		DownloadJson(eTag, jsonValues);
		SaveETag(eTag);

		Library completeLibrary = ConvertJsonToLibrary(parseJSON(jsonValues).object);
		SaveLibrary(completeLibrary);
		//Send the kill signal back to the parent of this thread
		//Can't just send bool as this seems to get interpreted as a ulong
		//so sending back parentThread just to have something to send
		ownerTid.send(true);
	}

	private static bool LoadETagFromDisk(out string eTag)
	{
		debug output(__FUNCTION__);
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
		debug output(__FUNCTION__);
		string libraryFileName = expandTilde(G_LibraryFilePath);

		return exists(libraryFileName);
	}

	private static void DownloadJson(out string eTag, out string jsonValues)
	{
		debug output(__FUNCTION__);
		//Download whole library in json format
		int progressCounter;
		HTTP connection = HTTP();
		scope(exit)connection.destroy();
		scope(failure)ownerTid.send(false);

		connection.onProgress = delegate int(ulong dltotal, ulong dlnow, ulong ultotal, ulong ulnow)
		{
			//Send a progress update to the parent of this thread
			//Only send every 50 progress updates so to not clog the message bus
			if (progressCounter < 50)
			{
				progressCounter++;
			}
			else
			{
				ownerTid.send(dlnow);
				progressCounter = 0;
			}

			return 0;
		};

		jsonValues = cast(string)get!(HTTP, char)(G_TopicTreeUrl, connection);
		eTag = connection.responseHeaders["etag"];
	}

	private static void SaveETag(string eTag)
	{	
		debug output(__FUNCTION__);
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
		debug output(__FUNCTION__);
		//If the node still has children load the current title and recurse again
		if ("children" in json && json["children"].type !is JSON_TYPE.NULL)
		{
			debug output("Found a node library");
			Library newLibrary = new Library();
			Appender!(Library[], Library) appendLibrary = appender!(Library[], Library);

			//Every entry has a title, no need to null check
			debug output("adding title ", json["title"].str);
			newLibrary.Title = json["title"].str;

			//Get all children of this library
			foreach(JSONValue jsonChild; json["children"].array)
			{
				Library childLibrary = ConvertJsonToLibrary(jsonChild.object);

				//returnedLibrary will be null if it is an exercise
				//in that case don't add it to the main library
				if (childLibrary)
				{
					appendLibrary.put(childLibrary);
				}
			}

			//If all children were exercises, then don't return the parent
			if (appendLibrary.data)
			{
				newLibrary.Children = appendLibrary.data;
				return newLibrary;
			}
			else
			{
				return null;
			}
		}
		//If no children then check if there's download links, if there are then this is a video
		else if ("download_urls" in json && json["download_urls"].type !is JSON_TYPE.NULL)
		{
			debug output("Found a video");
			Library newLibrary = new Library();
			
			//Every entry has a title, no need to null check
			debug output("adding title ", json["title"].str);
			newLibrary.Title = json["title"].str;
			
			//Check if there is an author_names object at all
			if ("author_names" in json)
			{
				JSONValue[] jsonAuthorNames = json["author_names"].array;
				
				//Now check if there are any entries in the author_names
				if (jsonAuthorNames.length != 0)
				{
					//There are author_names, loop thru and add them to library
					newLibrary.AuthorNamesLength = jsonAuthorNames.length;
					
					foreach(size_t authorCounter; 0 .. jsonAuthorNames.length)
					{
						newLibrary.AuthorNames[authorCounter] = jsonAuthorNames[authorCounter].str;
					}
				}
			}
			
			if ("date_added" in json)
			{
				//Have to cut off the trailing 'Z' from date as D library doesn't like it
				newLibrary.DateAdded = DateTime.fromISOExtString(chomp(json["date_added"].str, "Z"));
			}
			
			if ("description" in json)
			{
				newLibrary.Description = json["description"].str;
			}

			//Get the download urls
			JSONValue[string] urls = json["download_urls"].object;

			if ("mp4" in urls)
			{
				newLibrary.MP4 = urls["mp4"].str;
			}

			return newLibrary;
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
		debug output(__FUNCTION__);
		//No need to check for save directory existance here as it was checked and created if needed in SaveETag()
		
		//Use msgpack to serialise _completeLibrary
		//Storing the raw json string takes 13.3mb and takes ~2s to load
		//The msgpack file takes 2.2mb and a fraction of a second to load
		string libraryFileName = expandTilde(G_LibraryFilePath);
		ubyte[] serialised = pack(completeLibrary);

		write(libraryFileName, serialised);
	}

	public static void DownloadVideo(string url)
	{
		debug output(__FUNCTION__);
		bool keepGoing = true;
		string localFileName = GetLocalFileName(url);
		int progressCounter;
		HTTP connection = HTTP();
		scope(success)ownerTid.send(true, url);
		scope(failure)ownerTid.send(false, url);
		scope(exit)connection.destroy();

		connection.onProgress = delegate int(ulong dltotal, ulong dlnow, ulong ultotal, ulong ulnow)
		{
			//Send a progress update to the parent of this thread
			receiveTimeout(
				dur!"msecs"(1),
				(bool quit)
				{
					keepGoing = false;
				});

			if (keepGoing)
			{
				//Only send update every 50 progress updates to avoid clogging the message bus
				if (progressCounter < 50)
				{
					progressCounter++;
				}
				else
				{
					ownerTid.send(dlnow, url, thisTid);
					progressCounter = 0;
				}
				
				//Keep download going
				return 0;
			}
			else
			{
				//Kill the download
				return -1;
			}
		};

		//Start the download
		ubyte[] video = get!(HTTP, ubyte)(url, connection);

		//Only save the video if it got a chance to complete properly
		if (keepGoing)
		{
			write(localFileName, video);
		}
	}

	public static void DeleteVideo(string url)
	{
		debug output(__FUNCTION__);
		string localFileName = GetLocalFileName(url);
	
		//Double check file exists just in case it's been deleted manually
		if (exists(localFileName))
		{
			remove(localFileName);
		}
	}
}