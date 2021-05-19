all : langlex.l lang.y
	flex -o langlex.c langlex.l
	bison -o lang.c lang.y
	gcc lang.c -o parser
	rm -f langlex.c lang.c

clean :
	rm -f langlex.c lang.c parser