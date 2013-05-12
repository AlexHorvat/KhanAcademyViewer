module KhanAcademyViewer.DataStructures.Library;

import KhanAcademyViewer.DataStructures.DownloadUrl;

import std.datetime;

public final class Library
{
	string title;
	Library[] children;
	string description;
	long duration;
	int views;
	string[] author_names;
	DateTime date_added;
	DownloadUrl download_urls;
}