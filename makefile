compiler = dmd -v -O -release -inline -noboundscheck
target = ./KhanAcademyViewer

all:
	$(compiler) ./KhanAcademyViewer.d ./Windows/*.d ./DataStructures/*.d ./Include/*.d ./Workers/*.d ./Controls/*.d

clean:
	$(RM) $(target) *.o

