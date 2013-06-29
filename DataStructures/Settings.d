/**
 * 
 * Settings.d
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
module KhanAcademyViewer.DataStructures.Settings;

import KhanAcademyViewer.Include.Enums;

public final class Settings
{
	private ViewMode _viewMode = ViewMode.Flow;
	public @property {
		ViewMode ViewModeSetting() { return _viewMode; }
		void ViewModeSetting(ViewMode new_ViewMode) { _viewMode = new_ViewMode; }
	}

	private bool _isOffline = false;
	public @property {
		bool IsOffline() { return _isOffline; }
		void IsOffline(bool new_IsOffline) { _isOffline = new_IsOffline; }
	}

	private bool _keepPosition = false;
	public @property {
		bool KeepPosition() { return _keepPosition; }
		void KeepPosition(bool new_KeepPosition) { _keepPosition = new_KeepPosition; }
	}

	private string _lastSelectedCategory;
	public @property {
		string LastSelectedCategory() { return _lastSelectedCategory; }
		void LastSelectedCategory(string new_LastSelectedCategory) { _lastSelectedCategory = new_LastSelectedCategory; }
	}

	private bool _continuousPlay = false;
	public @property {
		bool ContinuousPlay() { return _continuousPlay; }
		void ContinuousPlay(bool new_ContinuousPlay) { _continuousPlay = new_ContinuousPlay; }
	}
}