//
//  KhanAcademyViewer.d
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

module kav.Main;

alias std.stdio.writeln output;

import gtk.Main;
import gtk.Version;

import gstreamer.gstreamer:GStreamer;

import kav.Windows.Viewer;

public void main(string args[]) {
	debug output(__FUNCTION__);
	//Test for gtk and gstreamer

	//TODO Check for mp4 support and maybe playbin support
	//Is this possible using gstreamer, or should check for .so file directly?

	try
	{
		uint majorVersion = Version.getMajorVersion;
		uint minorVersion = Version.getMinorVersion;
		uint microVersion = Version.getMicroVersion;

		debug output("GTK version ", majorVersion, ".", minorVersion, ".", microVersion);
	}
	catch
	{
		output("Cannot load GTK, ending...");
		return;
	}

	try
	{
		string gstreamerVersion = GStreamer.versionString;

		debug output("GStreamer version ", gstreamerVersion);
	}
	catch
	{
		output("Cannot load GStreamer, ending...");
		return;
	}

	//Has gtk and gstreamer, should be able to run
	Main.init(args);

	new Viewer();

	Main.run();

	//Not normally needed according to documentation, but clean up just in case something goes wrong
	GStreamer.deinit();
}