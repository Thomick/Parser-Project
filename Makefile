NAME = lang

all : langlex.c lang.c
	gcc lang.c -o $(NAME)

langlex.c : langlex.l
	flex -o langlex.c langlex.l

lang.c : lang.y
	bison -o lang.c lang.y

clean :
	rm -f langlex.c lang.c $(NAME)