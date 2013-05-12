module KhanAcademyViewer.Main;

import std.stdio;

import gtk.Main;
import gtk.Version;

import gstreamer.gstreamer;

import KhanAcademyViewer.Windows.Viewer;

void main(string args[]) {
	//Test for gtk and gstreamer
	try
	{
		uint majorVersion = Version.getMajorVersion;
		uint minorVersion = Version.getMinorVersion;
		uint microVersion = Version.getMicroVersion;

		writefln("GTK version %s.%s.%s", majorVersion, minorVersion, microVersion);
	}
	catch
	{
		writeln("Cannot load GTK, ending...");
		return;
	}

	try
	{
		writefln("GStreamer version %s", GStreamer.versionString);
	}
	catch
	{
		writeln("Cannot load GStreamer, ending...");
		return;
	}

	//Has gtk and gstreamer, should be able to run
	Main.init(args[]);
	new	Viewer();
	Main.run();

	//Not normally needed according to documentation, but clean up just in case something goes wrong
	GStreamer.deinit();
}