compiler = dmd
release = -O -release -noboundscheck
debug = -debug -v
target = ./KhanAcademyViewer

all:
	$(compiler) $(release) ./KhanAcademyViewer.d ./*/*.d ../GtkD/src/*/*.d ../GtkD/srcgstreamer/*/*.d
	
debug:
	$(compiler) $(debug) ./KhanAcademyViewer.d ./*/*.d ../GtkD/src/*/*.d ../GtkD/srcgstreamer/*/*.d

clean:
	$(RM) $(target) *.o