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

import gtk.Builder;
import gtk.AboutDialog;
import gtk.Dialog;

protected final class About
{
	private const string _gladeFile = "./Windows/About.glade";

	private AboutDialog _wdwAbout;

	this()
	{
		debug output(__FUNCTION__);
		SetupWindow();
	}

	private void SetupWindow()
	{
		debug output(__FUNCTION__);
		Builder windowBuilder = new Builder();
		
		windowBuilder.addFromFile(_gladeFile);

		_wdwAbout = cast(AboutDialog)windowBuilder.getObject("wdwAbout");
		_wdwAbout.addOnResponse(&wdwAbout_Response);

		_wdwAbout.showAll();
	}

	private void wdwAbout_Response(int response, Dialog sender)
	{
		debug output(__FUNCTION__);
		if (response == GtkResponseType.CANCEL)
		{
			sender.hide();
			sender.destroy();
		}
	}
}