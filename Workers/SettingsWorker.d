/**
 * 
 * SettingsWorker.d
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
module KhanAcademyViewer.Workers.SettingsWorker;

debug alias std.stdio.writeln output;

import std.file;
import std.path;

import msgpack;

import KhanAcademyViewer.DataStructures.Settings;
import KhanAcademyViewer.Include.Config;
import KhanAcademyViewer.Include.Enums;

public static class SettingsWorker
{
	public static Settings LoadSettings()
	{
		debug output(__FUNCTION__);
		if (SettingsFileExists())
		{
			return GetSavedSettings();
		}
		else
		{
			return new Settings;
		}
	}

	public static void SaveSettings(Settings settings)
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		ubyte[] serialised = pack(settings);
		
		write(settingsFileName, serialised);
	}

	private static bool SettingsFileExists()
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		
		return exists(settingsFileName);
	}

	private static Settings GetSavedSettings()
	{
		debug output(__FUNCTION__);
		Settings settings;
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		ubyte[] serialised = cast(ubyte[])read(settingsFileName);
		
		//Convert the serialised library back into a Library object
		unpack(serialised, settings);

		return settings;
	}
}