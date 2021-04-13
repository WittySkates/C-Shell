%{
// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and how to use Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
// Only "alias name word", "cd word", and "bye" run.
#include "nutshparser.tab.h"
#include <string.h>
#include "global.h"

char* subAliases(char* name){
    for (int i = 0; i < aliasIndex; i++) {
        if(strcmp(aliasTable.name[i], name) == 0) {
            return aliasTable.word[i];
        }
    }
    return name;
}
bool ifAlias(char* name){
    for (int i = 0; i < aliasIndex; i++) {
        if(strcmp(aliasTable.name[i], name) == 0) {
            return true;
        }
    }
    return false;
}

char* subEnv(char* var){
    for (int i = 0; i < varIndex; i++) {
        if(strcmp(varTable.var[i], var) == 0) {
            return varTable.word[i];
        }
    }
    return var;
}
bool ifEnv(char* var){
    for (int i = 0; i < varIndex; i++) {
        if(strcmp(varTable.var[i], var) == 0) {
            return true;
        }
    }
    return false;
}
%}
%array
%option noyywrap
%x string_condition
%x is_env

CHAR            [.A-Za-z0-9!\/_-][.A-Za-z0-9!\/_-]*
ANYCHAR         [}{)(*&%$#@!`;,\.a-zA-Z0-9'/*_=~ -][}{)(*&%$#@!`;,\.a-zA-Z0-9'/*_=~ -]*
ENV             \$\{
%%

<string_condition>{ANYCHAR}+    { yylval.string = strdup(yytext); printf("yytext: %s\n", yytext); return STRING;}
<string_condition>[\"]          {BEGIN(INITIAL);}

<is_env>{CHAR}+                 {
                                    if(ifEnv(yytext)) {
                                        printf("yytext: %s\n", yytext);
                                        //source: https://www.cs.princeton.edu/~appel/modern/c/software/flex/flex.html
                                        char *yycopy = strdup(subEnv(yytext) );
                                        for ( int i = strlen(subEnv(yytext)) - 1; i >= 0; --i )
                                                unput( yycopy[i] );
                                            free( yycopy );
                                        BEGIN(INITIAL);
                                    }
                                    else {
                                        printf("yytext: %s\n", yytext);
                                        yylval.string = strdup(yytext);
                                        return STRING;
                                    };
                                            
                                }
<is_env>[\}]                    {BEGIN(INITIAL);}

[ ]		            { }
bye                 { count++; return BYE;              }
cd		            { count++; return CD;               }
alias		        { isStart = true; return ALIAS;     }
unalias             { isStart = true; return UNALIAS;   }
pwd                 { count++; return PWD;              }
setenv              { count++; return SETENV;           }
unsetenv            { count++; return UNSETENV;         }        
printenv            { count++; return PRINTENV;         }   

{ENV}               {BEGIN(is_env);}
"\n"		        { isStart = false; count = 0; return END;   }
[\"]                { BEGIN(string_condition); }
{CHAR}+             {
                        if(ifAlias(yytext) && count == 0 && !isStart) {
                            printf("yytext: %s\n", yytext);
                            //source: https://www.cs.princeton.edu/~appel/modern/c/software/flex/flex.html
                            char *yycopy = strdup( subAliases(yytext) );
                            for ( int i = strlen(subAliases(yytext)) - 1; i >= 0; --i )
                                    unput( yycopy[i] );
                                free( yycopy );
                        } 
                        else {
                            count++;
                            printf("yytext: %s\n", yytext);
                            yylval.string = strdup(yytext);
                            return STRING;
                        };
                     }
%%