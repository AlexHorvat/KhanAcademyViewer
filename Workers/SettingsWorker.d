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

	/**
	 * Check if there are settings saved to local storage, if so return those, otherwise return a new Settings object.
	 * 
	 * Returns: a Settings object.
	 */
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

	/**
	 * Serialise and save to local storage the supplied Settings object.
	 * 
	 * Params:
	 * settings = the Settings object to save.
	 */
	static void saveSettings(Settings settings)
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		ubyte[] serialised = pack(settings);
		
		write(settingsFileName, serialised);
	}

private:

	/**
	 * Deserialise and return the settings from local storage.
	 * 
	 * Returns: the retrieved Settings object.
	 */
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

	/**
	 * Check if there are settings saved to local storage.
	 * 
	 * Returns: a bool of whether or not the settings exist on local storage.
	 */
	static bool settingsFileExists()
	{
		debug output(__FUNCTION__);
		string settingsFileName = expandTilde(SETTINGS_FILE_PATH);
		
		return exists(settingsFileName);
	}
}