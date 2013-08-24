/*
 * About.d
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

module kav.Windows.About;

debug alias std.stdio.writeln output;

import gtk.AboutDialog;
import gtk.Dialog;

public final class About
{

public:

	this()
	{
		debug output(__FUNCTION__);
		AboutDialog wdwAbout = new AboutDialog();

		wdwAbout.setTitle("About Khan Academy Viewer");
		wdwAbout.setProgramName("Khan Academy Viewer");
		wdwAbout.setVersion("0.3");
		wdwAbout.setCopyright("Copyright © 2013 Alex Horvat\nUses MessagePack by Masahiro Nakagawa");
		wdwAbout.setComments("The Khan Academy Viewer for the Gnome desktop");
		wdwAbout.setLicenseType(GtkLicense.GPL_3_0);
		wdwAbout.setAuthors(["Alex Horvat"]);
		wdwAbout.addOnResponse(&wdwAbout_Response);
		wdwAbout.setDestroyWithParent(true);
		wdwAbout.setModal(true);
		wdwAbout.showAll();
	}

private:

	/**
	 * Just close the dialog.
	 */
	void wdwAbout_Response(int response, Dialog dialog)
	{
		debug output(__FUNCTION__);
		if (response == GtkResponseType.CANCEL)
		{
			dialog.destroy();
		}
	}
}