/*
 * KhanAcademyViewer.d
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

module kav.Main;

debug alias std.stdio.writeln output;

import gtk.Main;
import gtk.Version;

import gstreamer.gstreamer:GStreamer;

import kav.Windows.Viewer;

/*
 * Start the program running.
 * Check that GTK and GStreamer are present, the program ends if they are not.
 * 
 * Params:
 * args = User supplied command line args, not used for anything yet, but expected by GTK.
 */
public void main(string args[]) {
	debug output(__FUNCTION__);
	uint majorVersion;
	uint minorVersion;
	uint microVersion;
	uint nanoVersion;

	//Test for gtk and gstreamer
	try
	{
		majorVersion = Version.getMajorVersion;
		minorVersion = Version.getMinorVersion;
		microVersion = Version.getMicroVersion;

		debug output("GTK version ", majorVersion, ".", minorVersion, ".", microVersion);
	}
	catch
	{
		 throw new Exception("Cannot load GTK, ending...");
	}

	if (!(majorVersion >= 3 && minorVersion >= 6))
	{
		throw new Exception("Gnome version too old, you need 3.6 or higher.");
	}

	try
	{
		GStreamer.versio(majorVersion, minorVersion, microVersion, nanoVersion);

		debug output("GStreamer version ", majorVersion, ".", minorVersion, ".", microVersion, ".", nanoVersion);
	}
	catch
	{
		throw new Exception("Cannot load GStreamer, ending...");
	}

	if (majorVersion < 1)
	{
		throw new Exception("GStreamer version to old, you need 1.0 or higher.");
	}

	//Has gtk and gstreamer, should be able to run
	Main.init(args);

	new Viewer();

	Main.run();

	//Not normally needed according to documentation, but clean up just in case something goes wrong
	GStreamer.deinit();
}