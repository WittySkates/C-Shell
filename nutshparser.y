%{
// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and how to use Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
// Only "alias name word", "cd word", and "bye" run.
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include "global.h"

int yylex(void);
int yyerror(char *s);
int getlogin_r(char *buf, size_t bufsize);
int runCD(char* arg);
int homeCD();
int runSetAlias(char *name, char *word);
int printWorkingDir();
int printForeignDir(char *path);
int runWordCount(char *files);
char* concat(const char *s1, const char *s2);
char* concatArgs(const char *s1, const char *s2);
%}

%union {char *string;}

%start cmd_line
%token <string> BYE CD STRING ALIAS END PWD
%type <string> ARGS

%%
cmd_line    :
	BYE END							{exit(1); return 1; }
	| CD STRING END					{runCD($2); return 1;}
	| CD END						{homeCD(); return 1;}
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
	| PWD END						{runPWD(); return 1;}
	| STRING END					{execute($1, ""); return 1;}
	| STRING ARGS END				{execute($1, $2); return 1;}
	;
	
ARGS		:
	STRING							{$$ = $1;}
	| ARGS STRING					{$$ = concatArgs($$, $2);}
	;
	
%%

int yyerror(char *s) {
  printf("%s\n",s);
  return 0;
  }

char* concat(const char *s1, const char *s2)
{
    char *result = malloc(strlen(s1) + strlen(s2) + 1);
    strcpy(result, s1);
    strcat(result, s2);
	//printf("Result: %s\n", result);
    return result;
}

char* concatArgs(const char *s1, const char *s2)
{
    char *result = malloc(strlen(s1) + strlen(s2) + strlen(" ") + 1);
    strcpy(result, s1);
	strcat(result, " ");
    strcat(result, s2);
	//printf("Result: %s\n", result);
    return result;
}

// Trying to make a catch all for all non built in commands
int execute(char *cmd, char *args) {
	pid_t pid;

	int arg_amount = 2;
	for (int i = 0; i < strlen(args); i++) {
		if(args[i] == ' '){
			arg_amount++;
		}
	}

	char* paramList[arg_amount];
	paramList[0] = cmd;

	char *arg = strtok(args, " ");
	int i = 1;
	while(arg != NULL){
		paramList[i] = arg;
		i++;
		arg = strtok(NULL, " ");
	}
	paramList[i] = NULL;

	char* command = concat("/bin/", cmd);

	if ((pid = fork()) == -1)
		perror("fork error\n");
	else if (pid == 0) {
		execv(command, paramList);
		printf("Return not expected. Must be an execv error.n\n");
		exit(0);
	}
	else {
		wait();
		if(strcmp(cmd, "cat")==0){
			printf("\n");
		}
	}
}

int runPWD() {
	getcwd(cwd, sizeof(cwd));
    printf("%s\n", cwd);
}

int runCD(char* arg) {
	if (arg[0] != '/') { // arg is relative path
		strcat(varTable.word[0], "/");
		strcat(varTable.word[0], arg);

		if(chdir(varTable.word[0]) == 0) {
			return 1;
		}
		else {
			getcwd(cwd, sizeof(cwd));
			strcpy(varTable.word[0], cwd);
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // arg is absolute path
		if(chdir(arg) == 0){
			strcpy(varTable.word[0], arg);
			return 1;
		}
		else {
			printf("Directory not found\n");
                       	return 1;
		}
	}
}

int homeCD() {											// function to change directory to /home/user
	if(chdir(varTable.word[1]) == 0) {					// check if you can change directory to user
		strcpy(varTable.word[0], varTable.word[1]);		// if so, update present working directory
		return 1;
	}
	else {
		getcwd(cwd, sizeof(cwd));						// if not, update cwd
		strcpy(varTable.word[0], cwd);					// set pwd to be cwd
		printf("Directory not found\n");
		return 1;
	}
}

int runSetAlias(char *name, char *word) {
	for (int i = 0; i < aliasIndex; i++) {
		if(strcmp(name, word) == 0){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		else if((strcmp(aliasTable.name[i], name) == 0) && (strcmp(aliasTable.word[i], word) == 0)){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		else if(strcmp(aliasTable.name[i], name) == 0) {
			strcpy(aliasTable.word[i], word);
			return 1;
		}
	}
	strcpy(aliasTable.name[aliasIndex], name);
	strcpy(aliasTable.word[aliasIndex], word);
	aliasIndex++;

	return 1;
}

// int printWorkingDir(){
// 	DIR * d = opendir(varTable.word[0]); 															// open the path
//   	if(d==NULL) return 1; 																			// if was not able return
//   	struct dirent * dir; 																			// for the directory entries
//   	while ((dir = readdir(d)) != NULL) 																// if we were able to read somehting from the directory
//     {
//       if(dir-> d_type != DT_DIR) 																	// if the type is not directory just print it with blue
//         printf("%s%s\n",BLUE, dir->d_name);
//       else if(dir -> d_type == DT_DIR && strcmp(dir->d_name,".")!=0 && strcmp(dir->d_name,"..")!=0 ) // if it is a directory
//       {
//         printf("%s%s\n",GREEN, dir->d_name); 														// print its name in green
//         char d_path[255]; 																			// here I am using sprintf which is safer than strcat
//         sprintf(d_path, "%s/%s", varTable.word[0], dir->d_name);
//       }
//     }
//     closedir(d); 																					// finally close the directory
// }

// int printForeignDir(char *path){
// 	char temp[PATH_MAX];
// 	strcat(temp, varTable.word[0]);																	// create a string of the pwd/path
// 	strcat(temp, "/");
// 	strcat(temp, path);
// 	DIR * d = opendir(temp); 																		// open the path
//   	if(d==NULL) return 1; 																			// if was not able return
//   	struct dirent * dir; 																			// for the directory entries
//   	while ((dir = readdir(d)) != NULL) 																// if we were able to read somehting from the directory
//     {
//       if(dir-> d_type != DT_DIR) 																	// if the type is not directory just print it with blue
//         printf("%s%s\n",BLUE, dir->d_name);
//       else if(dir -> d_type == DT_DIR && strcmp(dir->d_name,".")!=0 && strcmp(dir->d_name,"..")!=0 ) // if it is a directory
//       {
//         printf("%s%s\n",GREEN, dir->d_name); 														// print its name in green
//         char d_path[255]; 																			// here I am using sprintf which is safer than strcat
//         sprintf(d_path, "%s/%s", temp, dir->d_name);
//       }
//     }
//     closedir(d); 																					// finally close the directory
// 	temp[0] = 0;
// }