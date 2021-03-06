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
#include <sys/wait.h>
#include <fcntl.h>
#include "global.h"

int yylex(void);
int yyerror(char *s);
int getlogin_r(char *buf, size_t bufsize);
int runCD(char* arg);
int homeCD();
int runSetAlias(char *name, char *word);
int removeAlias(char *name);
int listAlias();
int printWorkingDir();
int printForeignDir(char *path);
int runWordCount(char *files);
char* concat(const char *s1, const char *s2);
char* concatArgs(const char *s1, const char *s2);
int setEnv(char *variable, char *word);
int printEnv();
int unsetEnv(char *variable);
int runPWD();
int execute(char *cmd);
int removeAlias(char *name);
int byebye();
%}

%union {char *string;}

%start cmd_line
%token <string> BYE CD STRING ALIAS UNALIAS END PWD SETENV PRINTENV UNSETENV 
%type <string> ARGS SET

%%
cmd_line    :
	BYE END							{byebye(); return 1; }
	| CD STRING END					{runCD($2); return 1;}
	| CD END						{homeCD(); return 1;}
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
	| ALIAS END						{listAlias(); return 1;}
	| UNALIAS STRING END			{removeAlias($2); return 1;}
	| PWD END						{runPWD(); return 1;}
	| ARGS END						{execute($1); return 1;}
	| SETENV STRING SET END			{setEnv($2, $3); return 1;}
	| PRINTENV END					{printEnv(); return 1;}
	| UNSETENV STRING END			{unsetEnv($2); return 1;}
	;
	
ARGS		:
	STRING							{$$ = $1;}
	| ARGS STRING					{$$ = concatArgs($$, $2);}
	;

SET		:
	STRING							{$$ = $1;}
	| SET STRING					{$$ = concat($$, $2);}
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
int execute(char *cmd) {
	pid_t pid, gpid;
	int status;
	//printf("cmd: %s\n", cmd);
	int arg_amount = 2;
	int seperator_amount = 0;
	int pipe_amount = 0;
	bool output_present = false;
	for (int i = 0; i < strlen(cmd); i++) {
		if(cmd[i] == ' '){
			arg_amount++;
		}
		if(cmd[i] == '|'){
			pipe_amount++;
			seperator_amount++;
		}
		if(cmd[i] == '>'){
			seperator_amount++;
			output_present = true;
		}
	}

	char* paramList[seperator_amount + 1][arg_amount];
	char* token = strtok(cmd, " ");

	int i = 0;
	int j = 0;
	int ofd;
	int out_carrot = 0;
	while(token != NULL){
		if((strcmp(token, "|") == 0) || strcmp(token, ">") == 0 || strcmp(token, ">>") == 0){
			paramList[i][j] = NULL;
			if(strcmp(token, ">") == 0){
				out_carrot++;
			}
			if(strcmp(token, ">>") == 0){
				out_carrot++;
				out_carrot++;
			}
			i++;
			j = 0;
		}
		else if (strcmp(token, "<") == 0){
			token = strtok(NULL, " ");
			FILE *fp;
			long lSize;
			char *buffer;
			fp = fopen ( token , "rb" );
			if( !fp ) perror(token),exit(1);
			fseek( fp , 0L , SEEK_END);
			lSize = ftell( fp );
			rewind( fp );
			buffer = calloc( 1, lSize+1 );
			if( !buffer ) fclose(fp),fputs("memory alloc fails",stderr),exit(1);
			if( 1!=fread( buffer , lSize, 1 , fp) )
			fclose(fp),free(buffer),fputs("entire read fails",stderr),exit(1);

			paramList[i][j] = buffer;
			fclose(fp);
			j++;
			paramList[i][j] = NULL;
		}
		else{
			paramList[i][j] = token;
			if(out_carrot == 1){
				ofd = creat(token, 0644);
			}
			if(out_carrot == 2){
				ofd = open(token, O_APPEND | O_CREAT | O_RDWR);
			}
			//printf("I: %d J: %d T: %s\n", i,j,token);
			j++;
		}
		token = strtok(NULL, " ");
	}
	paramList[i][j] = NULL;
	
	int pipefds[2*pipe_amount];
	for(int p = 0; p < (pipe_amount); p++){
		if(pipe(pipefds + p*2) < 0) {
			perror("couldn't pipe");
			exit(EXIT_FAILURE);
		}
	}

	int commandc = 0;
	for(int k = 0; k < pipe_amount + 1; k++){
		pid = fork();
		if(pid == 0){
			// is last
			if(k == pipe_amount && out_carrot > 0){
				if(dup2(ofd, 1) < 0){
					perror("dup2");
					exit(EXIT_FAILURE);
				}
			}
			// Not first
			if (k != 0){
				if(dup2(pipefds[commandc-2], 0) < 0){
					perror("dup2");
					exit(EXIT_FAILURE);
				}
			}
			// Not last
			if(k != pipe_amount){
				if(dup2(pipefds[commandc+1], 1) < 0){
					perror("dup2");
					exit(EXIT_FAILURE);
				}
			}
			for(i = 0; i < 2*pipe_amount; i++){
				close(pipefds[i]);
			}
			if(out_carrot > 0){
				close(ofd);
			}
			char* cpath = malloc(sizeof(varTable.word[3]));
			strcpy(cpath, varTable.word[3]);

			int path_amount = 1;
			for (int i = 0; i < strlen(cpath); i++) {
				if(cpath[i] == ':'){
					path_amount++;
				}
			}
			char* path = strtok(cpath, ":");
			int path_c = 1;
			while(path != NULL){
				char* temp = concat(path, "/");
				char* command = concat(temp, paramList[k][0]);
				//printf("%s\n", command);
				if(access(command, F_OK) == 0){
					execv(command, paramList[k]);
					printf("Return not expected. Must be an execv error.\n");
				}
				else if(path_c == path_amount){
					printf("Command \'%s\' not found.\n", paramList[k][0]);
				}
				path_c++;
				path = strtok(NULL, ":");
				//printf("%s\n", paramList[k][0]);
			}
		}
		else if (pid < 0){
			perror("eror");
			exit(EXIT_FAILURE);
		}
		commandc+=2;

	}
	for(int i = 0; i < 2*pipe_amount; i++){
		close(pipefds[i]);
	}
	//close(ofd);
	if(!background){
		//Leaves zombie process (alternate is to wait(&status) and increase amount to high number?)
		// for(int i = 0; i < pipe_amount + 2; i++){
		// 	waitpid(pid, &status, WUNTRACED);
		// }
		for(int i = 0; i < pipe_amount + 10; i++){
			wait(&status);
		}
	}
	else{
		background = false;
	}
}

int byebye(){
	printf("Bye :)\n");
	exit(0);
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
			printf("Directory: %s\n", arg);
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

bool checkAlias (char *name, char *word){
	if(strcmp(name, word) == 0){
		return false;
	}
	for (int i = 0; i < aliasIndex; i++) {
		if((strcmp(word, aliasTable.name[i]) == 0)){
			return checkAlias(name, aliasTable.word[i]);
		}
	}
	return true;
}

int runSetAlias(char *name, char *word) {
	if(strcmp(name, word) == 0){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
	}

	if(!checkAlias(name, word)){
		printf("Error, expansion of \"%s\" would create a loop.\n", name);
		return 1;
	}

	for (int i = 0; i < aliasIndex; i++) {
		if(strcmp(aliasTable.name[i], name) == 0) {
			strcpy(aliasTable.word[i], word);
			return 1;
		}
	}

	strcpy(aliasTable.name[aliasIndex], name);
	strcpy(aliasTable.word[aliasIndex], word);
	aliasIndex++;
	return 1;
}

int removeAlias(char *name){
	int isFound = 0;
	char aliasName[128];
	strcpy(aliasName, name);
	for (int i = 0; i < aliasIndex; i++) {
		if(strcmp(aliasTable.name[i], name) == 0){
			isFound = 1;
			for(int j = i; j < aliasIndex-1; j++){
				strcpy(aliasTable.name[j], aliasTable.name[j+1]);
				strcpy(aliasTable.word[j], aliasTable.word[j+1]);
			}
			break;
		}
	}
	if(isFound == 1){
		aliasIndex--;
		return 1;
	}
	else{
		printf("There is no alias with the name: %s\n", aliasName);
		return 1;
	}
}

int listAlias(){
	for (int i = 0; i < aliasIndex; i++) {
		printf("%s=%s\n", aliasTable.name[i], aliasTable.word[i]);
	}
}

int setEnv(char *variable, char *word){
	for(int i = 0; i < varIndex; i++){
		if(strcmp(varTable.var[i], variable) == 0){
			strcpy(varTable.word[i], word);
			return 1;
		}
	}
	strcpy(varTable.var[varIndex], variable);
    strcpy(varTable.word[varIndex], word);
    varIndex++;
	return 1;
}

int printEnv(){
	for(int i = 0; i < varIndex; i++){
		printf("%s=%s\n", varTable.var[i], varTable.word[i]);
	}
	printf("VARINDEX: %d\n", varIndex);
}

int unsetEnv(char *variable){
	for(int i = 0; i < varIndex; i++){
		if(strcmp(variable, "PATH") == 0){
			fprintf(stderr, "The 'PATH' variable cannot be unbound\n");
			return 1;
		}
		else if(strcmp(variable, "HOME") == 0){
			fprintf(stderr, "The 'HOME' variable cannot be unbound\n");
			return 1;
		}
		else if(strcmp(varTable.var[i], variable) == 0){
			for(int j  = i; j < varIndex; j++){
				strcpy(varTable.word[j],varTable.word[j+1]);
				strcpy(varTable.var[j],varTable.var[j+1]);
			}
			varIndex--;
			return 1;
		}
	}
	printf("Error: variable not found!\n");
	return 1;
}
