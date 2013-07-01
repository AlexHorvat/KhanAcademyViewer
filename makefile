compiler = dmd
release = -O -release -noboundscheck
debug = -debug
target = ./KhanAcademyViewer

all:
	$(compiler) $(release) ./KhanAcademyViewer.d ./Windows/*.d ./DataStructures/*.d ./Include/*.d ./Workers/*.d ./Controls/*.d
	
debug:
	$(compiler) $(debug) ./KhanAcademyViewer.d ./Windows/*.d ./DataStructures/*.d ./Include/*.d ./Workers/*.d ./Controls/*.d

clean:
	$(RM) $(target) *.o