Khan Academy Viewer
=================

<h3>A Gnome 3 desktop player for the Khan Academy</h3>

<strong>Why choose this over using the website?</strong>
<ul>
	<li>Download videos and watch them offline</li>
	<li>Bookmark where you were up to</li>
	<li>Continuous play of the entire subject</li>
	<li>Easier to browse to a subject (in my opinion at least)</li>
</ul>

<strong>How to build from source:</strong>
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
	<li>This means nothing to you? If you've got a fairly recent linux distribution, running the gnome desktop and can watch any video you come across, you should be fine</li>
</ul>

<i>Getting the source code</i>
<ul>
	<li>Create a new directory, I've called it Development, you can call it whatever you want</li>
	<li>In this directory run git clone https://github.com/gtkd-developers/GtkD.git to get the latest GtkD source</li>
	<li>Then, still in the same directory run git clone https://github.com/AlexHorvat/KhanAcademyViewer.git to get the Khan Academy Viewer source</li>
	<li>Go into the Gtkd directory and run the command make -f GNUmakefile all (this might take a while)</li>
	<li>Back up to Development directory, then go into KhanAcademyViewer directory</li>
	<li>Run command make</li>
	<li>Done, now run ./KhanAcademyViewer to get the viewer going</li>
</ul>

<i>Or if you like command line stuff</i>
<code>
	mkdir Development<br/>
	cd Development<br/>
	git clone https://github.com/gtkd-developers/GtkD.git<br/>
	git clone https://github.com/AlexHorvat/KhanAcademyViewer.git<br/>
	cd GtkD<br/>
	make -f GNUmakefile all<br/>
	cd ..<br/>
	cd KhanAcademyViewer<br/>
	make<br/>
	./KhanAcademyViewer<br/>
</code>

<strong>Somethings gone wrong!</strong>
<br/>
<i>Only get sound while playing a video?</i>
<br/>
In fedora you need to setup <a href="http://rpmfusion.org/Configuration" target="_blank">RPM Fusion</a>. Install RPM Fusion Free, then go into your package manager and install GStreamer 1.0 libav-based plug-ins.

<i>The video never starts, I just get the spinner forever!</i>
<br/>
This could be because your computer doesn't support xvimagesink, the only time I've seen this happen is in a virtual machine without 3d acceleration, edit the file VideoWorker.d, replace the string "xvimagesink" with "ximagesink" but this will do strange things to fullscreen mode.

<i>Something else is wrong!</i>
<br/>
Rebuild Khan Academy Viewer using <code>make debug</code> instead of just <code>make</code>, now run the application from a console and file a bug report along with the output from the console.