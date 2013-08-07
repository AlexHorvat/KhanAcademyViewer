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
module kav.Workers.SettingsWorker;

debug alias std.stdio.writeln output;

import kav.DataStructures.Settings;
import kav.Include.Config;
import kav.Include.Enums;

import msgpack;

import std.file;
import std.path;

public static class SettingsWorker
{

public:

	static Settings loadSettings()
	{
		debug output(__FUNCTION__);
		if (settingsFileExists())
		{
			return getSavedSettings();
		}
		else
		{
			return new Settings;
		}
	}

	static void saveSettings(Settings settings)
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		ubyte[] serialised = pack(settings);
		
		write(settingsFileName, serialised);
	}

private:

	static Settings getSavedSettings()
	{
		debug output(__FUNCTION__);
		Settings settings;
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		ubyte[] serialised = cast(ubyte[])read(settingsFileName);
		
		//Convert the serialised library back into a Library object
		unpack(serialised, settings);
		
		return settings;
	}

	static bool settingsFileExists()
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		
		return exists(settingsFileName);
	}
}