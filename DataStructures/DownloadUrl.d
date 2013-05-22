//
//  DownloadUrl.d
//
//  Author:
//       Alex Horvat <alex.horvat9@gmail.com>
//
//  Copyright (c) 2013 Alex Horvat
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

module KhanAcademyViewer.DataStructures.DownloadUrl;

public final class DownloadUrl
{
	private string _mp4;
	public @property {
		string MP4() { return _mp4; }
		void MP4(string new_mp4) { _mp4 = new_mp4; }
	}

	//TODO am I going to use the png for anything?
	private string _png;
	public @property {
		string PNG() { return _png; }
		void PNG(string new_png) { _png = new_png; }
	}

	private string _m3u8;
	public @property {
		string M3U8() { return _m3u8; }
		void M3U8(string new_m3u8) { _m3u8 = new_m3u8; }
	}
}