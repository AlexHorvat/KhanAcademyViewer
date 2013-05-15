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

alias std.file fileUtils;
//import std.stdio;
import std.path;
import std.net.curl;
import std.json;
import std.datetime;
import std.string;

import msgpack;

import KhanAcademyViewer.DataStructures.Library;
import KhanAcademyViewer.DataStructures.DownloadUrl;

protected final class LibraryWorker
{
	private static immutable string _topicTreeUrl = "http://www.khanacademy.org/api/v1/topictree";
	private static immutable string _eTagFilePath = "~/.config/KhanAcademyViewer/ETag";
	private static immutable string _libraryFilePath = "~/.config/KhanAcademyViewer/Library";
	private static Library _completeLibrary;
	private static string _etag;
	private static string _jsonValues;

	public static Library LoadLibrary()
	{
		if (NeedToRefreshLibrary())
		{
			RefreshLibrary();
		}
		else
		{
			LoadLibraryFromDisk();
		}

		return _completeLibrary;
	}

	private static bool NeedToRefreshLibrary()
	{
		if (LoadETagFromDisk())
		{
			HTTP connection = HTTP(_topicTreeUrl);

			connection.method = HTTP.Method.head;
			connection.perform();

			string newETag = connection.responseHeaders["etag"];

			return newETag != _etag;
		}
		else
		{
			return true;
		}
	}

	private static bool LoadETagFromDisk()
	{
		string eTagFileName = expandTilde(_eTagFilePath);

		if (fileUtils.exists(eTagFileName))
		{
			_etag = fileUtils.readText(eTagFileName);
			return true;
		}
		else
		{
			return false;
		}
	}

	private static void RefreshLibrary()
	{
		//Download and process the library
		DownloadLibrary();
		SaveETag();
		ConvertJsonToLibrary();
		SaveLibrary();
	}

	private static void DownloadLibrary()
	{
		//TODO
		//Figure out how to implement HTTP.onProgress to show download progress

		//Download whole library in json format
		HTTP connection = HTTP();

		_jsonValues = cast(string)get(_topicTreeUrl, connection);
		_etag = connection.responseHeaders["etag"];
		connection.destroy();
	}
	
	private static void SaveETag()
	{	
		string eTagFileName = expandTilde(_eTagFilePath);
		string filePath = dirName(eTagFileName);

		//Create directory if it doesn't exist
		if (!fileUtils.exists(filePath))
		{
			fileUtils.mkdirRecurse(filePath);
		}

		//Write the file - overwrite if already exists
		fileUtils.write(eTagFileName, _etag);
	}

	private static void ConvertJsonToLibrary()
	{
		_completeLibrary = BuildLibary(parseJSON(_jsonValues).object);
	}

	private static Library BuildLibary(JSONValue[string] json)
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
				library.author_names.length = jsonAuthorNames.length;
				
				foreach(authorCounter; 0 .. jsonAuthorNames.length)
				{
					library.author_names[authorCounter] = jsonAuthorNames[authorCounter].str;
				}
			}
		}

		if ("date_added" in json)
		{
			//Have to cut off the trailing 'Z' from date as D library doesn't like it
			library.date_added = DateTime.fromISOExtString(chomp(json["date_added"].str, "Z"));
		}

		if ("description" in json)
		{
			library.description = json["description"].str;
		}

		if ("download_urls" in json)
		{
			JSONValue[string] urls = json["download_urls"].object;

			DownloadUrl downloadUrl = new DownloadUrl;

			if ("mp4" in urls)
			{
				downloadUrl.mp4 = urls["mp4"].str;
			}

			if ("png" in urls)
			{
				downloadUrl.png = urls["png"].str;
			}

			if ("m3u8" in urls)
			{
				downloadUrl.m3u8 = urls["m3u8"].str;
			}

			library.download_urls = downloadUrl;
		}

		if ("duration" in json)
		{
			library.duration = json["duration"].integer;
		}

		//Every entry has a title, no need to null check
		library.title = json["title"].str;

		//If the node still has children recurse again
		if ("children" in json)
		{
			//Get the json child values
			JSONValue[] jsonChildren = json["children"].array;

			//Set the array of Library objects length to the same length as the jsonChildren
			library.children.length = jsonChildren.length;

			//Recurse and build a new library for each child
			foreach(childCounter; 0 .. jsonChildren.length)
			{
				library.children[childCounter] = BuildLibary(jsonChildren[childCounter].object);
			}
		}

		return library;
	}

	private static void SaveLibrary()
	{
		//Note:
		//No need to check for save directory existance here as it was checked and created if needed in SaveETag()
		//writeln("Saving Library");

		//Use msgpack to serialise _completeLibrary
		//Storing the raw json string takes 13.3mb and takes ~2s to load
		//The msgpack file takes 2.2mb and a fraction of a second to load
		string libraryFileName = expandTilde(_libraryFilePath);
		ubyte[] serialised = pack(_completeLibrary);

		fileUtils.write(libraryFileName, serialised);
	}

	private static void LoadLibraryFromDisk()
	{
		string libraryFileName = expandTilde(_libraryFilePath);

		if (fileUtils.exists(libraryFileName))
		{
			ubyte[] serialised = cast(ubyte[])fileUtils.read(libraryFileName);

			unpack(serialised, _completeLibrary);
		}
		else
		{
			RefreshLibrary();
		}
	}
}