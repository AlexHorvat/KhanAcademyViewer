/**
 * 
 * Loading.d
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

module KhanAcademyViewer.Windows.Loading;

import std.conv;

import gtk.Builder;
import gtk.Window;
import gtk.Label;

protected final class Loading
{
	private const string _gladeFile = "./Windows/Loading.glade";
	
	private Window _wdwLoading;
	private Label _lblStatus;
	private Label _lblDataDownloaded;

	this()
	{
		SetupWindow();
	}

	~this()
	{
		_wdwLoading.hide();
		_wdwLoading.destroy();
	}

	public void UpdateStatus(string newStatus)
	{
		_lblStatus.setText(newStatus);
	}

	public void UpdateAmountDownloaded(long amountDownloaded)
	{
		//amountDownloaded is in bytes
		string downloaded = to!string(amountDownloaded / 1024);

		downloaded ~= " KB";
		_lblDataDownloaded.setText(downloaded);
	}
	
	private void SetupWindow()
	{
		Builder windowBuilder = new Builder();
				
		windowBuilder.addFromFile(_gladeFile);

		_wdwLoading = cast(Window)windowBuilder.getObject("wdwLoading");

		_lblStatus = cast(Label)windowBuilder.getObject("lblStatus");

		_lblDataDownloaded = cast(Label)windowBuilder.getObject("lblDataDownloaded");

		_wdwLoading.showAll();
	}
}