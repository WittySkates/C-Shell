all:
	flex json.l
	bison -d json.y
	# Since we have noyywrap enabled, we don't need to compile with -lfl
	g++ -o json main.cpp lex.yy.c json.tab.c
	# By the way, this will throw some warnings. They're harmless, and you can
	# suppress them if you want.
