/**
 * Config.d
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

module kav.Include.Config;

import core.time;

protected:

	immutable Duration	CONNECTION_TIME_OUT = dur!"seconds"(15);
	immutable string	DOWNLOAD_FILE_PATH = "~/.local/share/KhanAcademyViewer";
	immutable string	ETAG_FILE_PATH = "~/.config/KhanAcademyViewer/ETag";
	immutable string	LIBRARY_FILE_PATH = "~/.config/KhanAcademyViewer/Library";
	immutable string	SETTINGS_FILE_PATH = "~/.config/KhanAcademyViewer/Settings";
	immutable string	TOPIC_TREE_URL = "http://www.khanacademy.org/api/v1/topictree";