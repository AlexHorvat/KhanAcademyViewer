/**
 * 
 * Config.d
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

module KhanAcademyViewer.Include.Config;

import core.time;

protected immutable string G_TopicTreeUrl = "http://www.khanacademy.org/api/v1/topictree";
protected immutable string G_ETagFilePath = "~/.config/KhanAcademyViewer/ETag";
protected immutable string G_LibraryFilePath = "~/.config/KhanAcademyViewer/Library";
protected immutable string G_SettingsFilePath = "~/.config/KhanAcademyViewer/Settings";
protected immutable string G_DownloadFilePath = "~/.config/KhanAcademyViewer";
protected immutable Duration G_ConnectionTimeOut = dur!"seconds"(15);