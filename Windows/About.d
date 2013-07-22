/**
 * 
 * About.d
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
module KhanAcademyViewer.Windows.About;

debug alias std.stdio.writeln output;

import gtk.AboutDialog;
import gtk.Dialog;

public final class About
{
	private AboutDialog _wdwAbout;

	public this(void delegate() disposeFunction)
	{
		debug output(__FUNCTION__);
		Dispose = disposeFunction;

		_wdwAbout = new AboutDialog();
		_wdwAbout.setTitle("About Khan Academy Viewer");
		_wdwAbout.setProgramName("Khan Academy Viewer");
		_wdwAbout.setVersion("0.3");
		_wdwAbout.setCopyright("Copyright © 2013 Alex Horvat\nUses MessagePack by Masahiro Nakagawa");
		_wdwAbout.setComments("The Khan Academy Viewer for the Gnome desktop");
		_wdwAbout.setLicenseType(GtkLicense.GPL_3_0);
		_wdwAbout.setAuthors(["Alex Horvat"]);
		_wdwAbout.addOnResponse(&wdwAbout_Response);
		_wdwAbout.showAll();
	}

	public void Show()
	{
		_wdwAbout.present();
	}

	private void delegate() Dispose;

	private void wdwAbout_Response(int response, Dialog sender)
	{
		debug output(__FUNCTION__);
		if (response == GtkResponseType.CANCEL)
		{
			_wdwAbout.destroy();
			Dispose();
		}
	}
}