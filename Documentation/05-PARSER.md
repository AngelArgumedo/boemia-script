# Analisis Sintactico - Parser

## Introduccion

El Parser (Analizador Sintactico) es la segunda fase del compilador. Su responsabilidad es tomar la secuencia de tokens generada por el Lexer y construir un Arbol de Sintaxis Abstracta (AST) que representa la estructura jerarquica del programa.

## Que es un Parser?

Un parser verifica que los tokens sigan las reglas gramaticales del lenguaje y los organiza en una estructura de arbol que facilita el analisis posterior.

### Ejemplo de Parsing

**Entrada (Tokens)**:
```
[MAKE] [IDENTIFIER "x"] [COLON] [TYPE_INT] [ASSIGN] [INTEGER "5"] [SEMICOLON]
```

**Salida (AST)**:
```
VariableDecl {
    name: "x"
    data_type: INT
    value: Expr.integer(5)
    is_const: false
}
```

## Estructura del Parser

```mermaid
classDiagram
    class Parser {
        -lexer: *Lexer
        -current_token: Token
        -peek_token: Token
        -allocator: Allocator
        -errors: ArrayList
        +init(allocator, lexer) Parser
        +deinit() void
        +parseProgram() Program
        -nextToken() void
        -expectToken(type) void
        -parseStatement() Stmt
        -parseExpression(precedence) Expr
        -parsePrimary() Expr
    }

    class Token {
        +type: TokenType
        +lexeme: []const u8
        +line: usize
        +column: usize
    }

    class Program {
        +statements: []Stmt
        +allocator: Allocator
    }

    class Stmt {
        <<union>>
        +variable_decl
        +assignment
        +if_stmt
        +while_stmt
        +for_stmt
        +return_stmt
        +expr_stmt
        +print_stmt
        +block
        +function_decl
    }

    class Expr {
        <<union>>
        +integer
        +float
        +string
        +boolean
        +identifier
        +binary
        +unary
        +call
    }

    Parser --> Token
    Parser --> Program
    Program --> Stmt
    Stmt --> Expr
```

## Estrategia de Parsing: Descendente Recursivo

Boemia Script utiliza un parser descendente recursivo (Recursive Descent Parser), una tecnica donde cada regla gramatical se implementa como una funcion recursiva.

```mermaid
flowchart TD
    A[parseProgram] --> B[parseStatement]
    B --> C{Tipo de Statement}

    C -->|MAKE/SEAL| D[parseVariableDecl]
    C -->|IF| E[parseIfStatement]
    C -->|WHILE| F[parseWhileStatement]
    C -->|FOR| G[parseForStatement]
    C -->|RETURN| H[parseReturnStatement]
    C -->|PRINT| I[parsePrintStatement]
    C -->|FN| J[parseFunctionDecl]
    C -->|IDENTIFIER| K{peek == ASSIGN?}

    K -->|Si| L[parseAssignment]
    K -->|No| M[parseExpressionStatement]

    D --> N[parseExpression]
    E --> N
    F --> N
    L --> N
    M --> N

    N --> O[parsePrimary]
    O --> P{Tipo de Token}

    P -->|INTEGER| Q[Expr.integer]
    P -->|IDENTIFIER| R[Expr.identifier o Call]
    P -->|LPAREN| S[parseExpression recursivo]

    style A fill:#4a90e2
    style N fill:#f5a623
    style O fill:#7ed321
```

## Tecnica de Dos Tokens: current y peek

El parser mantiene dos tokens simultaneos para poder tomar decisiones basadas en el contexto:

```mermaid
graph LR
    A[current_token] -->|Token actual| B[Decision de parsing]
    C[peek_token] -->|Siguiente token| B

    B --> D[nextToken]
    D --> E[current = peek]
    D --> F[peek = lexer.nextToken]

    style A fill:#4a90e2
    style C fill:#f5a623
    style B fill:#7ed321
```

### Ejemplo Visual

```
Tokens: MAKE IDENTIFIER COLON TYPE_INT ASSIGN INTEGER SEMICOLON
        ^    ^
        |    |
     current peek

Despues de nextToken():

Tokens: MAKE IDENTIFIER COLON TYPE_INT ASSIGN INTEGER SEMICOLON
             ^         ^
             |         |
          current     peek
```

## Funciones Principales del Parser

### parseProgram()

Punto de entrada del parser. Construye el programa completo.

```mermaid
flowchart TD
    A[parseProgram] --> B[Crear lista statements]
    B --> C{current_token != EOF?}
    C -->|Si| D[parseStatement]
    D --> E[Agregar a lista]
    E --> C
    C -->|No| F[Retornar Program]

    D -->|Error| G[Skip hasta SEMICOLON]
    G --> H[Continuar parsing]
    H --> C

    style A fill:#4a90e2
    style F fill:#7ed321
    style G fill:#d0021b
```

**Manejo de Errores**: Si un statement falla, el parser salta hasta el siguiente punto y coma y continua, permitiendo reportar multiples errores en una sola ejecucion.

### parseStatement()

Determina que tipo de statement parsear basado en el token actual.

```mermaid
flowchart TD
    A[parseStatement] --> B{current_token.type}

    B -->|MAKE/SEAL| C[parseVariableDecl]
    B -->|IF| D[parseIfStatement]
    B -->|WHILE| E[parseWhileStatement]
    B -->|FOR| F[parseForStatement]
    B -->|RETURN| G[parseReturnStatement]
    B -->|PRINT| H[parsePrintStatement]
    B -->|FN| I[parseFunctionDecl]
    B -->|LBRACE| J[parseBlockStatement]
    B -->|IDENTIFIER| K{peek == ASSIGN?}
    B -->|Otro| L[parseExpressionStatement]

    K -->|Si| M[parseAssignment]
    K -->|No| L

    style A fill:#4a90e2
    style B fill:#f5a623
```

### parseVariableDecl()

Parsea declaraciones de variables (make/seal).

```mermaid
sequenceDiagram
    participant P as Parser
    participant L as Lexer

    P->>P: current = MAKE
    P->>P: is_const = false
    P->>P: nextToken()

    P->>P: Verificar IDENTIFIER
    P->>P: name = lexeme

    P->>P: expectToken(COLON)
    P->>P: Verificar tipo de dato
    P->>P: data_type = fromString

    P->>P: expectToken(ASSIGN)
    P->>P: nextToken()
    P->>P: value = parseExpression(0)

    P->>P: Verificar SEMICOLON
    P->>P: nextToken()

    P->>P: Retornar VariableDecl
```

**Gramatica**:
```
variable_decl := ('make' | 'seal') IDENTIFIER ':' TYPE '=' expression ';'
```

### parseExpression() - Pratt Parsing

El parser utiliza el algoritmo de Pratt para parsear expresiones con precedencia de operadores correcta.

```mermaid
flowchart TD
    A[parseExpression min_precedence] --> B[left = parsePrimary]
    B --> C{Siguiente es operador?}
    C -->|No| D[Retornar left]
    C -->|Si| E{precedence >= min_precedence?}
    E -->|No| D
    E -->|Si| F[op = getInfixOp]
    F --> G[prec = getPrecedence]
    G --> H[nextToken]
    H --> I[right = parseExpression prec+1]
    I --> J[left = BinaryExpr left op right]
    J --> C

    style A fill:#4a90e2
    style B fill:#f5a623
    style D fill:#7ed321
```

**Tabla de Precedencia**:

| Nivel | Operadores | Descripcion | Asociatividad |
|-------|------------|-------------|---------------|
| 6 | `*`, `/` | Multiplicacion, Division | Izquierda |
| 5 | `+`, `-` | Suma, Resta | Izquierda |
| 4 | `<`, `>`, `<=`, `>=` | Comparacion | Izquierda |
| 3 | `==`, `!=` | Igualdad | Izquierda |

**Ejemplo de Precedencia**:

```
Expresion: 2 + 3 * 4

Tokens: INTEGER(2) PLUS INTEGER(3) STAR INTEGER(4)

Proceso:
1. left = 2
2. op = PLUS (prec 5), right = parseExpression(6)
3. En parseExpression(6):
   - left = 3
   - op = STAR (prec 6 >= 6), right = 4
   - Retorna BinaryExpr(3 * 4)
4. Retorna BinaryExpr(2 + (3 * 4))

AST Resultante:
       +
      / \
     2   *
        / \
       3   4
```

### parsePrimary()

Parsea expresiones primarias (literales, identificadores, parentesis).

```mermaid
flowchart TD
    A[parsePrimary] --> B{current_token.type}

    B -->|INTEGER| C[Parsear entero]
    B -->|FLOAT| D[Parsear decimal]
    B -->|STRING| E[Parsear string]
    B -->|TRUE/FALSE| F[Parsear booleano]
    B -->|IDENTIFIER| G{peek == LPAREN?}
    B -->|LPAREN| H[Expresion entre parentesis]
    B -->|MINUS| I[Expresion unaria negativa]
    B -->|Otro| J[Error: ExpectedExpression]

    G -->|Si| K[Parsear llamada a funcion]
    G -->|No| L[Retornar identificador]

    C --> M[Expr.integer]
    D --> N[Expr.float]
    E --> O[Expr.string]
    F --> P[Expr.boolean]
    K --> Q[Expr.call]
    L --> R[Expr.identifier]
    H --> S[parseExpression recursivo]
    I --> T[Expr.unary]

    style A fill:#4a90e2
    style J fill:#d0021b
```

## Parsing de Estructuras de Control

### If Statement

```mermaid
flowchart TD
    A[parseIfStatement] --> B[nextToken - consume IF]
    B --> C[condition = parseExpression]
    C --> D{current == LBRACE?}
    D -->|No| E[Error]
    D -->|Si| F[nextToken - consume LBRACE]
    F --> G[then_block = parseBlock]
    G --> H{peek == ELSE?}
    H -->|No| I[nextToken - consume RBRACE]
    H -->|Si| J[nextToken - consume RBRACE]
    J --> K[nextToken - consume ELSE]
    K --> L{current == IF?}
    L -->|Si| M[else if - parseIfStatement recursivo]
    L -->|No| N{current == LBRACE?}
    N -->|Si| O[else block - parseBlock]
    N -->|No| E

    I --> P[Retornar IfStmt]
    M --> P
    O --> Q[nextToken - consume RBRACE]
    Q --> P

    style A fill:#4a90e2
    style P fill:#7ed321
    style E fill:#d0021b
```

**Gramatica**:
```
if_stmt := 'if' expression '{' block '}' ('else' (if_stmt | '{' block '}'))?
```

**Soporte para else-if**: El parser maneja `else if` recursivamente como un nuevo if statement dentro del else block.

### While Statement

```mermaid
flowchart TD
    A[parseWhileStatement] --> B[nextToken - consume WHILE]
    B --> C[condition = parseExpression]
    C --> D{current == LBRACE?}
    D -->|No| E[Error]
    D -->|Si| F[nextToken - consume LBRACE]
    F --> G[body = parseBlock]
    G --> H[nextToken - consume RBRACE]
    H --> I[Retornar WhileStmt]

    style A fill:#4a90e2
    style I fill:#7ed321
    style E fill:#d0021b
```

**Gramatica**:
```
while_stmt := 'while' expression '{' block '}'
```

### For Statement

```mermaid
flowchart TD
    A[parseForStatement] --> B[nextToken - consume FOR]
    B --> C{Declaracion o Statement?}
    C -->|IDENTIFIER : TYPE| D[Declaracion inline]
    C -->|Otro| E[Statement normal]

    D --> F[Parsear nombre, tipo, valor]
    E --> G[init = parseStatement]

    F --> H[condition = parseExpression]
    G --> H
    H --> I{current == SEMICOLON?}
    I -->|No| J[Error]
    I -->|Si| K[nextToken]
    K --> L[Parsear update assignment]
    L --> M{current == LBRACE?}
    M -->|No| J
    M -->|Si| N[nextToken - consume LBRACE]
    N --> O[body = parseBlock]
    O --> P[nextToken - consume RBRACE]
    P --> Q[Retornar ForStmt]

    style A fill:#4a90e2
    style Q fill:#7ed321
    style J fill:#d0021b
```

**Gramatica**:
```
for_stmt := 'for' (variable_decl | statement) expression ';' assignment '{' block '}'
```

**Caracteristica especial**: Permite declaracion de variable inline sin `make`:
```boemia
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}
```

## Parsing de Funciones

### Declaracion de Funcion

```mermaid
sequenceDiagram
    participant P as Parser

    P->>P: Consume FN
    P->>P: Obtener nombre
    P->>P: expectToken(LPAREN)

    loop Cada parametro
        P->>P: Parsear nombre: tipo
        P->>P: Agregar a params
        alt Hay coma
            P->>P: Consume COMMA
        end
    end

    P->>P: expectToken(RPAREN)
    P->>P: expectToken(COLON)
    P->>P: Parsear return_type
    P->>P: expectToken(LBRACE)
    P->>P: body = parseBlock
    P->>P: Consume RBRACE
    P->>P: Retornar FunctionDecl
```

**Gramatica**:
```
function_decl := 'fn' IDENTIFIER '(' params ')' ':' TYPE '{' block '}'
params := (IDENTIFIER ':' TYPE (',' IDENTIFIER ':' TYPE)*)?
```

### Llamada a Funcion

```mermaid
flowchart TD
    A[En parsePrimary] --> B{current == IDENTIFIER?}
    B -->|Si| C{peek == LPAREN?}
    C -->|Si| D[Es llamada a funcion]
    C -->|No| E[Es identificador simple]

    D --> F[nextToken - consume LPAREN]
    F --> G{current != RPAREN?}
    G -->|Si| H[arg = parseExpression]
    H --> I[Agregar arg a lista]
    I --> J{current == COMMA?}
    J -->|Si| K[nextToken - consume COMMA]
    K --> G
    J -->|No| G
    G -->|No| L[expectToken RPAREN]
    L --> M[Retornar CallExpr]

    E --> N[Retornar Identifier]

    style A fill:#4a90e2
    style M fill:#7ed321
    style N fill:#7ed321
```

**Gramatica**:
```
call_expr := IDENTIFIER '(' (expression (',' expression)*)? ')'
```

## Manejo de Errores

### Estrategia de Recuperacion

```mermaid
flowchart TD
    A[Error detectado] --> B[Registrar mensaje de error]
    B --> C[Agregar a lista de errores]
    C --> D{Tipo de error}

    D -->|ParseError en Statement| E[Buscar siguiente SEMICOLON]
    D -->|ParseError en Expression| F[Retornar error]
    D -->|UnexpectedToken| G[Descripcion detallada]

    E --> H{Encontrado SEMICOLON?}
    H -->|Si| I[nextToken - consume SEMICOLON]
    H -->|No| J{Encontrado EOF?}

    I --> K[Continuar parsing]
    J -->|Si| L[Terminar parsing]
    J -->|No| E

    style A fill:#d0021b
    style K fill:#f5a623
    style L fill:#7ed321
```

### expectToken()

Funcion auxiliar para verificar y consumir tokens esperados:

```mermaid
flowchart TD
    A[expectToken type] --> B{peek_token.type == type?}
    B -->|No| C[Crear mensaje de error]
    C --> D[Agregar a errors]
    D --> E[Retornar UnexpectedToken]
    B -->|Si| F[nextToken - avanzar]
    F --> G[Retornar void]

    style A fill:#4a90e2
    style E fill:#d0021b
    style G fill:#7ed321
```

**Ejemplo de Mensaje de Error**:
```
Expected SEMICOLON, got RBRACE at 5:12
```

## Construccion del AST

### Ejemplo Completo

**Codigo Fuente**:
```boemia
let x: int = 10;
if x > 5 {
    print(x);
}
```

**AST Generado**:
```
Program {
    statements: [
        Stmt.variable_decl {
            name: "x"
            data_type: INT
            value: Expr.integer(10)
            is_const: false
        },
        Stmt.if_stmt {
            condition: Expr.binary {
                left: Expr.identifier("x")
                operator: GT
                right: Expr.integer(5)
            }
            then_block: [
                Stmt.print_stmt {
                    expr: Expr.identifier("x")
                }
            ]
            else_block: null
        }
    ]
}
```

**Visualizacion del AST**:
```mermaid
graph TD
    A[Program] --> B[VariableDecl]
    A --> C[IfStmt]

    B --> D[name: x]
    B --> E[type: INT]
    B --> F[value: Expr]

    F --> G[integer: 10]

    C --> H[condition: BinaryExpr]
    C --> I[then_block]
    C --> J[else_block: null]

    H --> K[left: identifier x]
    H --> L[op: GT]
    H --> M[right: integer 5]

    I --> N[PrintStmt]
    N --> O[expr: identifier x]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#f5a623
```

## Optimizaciones del Parser

### Allocacion Eficiente

```mermaid
graph TB
    A[Parser] --> B[Allocator]
    B --> C[Crea nodos AST]
    B --> D[Lista de errores]

    C --> E[BinaryExpr*]
    C --> F[IfStmt*]
    C --> G[ForStmt*]

    E --> H[Almacenados en heap]
    F --> H
    G --> H

    H --> I[Liberados por Program.deinit]

    style A fill:#4a90e2
    style B fill:#f5a623
    style I fill:#7ed321
```

Solo los nodos que contienen otros nodos se almacenan en heap usando punteros. Los nodos simples se almacenan inline en el union.

### Sin Backtracking

El parser nunca retrocede. Toma decisiones basadas en:
- current_token
- peek_token (lookahead de 1)

Esto hace el parsing O(n) donde n es el numero de tokens.

## Tabla de Gramatica Completa

| Regla | Produccion |
|-------|------------|
| program | statement* |
| statement | variable_decl \| assignment \| if_stmt \| while_stmt \| for_stmt \| return_stmt \| print_stmt \| function_decl \| expr_stmt \| block |
| variable_decl | ('make' \| 'seal') IDENTIFIER ':' TYPE '=' expression ';' |
| assignment | IDENTIFIER '=' expression ';' |
| if_stmt | 'if' expression '{' block '}' ('else' (if_stmt \| '{' block '}'))? |
| while_stmt | 'while' expression '{' block '}' |
| for_stmt | 'for' init_stmt expression ';' update_stmt '{' block '}' |
| return_stmt | 'return' expression? ';' |
| print_stmt | 'print' '(' expression ')' ';' |
| function_decl | 'fn' IDENTIFIER '(' params ')' ':' TYPE '{' block '}' |
| block | statement* |
| expr_stmt | expression ';' |
| expression | primary (infix_op expression)* |
| primary | INTEGER \| FLOAT \| STRING \| TRUE \| FALSE \| IDENTIFIER \| call_expr \| '(' expression ')' \| '-' primary |
| call_expr | IDENTIFIER '(' args ')' |

## Testing del Parser

```mermaid
graph TB
    A[Parser Tests] --> B[Test Declaraciones]
    A --> C[Test Expresiones]
    A --> D[Test Control de Flujo]
    A --> E[Test Funciones]
    A --> F[Test Precedencia]
    A --> G[Test Errores]

    B --> B1[Variables]
    B --> B2[Constantes]

    C --> C1[Literales]
    C --> C2[Binarias]
    C --> C3[Unarias]
    C --> C4[Llamadas]

    D --> D1[If/Else]
    D --> D2[While]
    D --> D3[For]

    F --> F1[Aritmetica]
    F --> F2[Comparacion]
    F --> F3[Mixta]

    G --> G1[Tokens inesperados]
    G --> G2[Tipos invalidos]
    G --> G3[Recuperacion]

    style A fill:#4a90e2
```

## Performance del Parser

| Operacion | Complejidad |
|-----------|-------------|
| parseProgram() | O(n) |
| parseStatement() | O(1) |
| parseExpression() | O(m) donde m = complejidad expresion |
| parsePrimary() | O(1) |
| expectToken() | O(1) |
| **Total** | **O(n)** lineal en tokens |

## Integracion con Otras Fases

```mermaid
sequenceDiagram
    participant L as Lexer
    participant P as Parser
    participant A as Analyzer

    P->>L: nextToken()
    L-->>P: Token

    loop Para cada token
        P->>L: nextToken()
        L-->>P: Token
        P->>P: Construir AST
    end

    P-->>A: Program (AST)
    A->>A: Analizar semantica
```

## Proximos Pasos

Una vez construido el AST, el [Analyzer](06-ANALYZER.md) verifica la correccion semantica del programa.

## Referencias

- [AST Structure](13-AST-STRUCTURE.md) - Estructura detallada del AST
- [Error Handling](14-ERROR-HANDLING.md) - Manejo de errores en detalle
- [Type System](09-TYPE-SYSTEM.md) - Sistema de tipos
