compiler = dmd -O -release -noboundscheck
target = ./KhanAcademyViewer

all:
	$(compiler) ./KhanAcademyViewer.d ./Windows/*.d ./DataStructures/*.d ./Include/*.d ./Workers/*.d ./Controls/*.d

clean:
	$(RM) $(target) *.o

