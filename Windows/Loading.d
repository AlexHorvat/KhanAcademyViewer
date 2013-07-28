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

debug alias std.stdio.writeln output;

import std.string:format;

import gtk.Window;
import gtk.Fixed;
import gtk.Label;

import KhanAcademyViewer.Include.Functions;

public final class Loading
{
	private Window _wdwLoading;
	private Label _lblStatus;
	private Label _lblDataDownloaded;

	public this()
	{
		debug output(__FUNCTION__);
		_wdwLoading = new Window("Loading...");
		_wdwLoading.setModal(true);
		_wdwLoading.setSizeRequest(280, 130);
		_wdwLoading.setPosition(GtkWindowPosition.POS_CENTER_ON_PARENT);
		_wdwLoading.setDestroyWithParent(true);
		_wdwLoading.setTypeHint(GdkWindowTypeHint.DIALOG);
		_wdwLoading.setSkipPagerHint(true);
		_wdwLoading.setSkipTaskbarHint(true);

		Fixed fixLoading = new Fixed();
		_wdwLoading.add(fixLoading);
		
		_lblStatus = new Label("Checking for library updates", false);
		_lblStatus.setSizeRequest(-1, 30);
		_lblStatus.setHalign(GtkAlign.START);
		_lblStatus.setHexpand(true);
		fixLoading.put(_lblStatus, 25, 30);
		
		_lblDataDownloaded = new Label("0 KB", false);
		_lblDataDownloaded.setSizeRequest(-1, 30);
		_lblDataDownloaded.setHalign(GtkAlign.START);
		_lblDataDownloaded.setHexpand(true);
		fixLoading.put(_lblDataDownloaded, 25, 75);
		
		_wdwLoading.showAll();

		_lblDataDownloaded.hide();
	}

	public ~this()
	{
		debug output(__FUNCTION__);
		_wdwLoading.destroy();
	}

	public void UpdateStatus(string newStatus)
	{
		debug output(__FUNCTION__);
		_lblStatus.setText(newStatus);
		RefreshUI();
	}
	
	public void SetDataDownloadedVisible(bool isVisible)
	{
		_lblDataDownloaded.setVisible(isVisible);
		RefreshUI();
	}

	public void UpdateAmountDownloaded(long amountDownloaded)
	{
		debug output(__FUNCTION__);
		_lblDataDownloaded.setText(format("%s KB", amountDownloaded / 1024));
	}
}