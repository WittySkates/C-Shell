%{
#include "json_util.h"
#include <stdio.h>

int yylex(); // Defined in lex.yy.c

int yyparse(); // Need this definition so that yyerror can call it

extern object_t parser_result; // Need this so we can write to it in the "input" rule

void yyerror(char* e) {
	printf("Error: %s\n", e);

	// We'll have to call yyparse() again to restart parsing.
}
%}

	/*
	This block is needed to make sure that Bison has definitions for our JSON
	types. Without it, the #include "json_util.h" will not show up in the generated
	json.tab.h header, and the compiler will not be able to define YYSTYPE.
	*/
%code requires {
#include "json_util.h"
}

	/*
	Bison will generate a union type called YYSTYPE, which is the data type of
	the semantic value of every rule. In C/C++, a union is a single object that
	can have one of multiple types.

	Check json.l to see how to assign semantic value to tokens.
	*/
%define api.value.type union

	/* Semantic values for token types are all string*s, to keep it simple */
%token <std::string*> STRING_LITERAL NUMBER_LITERAL BOOLEAN_LITERAL NULL_LITERAL

	/* Semantic values for our rules - nice and easy to define now */
%nterm <object_t> object
%nterm <std::vector<keyval_t>*> key_value_list
%nterm <keyval_t> key_value

%%

	/*
	Input is a single object. When we find a complete object in the input stream,
	we set a global variable so that we can use the object later, then we return
	from yyparse.
	*/
input:
	  object { parser_result = $1; return 0; } ;

object:
	  '{' key_value_list '}'	{ $$ = make_composite_object($2); }
	| STRING_LITERAL			{ $$ = make_simple_object($1); }
	| NUMBER_LITERAL			{ $$ = make_simple_object($1); }
	| BOOLEAN_LITERAL			{ $$ = make_simple_object($1); }
	| NULL_LITERAL				{ $$ = make_simple_object($1); } ;

	/*
	A comma-separated list. Three different patterns here now, to represent
	lists with 1. no items, 2. one item, or 3. multiple items.
	*/
key_value_list:
	  %empty						{ $$ = new std::vector<keyval_t>(); }
	| key_value						{ $$ = new std::vector<keyval_t>(); $$->push_back($1); }
	| key_value_list ',' key_value	{ $$ = $1; $$->push_back($3); } ;

key_value:
	  STRING_LITERAL ':' object	{ $$ = make_keyval($1, $3); } ;
