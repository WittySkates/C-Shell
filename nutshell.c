// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and how to use Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
// Only "alias name word", "cd word", and "bye" run.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "global.h"
#include <unistd.h>

char *getcwd(char *buf, size_t size);
int yyparse();

int main()
{
    aliasIndex = 0;
    varIndex = 0;
    isStart = false;
    count = 0;
    isStringCond = false;

    getcwd(cwd, sizeof(cwd));

    strcpy(varTable.var[varIndex], "PWD");          // holds the Current working directory.
    strcpy(varTable.word[varIndex], cwd);           // UPDATE THIS WHENEVER YOU CHANGE DIRECTORIES
    varIndex++;

    strcpy(varTable.var[varIndex], "HOME");         // sets word in HOME to /home/*username*
    char user[PATH_MAX];
    getlogin_r(user, PATH_MAX);
    strcpy(varTable.word[varIndex], cwd);
    // strcpy(varTable.word[varIndex], "/home/");
    // strcat(varTable.word[varIndex], user);
    varIndex++;

    strcpy(varTable.var[varIndex], "PROMPT");
    strcpy(varTable.word[varIndex], "nutshell");
    varIndex++;

    strcpy(varTable.var[varIndex], "PATH");
    strcpy(varTable.word[varIndex], ".:/bin");
    varIndex++;

    system("clear");
    while(1)
    {
        printf("[%s%s]>> ",NORMAL_COLOR, varTable.word[2]);
        yyparse();
    }

   return 0;
}