%token _class attributes methods _int
%token _main _print _scan _if
%token _else _while _this id
%token nentero nreal _float
%token  dosp coma pyc punto
%token pari pard relop addop
%token mulop asig cori cord
%token llavei llaved 
%token _return

%{

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <cstdlib>
#include <string>
#include <iostream>
#include <algorithm>
#include <string>
#include "comun.h"
using namespace std;

// Variables y Funciones del Analizador Lexico
extern int ncol, nlin, findefichero;
extern int yylex();
extern char *yytext;
extern FILE *yyin;
int yyerror(char *s);
const int MEM = 16384;
int ACTUAL_MEM = 0;
int ETIQ = 0;
TablaSimbolos *ts = new TablaSimbolos(NULL);
void deleteScope(TablaSimbolos* root);
TablaSimbolos* createScope(TablaSimbolos* root);
TablaTipos* tp = new TablaTipos(); 
Simbolo buscarClase(TablaSimbolos *root, string nombre);
Simbolo buscar(TablaSimbolos *root, string nombre);
bool anyadir(TablaSimbolos *t,Simbolo s);
bool buscarAmbito(TablaSimbolos *root, string nombre);
string nuevoTemporal(int nerror, int nlin, int ncol, const char *s);
string nuevaEtiq();
string getRelop(string op);
int getRelopIndex(string op);
int NuevoTipoArray(int dim, int tbase);
int calcularDireccionArray(int dirbase);
int getTbase(int tipo);
int getDt(int tipo);

// DONE:  	
//			- 

// TO DO: 
//			- arrays
//			- probar varias condiciones en los ifs (&& --> *)


%}
%%
S : _class id llavei attributes dosp BDecl methods dosp Metodos llaved   	{
																				$$.code = $6.code + $9.code;
																				$$.code += "halt\n";
																				cout << $$.code;
																		   		int tk = yylex();
																		   		if (tk != 0) yyerror("");
																			};

Metodos : _int _main pari pard Bloque { $$.code = $5.code; };

Tipo 	: _int {$$.tipo = ENTERO; }
	 	| _float {$$.tipo = REAL; };

Bloque : llavei {ts = new TablaSimbolos(ts);} BDecl SeqInstr llaved 	{
																	 		$$.code = $3.code + $4.code;
																	 		deleteScope(ts);
																			ts = ts->root;
																		};

BDecl 	: BDecl DVar {$$.code = "";}
	  	| {$$.code = "";};

DVar : Tipo { $$.tipo = $1.tipo; } LIdent pyc {$$.code = "";};

LIdent : LIdent coma {$$.tipo = $0.tipo;} Variable {}
	   | {$$.tipo = $0.tipo;} Variable {};

Variable : 	id { $$.size = 1; $$.tipo = $0.tipo; } V   	{
															if(!buscarAmbito(ts,$1.lexema))  {
																Simbolo s;
																s.nombre = $1.lexema;
																s.tipo = getTbase($3.tipo);	//ENTERO, REAL o pos. ARRAY
																ACTUAL_MEM += $3.size;
																s.dir = to_string(ACTUAL_MEM);
																s.size = $3.size;
																anyadir(ts,s);

																if (ACTUAL_MEM >= MEM)
																	msgError(ERR_NOCABE,$1.nlin,$1.ncol,$1.lexema);
															}    
															else{
																msgError(ERRYADECL,$1.nlin,$1.ncol,$1.lexema);  
															}        
														};

V 	: cori nentero cord { $$.size = $0.size * atoi($1.lexema); $$.tipo = $0.tipo; } V 	{ 
																			$$.size = $5.size;
																			int dt = atoi($1.lexema);
																			$$.tipo = NuevoTipoArray(dt, $5.tipo);
																		}
	| 	{
			$$.size = $0.size;
			$$.tipo = $0.tipo;
		};

SeqInstr : SeqInstr Instr 								{ $$.code = $1.code + $2.code; }
		 | {  };

Instr : pyc {  }
	  | Bloque { $$.code = $1.code; }
	  | Ref asig Expr pyc  								{ 	
															$$.code = $1.code + $3.code;
															if($1.tipo == ENTERO && $3.tipo == REAL){
																$$.code += "mov " + $3.temp + " A\n";
																$$.code += "rtoi\n";
																$$.code += "mov A " + $3.temp + "\n";
															}
															else if($1.tipo == REAL && $3.tipo == ENTERO){
																$$.code += "mov " + $3.temp + " A\n";
																$$.code += "itor\n";
																$$.code += "mov A " + $3.temp + "\n";
															}

															$$.code += "mov " + $3.temp + " " + $1.temp + "\t\t; Instr : Ref asig Expr pyc \n";
														}
	  | _print pari Expr pard pyc 						{
		  													$$.code = $3.code;
															if ($3.tipo == ENTERO){
																$$.code += "wri " + $3.temp+ "\t; print valor entero de temporal\n";
															}
															else if($3.tipo == REAL){
																$$.code += "wrr " + $3.temp +"\t; print valor real de temporal\n";
															}
															$$.code += "wrl\n";
														}
	  | _scan pari Ref pard pyc 						{
															$$.code = $3.code;
															if ($3.tipo == ENTERO){
																$$.code += "rdi " + $3.temp +  "\t; guardar valor entero en temporal\n";
															}
															else if($3.tipo == REAL){
																$$.code += "rdr " + $3.temp + "\t; guardar valor real en temporal\n";
															}
	  													}
	  | _if pari Expr pard Instr 						{
															$$.code = $3.code;
															$$.code += "mov " + $3.temp + " A\n";
		  													string etiqueta = nuevaEtiq();
															$$.code += "jz " + etiqueta + " \t ; if \n";
															$$.code += $5.code;
															$$.code += etiqueta + " ";
	  													}
	  | _if pari Expr pard Instr _else Instr 			{
		  													$$.code = $3.code;
															string etiqueta1 = nuevaEtiq();
															string etiqueta2 = nuevaEtiq();
															$$.code += "mov " + $3.temp + " A\n";
															$$.code += "jz " + etiqueta1 + "\n";
															$$.code += $5.code;
															$$.code += "jmp " + etiqueta2 + "\n";
															$$.code += etiqueta1 + " ";
															$$.code += $7.code;
															$$.code += etiqueta2 + " ";
														}
	  | _while pari Expr pard Instr 					{
		  													string etiqueta1 = nuevaEtiq();
															string etiqueta2 = nuevaEtiq();
															$$.code = etiqueta1 + " ";
															$$.code += $3.code;
															$$.code += "mov " + $3.temp + " A\n";
															$$.code += "jz " + etiqueta2 + "\t ; if else\n";
															$$.code += $5.code;
															$$.code += "jmp " + etiqueta1 + "\n";
															$$.code += etiqueta2 + " ";
	  													};

Expr : 	Expr relop Esimple 							{
														string temp_final = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
														if(($1.tipo == ARRAY || $3.tipo == ARRAY)){
															msgError(ERR_NO_ATRIB,$2.nlin,$2.ncol,$2.lexema);
														}			
														string op = $2.lexema;								
														$$.code = $1.code;
														$$.code += $3.code;
														if($1.tipo == ENTERO && $3.tipo == ENTERO){
															$$.code += "mov " + $1.temp + " A\n";
															$$.code += getRelop(op) + "i " + $3.temp + "\t; Expr relop Esimple\n";
															
														}
														else if($1.tipo == ENTERO && $3.tipo == REAL){
															string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
															$$.code += "mov " + $1.temp + " A\n";
															$$.code += "itor \n";
															$$.code += getRelop(op) + "r " + $3.temp + "\t; Expr relop Esimple\n";
														}
														else if($1.tipo == REAL && $3.tipo == ENTERO){
															string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
															$$.code += "mov " + $3.temp + " A\n";
															$$.code += "itor \n";
															$$.code += getRelop(op) + "r " + temp1 + "\t; Expr relop Esimple\n";
														}	
														else { //reales
															$$.code += "mov " + $1.temp + " A\n";
															$$.code += getRelop(op) + "r " + $3.temp + "\t; Expr relop Esimple\n";
														}
														$$.code += "mov A " + temp_final + "\t; guardar el resultado en temporal\n";
														$$.temp = temp_final;
													}
	 |  Esimple 									{ 
		 												$$.code = $1.code;
														$$.tipo = $1.tipo;	
													};

Esimple : Esimple addop Term  	{   
									string temp_final = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
									$$.temp = temp_final;
									string op = "";
									string aux_impr = $2.lexema;
									if(strcmp($2.lexema,"+")==0){
										op = "add";
									}
									else 
										op = "sub";

									if($1.tipo == ENTERO && $3.tipo == ENTERO){
										//$$.code = "; ENTEROS \n";
										$$.code = $1.code;
										$$.tipo = ENTERO;
										$$.code += $3.code; //se mete en la A el resultado de Term
										$$.code += "mov " + $1.temp + " A\n";
										$$.code += op + "i " + $3.temp + "\t; ENTERO "+ aux_impr + " ENTERO\n";
									}
									else if($1.tipo == ENTERO && $3.tipo == REAL){
										$$.code = $1.code;
										$$.tipo = REAL;
										string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
										$$.code += "mov " + $1.temp + " A\n";
										$$.code += "itor \n";
										$$.code += "mov A " + temp1 + " \n";
										$$.code += $3.code;
										$$.code += "mov " + temp1 + " A\n";
										$$.code += op +"r " + $3.temp + "\t; ENTERO " + aux_impr + " REAL\n";
										//ACTUAL_MEM--;
									}
									else if($1.tipo == REAL && $3.tipo == ENTERO){
										$$.code = $1.code;
										$$.tipo = REAL;
										$$.code += $3.code;
										string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
										$$.code += "mov " + $3.temp + " A\n";
										$$.code += "itor \n";
										$$.code += "mov A " + temp1 + " \n";
										$$.code += "mov " + $1.temp + " A\n";
										$$.code += op +"r " + temp1 + "\t; REAL " + aux_impr + " REAL\n";
										//ACTUAL_MEM--;
									}	
									else { //reales
										//$$.code = "; REALES \n";
										$$.code = $1.code;
										$$.tipo = REAL;
										$$.code += $3.code;
										$$.code += "mov " + $1.temp + " A\n";
										$$.code += op + "r " + $3.temp + "\t; REAL " + aux_impr + " REAL\n";
							  		}
									$$.code += "mov A " + temp_final + "\t; guardar el resultado en temporal\n";
								}
		| Term 					{ 
									$$.code = $1.code;
									$$.tipo = $1.tipo;
									$$.temp = $1.temp;
			   					};

Term : Term mulop Factor   	{
								string temp_final = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
								$$.temp = temp_final;
								string op = "";
								string aux_impr = $2.lexema;
								if(strcmp($2.lexema,"*")==0){
									op = "mul";
								}
								else
									op = "div";

								if($1.tipo == ENTERO && $3.tipo == ENTERO){
									//$$.code = "; ENTEROS \n";
									$$.code = $1.code;
									$$.tipo = ENTERO;
									$$.code += $3.code;
									$$.code += "mov " + $1.temp + " A\n";
									$$.code += op + "i " + $3.temp + "\t; ENTERO " + aux_impr + " ENTERO\n";
								}
								else if($1.tipo == ENTERO && $3.tipo == REAL){
									$$.tipo = REAL;
									//$$.code = "; ENTERO Y REAL \n";
									$$.code = $1.code;
									string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
									$$.code += "mov " + $1.temp + " A\n";
									$$.code += "itor \n";
									$$.code += "mov A " + temp1 + "\n";
									$$.code += $3.code;
									$$.code += "mov " + temp1 + " A\n";
									$$.code += op + "r " + $3.temp + "\t; ENTERO " + aux_impr + " REAL\n";
									//ACTUAL_MEM--;
								}
								else if($1.tipo == REAL && $3.tipo == ENTERO){
									//$$.code = "; REAL y ENTERO \n";
									$$.code = $1.code;
									$$.tipo = REAL;
									$$.code += $3.code;
									string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
									$$.code += "mov " + $3.temp + " A\n";
									$$.code += "itor\n";
									$$.code += "mov A " + temp1 + "\n";
									$$.code += "mov " + $1.temp + " A\n";
									$$.code += op + "r " + temp1 + "\t; Term : REAL " + aux_impr + " ENTERO\n";
									//ACTUAL_MEM--;
								}	
								else { //reales
									//$$.code = "; REALES \n";
									$$.code = $1.code;
									$$.tipo = REAL;
									$$.code += $3.code;
									$$.code += "mov " + $1.temp + " A\n";
									$$.code += op + "r " + $3.temp + "\t; REAL " + aux_impr + " REAL\n";
								}

								$$.code += "mov A " + temp_final +"\n";// "\t; guardar el resultado en temporal\n";
						   	}
	 | Factor  	{ 
					$$.tipo = $1.tipo;
					$$.code = $1.code;
					$$.temp = $1.temp;
			   	};

Factor :  Ref      		{
							$$.code = $1.code;
							$$.tipo = $1.tipo;
							$$.temp = $1.temp;

							if($1.tipo >= ARRAY){ //arrays
								//msgError(ERRFALTAN,$1.nlin,$1.ncol,$1.lexema);
								string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
								$$.code += "mov " + $1.temp + " " + temp + "\t\t; guarda id " + $$.aux_lexema + "\n";
								$$.code += "muli #" + to_string(getDt($1.tipo)) +"\n";
								$$.code += "addi #" + to_string($1.dbase) + "\n";
								$$.code += "mov @A " + temp + "\n";
							}

							/*string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
							$$.code = $1.code;
							$$.code += "mov " + $1.temp + " " + temp + "\t\t; guarda id " + $$.aux_lexema + "\n";
							$$.code += "muli #" + getDt($1.tipo) +"\n";
							$$.code += "addi #" + to_string($1.dbase) + "\n";
							$$.code += "mov @A " + temp + "\n";
							$$.tipo = $1.tipo;
							$$.temp = $1.temp;*/
							
						}
						
	   | nentero  		{
							string aux_lex = $1.lexema;
							string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
							$$.tipo = ENTERO;
							$$.temp = temp;
							$$.code = "mov #" + aux_lex + " " + temp + "\t\t; guarda entero " + aux_lex + "\n";
						}
	   | nreal    		{
							string aux_lex = $1.lexema;
							string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
							$$.tipo = REAL;
							$$.temp = temp;
							$$.code = "mov $" + aux_lex + " " + temp + "\t\t; guarda real " + aux_lex + "\n";
						}
	   | pari Expr pard { 
		   					$$.code = "; Factor -> pari Expr pard\n";
							$$.code += $2.code; //"\t; Factor -> pari Expr pard\n";
							string aux = $2.temp;
							$$.temp = aux;
							$$.tipo = $2.tipo;
						};

Ref : _this punto id  			{
									Simbolo s = buscarClase(ts, $3.lexema);
									if (s.nombre != ""){
										string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
										$$.tipo = s.tipo;
										$$.temp = s.dir;
										string aux = $3.lexema;
										$$.aux_lexema = aux;
										$$.code = "mov " + s.dir + " " + temp + "\t\t; guarda id " + $$.aux_lexema + "\n";
										if($1.tipo >= ARRAY)
											$$.code = "mov #0"  + temp + "\t\t; guarda 0 y empieza recursivo arrays de " + $$.aux_lexema + "\n";
									}
									else
										msgError(ERR_NO_ATRIB, $1.nlin, $1.ncol, $1.lexema);
								}
	| id 						{ 
									Simbolo s = buscar(ts, $1.lexema);
									if (s.nombre != ""){
										string temp = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
										$$.tipo = s.tipo;
										$$.temp = s.dir;
										$$.dbase = atoi(s.dir.c_str());
										string aux = $1.lexema;
										$$.aux_lexema = aux;
										$$.code = "mov " + s.dir + " " + temp + "\t\t; guarda id " + $$.aux_lexema + "\n";
										if($1.tipo >= ARRAY)
											$$.code = "mov #0"  + temp + "\t\t; guarda 0 y empieza recursivo arrays de " + $$.aux_lexema + "\n";
									}
									else
										msgError(ERRNODECL, $1.nlin, $1.ncol, $1.lexema);
								}
	| Ref  cori {
				if($1.tipo < ARRAY){
					msgError(ERRFALTAN,$1.nlin,$1.ncol,$1.lexema);
				}
	} Esimple cord 	{
									/*if($1.tipo < ARRAY){
										msgError(ERRSOBRAN, $1.nlin, $1.ncol, $1.lexema);
									}
									else{*/
									if($4.tipo != ENTERO){
										msgError(ERRSOBRAN, $1.nlin, $1.ncol, $1.lexema);
									}
									/*int dirbase = atoi($1.temp.c_str());
									int dir_array = calcularDireccionArray(dirbase);*/
									string temporal = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
									$$.dbase = $1.dbase;
									$$.tipo = getTbase($1.tipo);
									$$.temp = temporal;

									$$.code = $3.code;
									/*string temp1 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);
									string temp2 = nuevoTemporal(ERR_MAXTMP, $1.nlin, $1.ncol, $1.lexema);

									$$.code += "mov " + $1.temp + " " + temp1 + "\n";
									$$.code += $3.code;
									$$.code += "mov " + $1.temp + " A\n";*/
									$$.code += "mov " + $1.temp + " A\n";
									$$.code += "muli #" + to_string(getDt($1.tipo)) +"\n"; 
									$$.code += "addi " + $3.temp + " \n";
									$$.code += "mov A " + temporal + " \n";
									//}
								};

Metodos : Met Metodos {};

Met : Tipo id pari Arg pard Bloque {};

Arg : {}
	| CArg {};

CArg : Tipo id CArgp {};

CArgp : coma Tipo id CArgp {}
	  | {};

Instr : _return Expr pyc {};

Factor : id pari Par pard {};

Par : {}
	| Expr CPar {};

CPar : {}
	 | coma Expr CPar {};

%%

void msgError(int nerror, int nlin, int ncol, const char *s){
	switch (nerror) {
		case ERRLEXICO: fprintf(stderr,"Error lexico (%d,%d): caracter '%s' incorrecto\n",nlin,ncol,s);
			break;
		case ERRSINT: fprintf(stderr,"Error sintactico (%d,%d): en '%s'\n",nlin,ncol,s);
			break;
		case ERREOF: fprintf(stderr,"Error sintactico: fin de fichero inesperado\n");
			break;
		case ERRLEXEOF: fprintf(stderr,"Error lexico: fin de fichero inesperado\n");
			break;
		default:
			fprintf(stderr,"Error semantico (%d,%d): ", nlin,ncol);
			switch(nerror) {
				case ERRYADECL: fprintf(stderr,"simbolo '%s' ya declarado\n",s);
					break;
				case ERRNODECL: fprintf(stderr,"identificador '%s' no declarado\n",s);
					break;
				case ERRDIM: fprintf(stderr,"la dimension debe ser mayor que cero\n");
					break;
				case ERRFALTAN: fprintf(stderr,"faltan indices\n");
					break;
				case ERRSOBRAN: fprintf(stderr,"sobran indices\n");
					break;
				case ERR_EXP_ENT: fprintf(stderr,"la expresion entre corchetes debe ser de tipo entero\n");
					break;
				case ERR_NO_ATRIB: fprintf(stderr,"el simbolo despues de 'this' debe ser un atributo\n");
					break;
				case ERR_NOCABE:fprintf(stderr,"la variable '%s' ya no cabe en memoria\n",s);
					break;
				case ERR_MAXVAR:fprintf(stderr,"en la variable '%s', hay demasiadas variables declaradas\n",s);
					break;
				case ERR_MAXTIPOS:fprintf(stderr,"hay demasiados tipos definidos\n");
					break;
				case ERR_MAXTMP:fprintf(stderr,"no hay espacio para variables temporales\n");
					break;
			}
	}
	exit(1);
}

int yyerror(char *s){
	extern int findefichero;
	if (findefichero) {
	   msgError(ERREOF,-1,-1,"");
	}
	else{  
	   msgError(ERRSINT,nlin,ncol-strlen(yytext),yytext);
	}
}
string getRelop(string op){
	int op_index = getRelopIndex(op);

	switch(op_index){
		case 1:
			return "eql";
		case 2:
			return "neq";
		case 3:
			return "lss";
		case 4:
			return "leq";
		case 5:
			return "gtr";
		case 6:
			return "geq";
	}
}
int getRelopIndex(string op){
	if (op == "==")
		return 1;
	if (op == "!=")
		return 2;
	if (op == "<")
		return 3;
	if (op == "<=")
		return 4;
	if (op == ">")
		return 5;
	if (op == ">=")
		return 6;
}
bool equalsIgnoreCase(string s1, char* lexema){
	string s2 = string(lexema);
	transform(s2.begin(), s2.end(), s2.begin(), ::tolower);

	if (s1 == s2)
		return true;

	return false;
}
string nuevoTemporal(int nerror, int nlin, int ncol, const char *s){
	ACTUAL_MEM++;
	if ((ACTUAL_MEM + 1) >= MEM)
		msgError(nerror, nlin, ncol, s);
	return to_string(ACTUAL_MEM);
}
string nuevaEtiq(){
	ETIQ++;
	string etiqueta = "L"+to_string(ETIQ);
	return etiqueta;
}
int main(int argc, char *argv[]){
	FILE *fent;

	if (argc == 2) {
		fent = fopen(argv[1], "rt");
		if (fent) {
			yyin = fent;
			yyparse();
			fclose(fent);
		}
		else
			fprintf(stderr, "No puedo abrir el fichero\n");
	}
	else
		fprintf(stderr, "Uso: ejemplo <nombre de fichero>\n");
}
/*****TABLA TIPOS******/
int NuevoTipoArray(int dim, int tbase){
	tp->tipos.push_back(Tipo{tbase,dim,ARRAY});
	return tp->tipos.size()-1;
}

int calcularDireccionArray(int dirbase){


	return 0;
}
int getTbase(int tipo){ return tp->tipos[tipo].tbase; } //$3.tipo ==> ENTERO = 1 --> REAL
int getDt(int tipo){ return tp->tipos[tipo].dt; }
/*****TABLA SIMBOLOS*********/
bool buscarAmbito(TablaSimbolos *root,string nombre){
	for(size_t i=0;i<root->simbolos.size();i++){
		if(root->simbolos[i].nombre == nombre){
			return true;
		}
	}
	return false;
}
bool anyadir(TablaSimbolos *t,Simbolo s){
	for(size_t i=0; i<t->simbolos.size();i++){
		if(t->simbolos[i].nombre==s.nombre){
			return false;
		}

	}
	t->simbolos.push_back(s);
	return true;
}
Simbolo buscar(TablaSimbolos *root,string nombre){
	for(size_t i = 0; i < root->simbolos.size(); i++){
		if(root->simbolos[i].nombre == nombre){
			return root->simbolos[i];
		}
	}
	if(root->root != NULL){ 
		return buscar(root->root, nombre);
	}
}
Simbolo buscarClase(TablaSimbolos *root, string nombre){
	if (root->root != NULL)
		return buscarClase(root->root, nombre);
	
	for(size_t i = 0; i < root->simbolos.size(); i++){
		if(root->simbolos[i].nombre == nombre){
			return root->simbolos[i];
		}
	}
}
TablaSimbolos* createScope(TablaSimbolos* root){
	TablaSimbolos* child = new TablaSimbolos(root);
	child->root = root;
	return child;
}
void deleteScope(TablaSimbolos* root){
	for(size_t i = 0; i < root->simbolos.size(); i++){
		ACTUAL_MEM-=root->simbolos[i].size;
	}
}