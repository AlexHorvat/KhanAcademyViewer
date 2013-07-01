Khan Academy Viewer
=================

A Gnome 3 desktop player for the Khan Academy.

<i>Why choose this over using the website?</i>
<ul>
	<li>Download videos and watch them offline</li>
	<li>Bookmark where you were up to</li>
	<li>Continuous play of the entire subject</li>
	<li>Easier to browse to a subject (in my opinion at least)</li>
</ul>

<i>How to build from source:</i>
<strong>Prerequisites</strong>
<ul>
	<li>Recent version of Gnome 3 (tested on GTK 3.6+)</li>
	<li>GStreamer 1.0+, with it's basic plugins and codecs</li>
	<li>Your system needs to be able to play h264 videos</li>
	<li>Video driver compatible with xvimagesink</li>
	<li>Git</li>
	<li>Dmd 2 <a href="http://dlang.org/download.html">Download here</a></li>
	<li>libcurl.so (in Fedora this is in the libcurl-devel package)</li>
	<li>This means nothing to you? If you've got a fairly recent linux distribution, running the gnome desktop and can watch any video you come across, you should be fine</li>
</ul>
	
<strong>Getting the source code</strong>
<ul>
	<li>Create a new directory, I've called it Development, you can call it whatever you want</li>
	<li>In this directory run git clone https://github.com/gtkd-developers/GtkD.git to get the latest GtkD source</li>
	<li>Then, still in the same directory run git clone https://github.com/AlexHorvat/KhanAcademyViewer.git to get the Khan Academy Viewer source</li>
	<li>Go into the Gtkd directory and run the command make -f GNUmakefile all (this might take a while)</li>
	<li>Back up to Development directory, then go into KhanAcademyViewer directory</li>
	<li>Run command make</li>
	<li>Done, now run ./KhanAcademyViewer to get the viewer going</li>
</ul>

<strong>Or if you like command line stuff</strong>
<code>
	mkdir Development
	cd Development
	git clone https://github.com/gtkd-developers/GtkD.git
	git clone https://github.com/AlexHorvat/KhanAcademyViewer.git
	cd GtkD
	make -f GNUmakefile all
	cd ..
	cd KhanAcademyViewer
	make
	./KhanAcademyViewer
</code>

<i>Somethings gone wrong!</i>
<strong>Only get sound while playing a video?</strong>
In fedora you need to setup <a href="http://rpmfusion.org/Configuration"</a>RPM Fusion</a>. Install RPM Fusion Free, then go into your package manager and install GStreamer 1.0 libav-based plug-ins.

<strong>The video never starts, I just get the spinner forever!</strong>
This could be because your computer doesn't support xvimagesink, the only time I've seen this happen is in a virtual machine without 3d acceleration, edit the file VideoWorker.d, replace the string "xvimagesink" with "ximagesink" but this will do strange things to fullscreen mode.

<strong>Something else is wrong!</strong>
Rebuild Khan Academy Viewer using <code>make debug</code> instead of just <code>make</code>, now run the application from a console and file a bug report along with the output from the console.