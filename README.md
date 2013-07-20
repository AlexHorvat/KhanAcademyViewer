Khan Academy Viewer
=================

<h4>A Gnome 3 desktop player for the Khan Academy</h4>

<strong>Why choose this over using the website?</strong>
<ul>
	<li>Download videos and watch them offline</li>
	<li>Bookmark where you were up to</li>
	<li>Continuous play of an entire subject</li>
	<li>Easier to browse to a subject (in my opinion at least)</li>
</ul>
<br/>
<strong>How to build from source:</strong>
<br/>
<br/>
<i>Prerequisites</i>
<ul>
	<li>Recent version of Gnome 3 (tested on GTK 3.6+)</li>
	<li>GStreamer 1.0+, with it's basic plugins and codecs</li>
	<li>Your system needs to be able to play h264 videos</li>
	<li>Video driver compatible with xvimagesink</li>
	<li>Git</li>
	<li>Dmd 2 <a href="http://dlang.org/download.html" target="_blank">Download here</a></li>
	<li>libcurl.so (in Fedora this is in the libcurl-devel package)</li>
	<li>This means nothing to you? If you've got a fairly recent linux distribution, running the gnome desktop and can watch any video you come across, you should be fine (at least once you've figured out how to get the curl development files)</li>
</ul>
<br/>
<i>Getting the source code</i>
<ul>
	<li>Create a new directory, I've called it Development, you can call it whatever you want</li>
	<li>In this directory run git clone https://github.com/gtkd-developers/GtkD.git to get the latest GtkD source</li>
	<li>Then, still in the same directory run git clone https://github.com/AlexHorvat/KhanAcademyViewer.git to get the Khan Academy Viewer source</li>
	<li>Go into KhanAcademyViewer directory</li>
	<li>Run command make, might take a minute or two</li>
	<li>Done, now run ./KhanAcademyViewer to get the viewer going</li>
</ul>
<br/>
<i>Or if you like command line stuff</i>
<br/>
<code>
	mkdir Development<br/>
	cd Development<br/>
	git clone https://github.com/gtkd-developers/GtkD.git<br/>
	git clone https://github.com/AlexHorvat/KhanAcademyViewer.git<br/>
	cd KhanAcademyViewer<br/>
	make<br/>
	./KhanAcademyViewer<br/>
</code>
<br/>
<strong>Something's gone wrong!</strong>
<br/>
<br/>
<i>I only get sound while playing a video?</i>
<br/>
In fedora you need to setup <a href="http://rpmfusion.org/Configuration" target="_blank">RPM Fusion</a>. Install RPM Fusion Free, then go into your package manager and install GStreamer 1.0 libav-based plug-ins.

<i>Going to fullscreen and back makes weird things happen!</i>
<br/>
Currently this program uses ximagesink for displaying the video - this is what works best on my computer, however, xvimagesink may work better for you, to enable it go into VideoControl.d and replace the "ximagesink" string with "xvimagesink".

<i>Something else is wrong!</i>
<br/>
Rebuild Khan Academy Viewer using <code>make debug</code> instead of just <code>make</code>, now run the application from a console and file a bug report along with the output from the console.