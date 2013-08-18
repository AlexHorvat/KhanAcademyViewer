/**
 * DownloadWorker.d
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

module kav.Workers.DownloadWorker;

debug alias std.stdio.writeln output;

import kav.DataStructures.Library;
import kav.Include.Config;
import kav.Include.Functions;

import msgpack;

import std.array;
import std.concurrency;
import std.datetime;
import std.file;
import std.json;
import std.net.curl;
import std.string;

public static class DownloadWorker
{

public:

	/**
	 * Delete a video from local storage.
	 * 
	 * Params:
	 * url = the remote file name to delete (will be converted to local file name in this method)
	 */
	static void deleteVideo(string url)
	{
		debug output(__FUNCTION__);
		string localFileName = Functions.getLocalFileName(url);
		
		//Double check file exists just in case it's been deleted manually
		if (exists(localFileName))
		{
			remove(localFileName);
		}
	}

	/**
	 * Download complete library from Khan Academy website, convert to a Library object and save to disk.
	 */
	static void downloadLibraryAsync()
	{
		debug output(__FUNCTION__);
		scope(failure)ownerTid.send(false); //Handle error in this thread

		string eTag, jsonValues;
		
		downloadJson(eTag, jsonValues);
		saveETag(eTag);

		//Convert library from JSON to Library object(s) and save to disk
		Library completeLibrary = convertJsonToLibrary(parseJSON(jsonValues).object);
		saveLibrary(completeLibrary);

		//Send the kill signal back to the parent of this thread
		ownerTid.send(true);
	}

	/**
	 * Download a specified video to local storage.
	 * 
	 * Params:
	 * url = the video to download.
	 */
	static void downloadVideoAsync(string url)
	{
		debug output(__FUNCTION__);
		scope(success)ownerTid.send(true, url);
		scope(failure)ownerTid.send(false, url);
		scope(exit)connection.destroy();

		bool keepGoing = true;
		string localFileName = Functions.getLocalFileName(url);
		int progressCounter;
		HTTP connection = HTTP();
		
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

	/**
	 * Check if computer currently has an internet connection by trying to retrieve the HEAD from the Khan Academy library url.
	 */
	static void hasInternetConnectionAsync()
	{
		debug output(__FUNCTION__);
		scope(success)ownerTid.send(true);
		scope(failure)ownerTid.send(false);
		scope(exit)connection.destroy();

		HTTP connection = HTTP(TOPIC_TREE_URL);

		connection.method = HTTP.Method.head;
		connection.connectTimeout(CONNECTION_TIME_OUT);
		connection.perform();
	}

	/**
	 * Compare locally stored etag to Khan Academy's current etag, if they match no need to download the library again. 
	 */
	static void needToDownloadLibraryAsync()
	{
		debug output(__FUNCTION__);
		scope(failure)ownerTid.send(true); //Force library download on error

		string eTag;
		
		if (loadETagFromDisk(eTag) && libraryExists())
		{
			HTTP connection = HTTP(TOPIC_TREE_URL);
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

private:

	/**
	 * Take the downloaded library in JSON format and covert it to a nested Library object
	 * 
	 * Params:
	 * json = the downloaded library in json format.
	 */
	static Library convertJsonToLibrary(JSONValue[string] json)
	{
		debug output(__FUNCTION__);
		//If the node still has children load the current title and recurse again
		if ("children" in json && json["children"].type !is JSON_TYPE.NULL)
		{
			Library newLibrary = new Library();
			Appender!(Library[], Library) appendLibrary = appender!(Library[], Library);
			
			//Every entry has a title, no need to null check
			newLibrary.title = json["title"].str;
			
			//Get all children of this library
			foreach(JSONValue jsonChild; json["children"].array)
			{
				Library childLibrary = convertJsonToLibrary(jsonChild.object);
				
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
				newLibrary.children = appendLibrary.data;
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
			Library newLibrary = new Library();
			
			//Every entry has a title, no need to null check
			newLibrary.title = json["title"].str;
			
			//Check if there is an author_names object at all
			if ("author_names" in json)
			{
				JSONValue[] jsonAuthorNames = json["author_names"].array;
				
				//Now check if there are any entries in the author_names
				if (jsonAuthorNames.length != 0)
				{
					//There are author_names, loop thru and add them to library
					newLibrary.authorNames = new string[jsonAuthorNames.length];
					
					foreach(size_t authorCounter; 0 .. jsonAuthorNames.length)
					{
						newLibrary.authorNames[authorCounter] = jsonAuthorNames[authorCounter].str;
					}
				}
			}
			
			if ("date_added" in json)
			{
				//Have to cut off the trailing 'Z' from date as D library doesn't like it
				newLibrary.dateAdded = DateTime.fromISOExtString(chomp(json["date_added"].str, "Z"));
			}
			
			if ("description" in json)
			{
				newLibrary.description = json["description"].str;
			}
			
			//Get the download urls
			JSONValue[string] urls = json["download_urls"].object;
			
			if ("mp4" in urls)
			{
				newLibrary.mp4 = urls["mp4"].str;
			}
			
			return newLibrary;
		}
		//No children, but no video's as well, must be an exercice - don't load it
		else
		{
			return null;
		}
	}

	/**
	 * Download whole library from Khan Academy in JSON format.
	 * 
	 * Params:
	 * eTag = this is set to the Khan Academies version of the library's etag.
	 * jsonValues = the library is loaded into this variable.
	 */
	static void downloadJson(out string eTag, out string jsonValues)
	{
		debug output(__FUNCTION__);
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
		
		jsonValues = cast(string)get!(HTTP, char)(TOPIC_TREE_URL, connection);
		eTag = connection.responseHeaders["etag"];
	}

	/**
	 * Check if the library exists on local storage.
	 * 
	 * Returns: Bool of whether or not the library exists.
	 */
	static bool libraryExists()
	{
		debug output(__FUNCTION__);
		string libraryFileName = expandTilde(LIBRARY_FILE_PATH);
		
		return exists(libraryFileName);
	}

	/**
	 * Check if the etag exists on local storage, and if it does, load it.
	 * 
	 * Params:
	 * eTag = this is the variable to be set to the etag value.
	 * 
	 * Returns: Bool of whether or not the etag exists on local storage.
	 */
	static bool loadETagFromDisk(out string eTag)
	{
		debug output(__FUNCTION__);
		string eTagFileName = expandTilde(ETAG_FILE_PATH);
		
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

	/**
	 * Save the etag value to local storage.
	 * 
	 * Params:
	 * eTag = the new etag value to save.
	 */
	static void saveETag(string eTag)
	{	
		debug output(__FUNCTION__);
		string eTagFileName = expandTilde(ETAG_FILE_PATH);
				
		//Write the file - overwrite if already exists
		write(eTagFileName, eTag);
	}

	/**
	 * Run msgpack over the library to serialise it, then save it to local storage.
	 * 
	 * Params:
	 * completeLibrary = the library to save.
	 */
	static void saveLibrary(Library completeLibrary)
	{
		debug output(__FUNCTION__);
		//No need to check for save directory existance here as it was checked and created if needed in SaveETag()
		
		//Use msgpack to serialise _completeLibrary
		//Storing the raw json string takes 13.3mb and takes ~2s to load
		//The msgpack file takes 2.2mb and a fraction of a second to load
		string libraryFileName = expandTilde(LIBRARY_FILE_PATH);
		ubyte[] serialised = pack(completeLibrary);
		
		write(libraryFileName, serialised);
	}
}