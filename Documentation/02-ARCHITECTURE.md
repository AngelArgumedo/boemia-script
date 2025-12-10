# Arquitectura del Compilador Boemia Script

## Introduccion

El compilador de Boemia Script sigue una arquitectura clasica de compilador en multiples fases, separando claramente las responsabilidades entre el frontend (analisis) y el backend (generacion de codigo).

## Vision General de la Arquitectura

```mermaid
graph TB
    subgraph CLI["Interfaz de Linea de Comandos"]
        A[main.zig]
    end

    subgraph Frontend["Frontend - Analisis"]
        B[Lexer<br/>lexer.zig]
        C[Parser<br/>parser.zig]
        D[Analyzer<br/>analyzer.zig]
    end

    subgraph Core["Representaciones Centrales"]
        E[Tokens<br/>token.zig]
        F[AST<br/>ast.zig]
    end

    subgraph Backend["Backend - Generacion"]
        G[Code Generator<br/>codegen.zig]
    end

    subgraph External["Herramientas Externas"]
        H[GCC/Clang]
    end

    subgraph Output["Salida"]
        I[Ejecutable Binario]
    end

    A --> B
    B --> E
    E --> C
    C --> F
    F --> D
    D --> G
    G --> H
    H --> I

    style CLI fill:#e3f2fd
    style Frontend fill:#fff3e0
    style Core fill:#f3e5f5
    style Backend fill:#e8f5e9
    style External fill:#ffccbc
    style Output fill:#c8e6c9
```

## Componentes Principales

### 1. CLI - Interfaz de Usuario (main.zig)

Responsabilidades:
- Procesamiento de argumentos de linea de comandos
- Lectura de archivos fuente
- Coordinacion de las fases de compilacion
- Manejo de errores globales
- Presentacion de resultados al usuario

```mermaid
flowchart TD
    A[Inicio] --> B{Argumentos validos?}
    B -->|No| C[Mostrar uso]
    B -->|Si| D[Leer archivo .bs]
    D --> E{Lectura exitosa?}
    E -->|No| F[Error de lectura]
    E -->|Si| G[Iniciar Lexer]
    G --> H[Iniciar Parser]
    H --> I{Parsing exitoso?}
    I -->|No| J[Mostrar errores]
    I -->|Si| K[Iniciar Analyzer]
    K --> L{Analisis exitoso?}
    L -->|No| M[Mostrar errores semanticos]
    L -->|Si| N[Generar codigo C]
    N --> O[Compilar con GCC]
    O --> P{Compilacion exitosa?}
    P -->|No| Q[Error de compilacion]
    P -->|Si| R[Exito]

    style A fill:#4a90e2
    style R fill:#7ed321
    style C fill:#d0021b
    style F fill:#d0021b
    style J fill:#d0021b
    style M fill:#d0021b
    style Q fill:#d0021b
```

### 2. Representaciones Centrales

#### Tokens (token.zig)

Define todos los tipos de tokens que el lenguaje reconoce.

```mermaid
graph TB
    A[TokenType] --> B[Literales]
    A --> C[Identificadores]
    A --> D[Palabras Reservadas]
    A --> E[Operadores]
    A --> F[Delimitadores]
    A --> G[Especiales]

    B --> B1[INTEGER]
    B --> B2[FLOAT]
    B --> B3[STRING]
    B --> B4[TRUE/FALSE]

    C --> C1[IDENTIFIER]

    D --> D1[MAKE/SEAL]
    D --> D2[FN/RETURN]
    D --> D3[IF/ELSE]
    D --> D4[WHILE/FOR]

    E --> E1[PLUS/MINUS]
    E --> E2[STAR/SLASH]
    E --> E3[EQ/NEQ]
    E --> E4[LT/GT/LTE/GTE]

    F --> F1[LPAREN/RPAREN]
    F --> F2[LBRACE/RBRACE]
    F --> F3[SEMICOLON/COLON]

    G --> G1[EOF]
    G --> G2[ILLEGAL]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#f5a623
    style D fill:#bd10e0
    style E fill:#50e3c2
    style F fill:#f8e71c
    style G fill:#d0021b
```

#### AST (ast.zig)

Define la estructura del arbol de sintaxis abstracta.

```mermaid
classDiagram
    class Program {
        +statements: []Stmt
        +allocator: Allocator
        +init()
        +deinit()
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

    class DataType {
        <<enum>>
        INT
        FLOAT
        STRING
        BOOL
        VOID
    }

    Program --> Stmt
    Stmt --> Expr
    Stmt --> DataType
    Expr --> BinaryOp
    Expr --> UnaryOp

    class BinaryOp {
        <<enum>>
        ADD
        SUB
        MUL
        DIV
        EQ
        NEQ
        LT
        GT
        LTE
        GTE
    }

    class UnaryOp {
        <<enum>>
        NEG
        NOT
    }
```

### 3. Frontend - Fases de Analisis

#### Lexer (lexer.zig)

**Responsabilidad**: Convertir el codigo fuente en una secuencia de tokens.

**Estructura de Datos Principal**:

```mermaid
classDiagram
    class Lexer {
        -source: []const u8
        -position: usize
        -read_position: usize
        -ch: u8
        -line: usize
        -column: usize
        -allocator: Allocator
        +init()
        +nextToken()
        -readChar()
        -peekChar()
        -skipWhitespace()
        -skipComment()
        -readIdentifier()
        -readNumber()
        -readString()
    }
```

**Algoritmo de Tokenizacion**:

```mermaid
flowchart TD
    A[nextToken] --> B[skipWhitespace]
    B --> C[skipComment]
    C --> D{Tipo de caracter?}
    D -->|Operador| E[Retornar token operador]
    D -->|Delimitador| F[Retornar token delimitador]
    D -->|Letra| G[readIdentifier]
    D -->|Digito| H[readNumber]
    D -->|Comilla| I[readString]
    D -->|EOF| J[Retornar EOF]
    D -->|Otro| K[Retornar ILLEGAL]

    G --> L{Es keyword?}
    L -->|Si| M[Retornar keyword]
    L -->|No| N[Retornar IDENTIFIER]

    H --> O{Tiene punto?}
    O -->|Si| P[Retornar FLOAT]
    O -->|No| Q[Retornar INTEGER]

    I --> R{String cerrado?}
    R -->|Si| S[Retornar STRING]
    R -->|No| T[Retornar ILLEGAL]
```

#### Parser (parser.zig)

**Responsabilidad**: Construir el AST a partir de la secuencia de tokens.

**Estructura de Datos Principal**:

```mermaid
classDiagram
    class Parser {
        -lexer: *Lexer
        -current_token: Token
        -peek_token: Token
        -allocator: Allocator
        -errors: ArrayList
        +init()
        +deinit()
        +parseProgram()
        -parseStatement()
        -parseExpression()
        -parsePrimary()
        -nextToken()
        -expectToken()
    }
```

**Estrategia de Parsing**: Descendente Recursivo (Recursive Descent)

**Precedencia de Operadores**:

```mermaid
graph TB
    A[Precedencia] --> B[Nivel 6: *, /]
    B --> C[Nivel 5: +, -]
    C --> D[Nivel 4: <, >, <=, >=]
    D --> E[Nivel 3: ==, !=]

    style B fill:#d0021b
    style C fill:#f5a623
    style D fill:#f8e71c
    style E fill:#7ed321
```

#### Analyzer (analyzer.zig)

**Responsabilidad**: Verificar la correccion semantica del programa.

**Estructura de Datos Principal**:

```mermaid
classDiagram
    class Analyzer {
        -allocator: Allocator
        -symbol_table: HashMap
        -errors: ArrayList
        +init()
        +deinit()
        +analyze()
        -analyzeStmt()
        -checkExpr()
    }

    class Symbol {
        +data_type: DataType
        +is_const: bool
    }

    Analyzer --> Symbol
```

**Verificaciones Realizadas**:

```mermaid
flowchart TD
    A[Analisis Semantico] --> B[Verificacion de Tipos]
    A --> C[Verificacion de Variables]
    A --> D[Verificacion de Constantes]

    B --> B1[Tipos compatibles en asignaciones]
    B --> B2[Tipos compatibles en operaciones]
    B --> B3[Condiciones booleanas]

    C --> C1[Variables declaradas antes de uso]
    C --> C2[No redeclaracion de variables]

    D --> D1[No asignacion a constantes]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#f5a623
    style D fill:#bd10e0
```

### 4. Backend - Generacion de Codigo

#### Code Generator (codegen.zig)

**Responsabilidad**: Convertir el AST en codigo C valido.

**Estructura de Datos Principal**:

```mermaid
classDiagram
    class CodeGenerator {
        -allocator: Allocator
        -output: ArrayList~u8~
        -indent_level: usize
        -string_literals: ArrayList
        -variable_types: HashMap
        +init()
        +deinit()
        +generate()
        -generateStmt()
        -generateExpr()
        -generatePrint()
        -writeHeaders()
        -mapType()
        -mapBinaryOp()
    }
```

**Proceso de Generacion**:

```mermaid
flowchart LR
    A[AST] --> B[Generar Headers C]
    B --> C[Generar main]
    C --> D{Para cada Statement}
    D --> E[Generar Statement]
    E --> D
    D --> F[Generar return 0]
    F --> G[Codigo C Completo]
    G --> H[Escribir a archivo .c]
    H --> I[Invocar GCC]
    I --> J[Ejecutable]

    style A fill:#f3e5f5
    style G fill:#e1f5fe
    style J fill:#c8e6c9
```

## Flujo de Datos Completo

```mermaid
sequenceDiagram
    participant U as Usuario
    participant M as main.zig
    participant L as Lexer
    participant P as Parser
    participant A as Analyzer
    participant C as CodeGen
    participant G as GCC

    U->>M: boemia-compiler programa.bs -o output
    M->>M: Leer archivo programa.bs
    M->>L: init(codigo_fuente)
    M->>P: init(lexer)

    loop Para cada token
        P->>L: nextToken()
        L-->>P: Token
    end

    P->>P: Construir AST
    P-->>M: Program (AST)

    M->>A: analyze(program)

    loop Para cada statement
        A->>A: Verificar tipos
        A->>A: Verificar variables
    end

    A-->>M: OK o Error

    M->>C: generate(program)

    loop Para cada statement
        C->>C: Generar codigo C
    end

    C-->>M: Codigo C
    M->>G: Compilar codigo C
    G-->>M: Ejecutable
    M->>U: Compilacion exitosa
```

## Manejo de Errores en Capas

```mermaid
graph TB
    A[Error en Lexer] --> E[Reportar error lexico]
    B[Error en Parser] --> F[Reportar error sintactico]
    C[Error en Analyzer] --> G[Reportar error semantico]
    D[Error en CodeGen] --> H[Reportar error de generacion]

    E --> I[Lista de errores]
    F --> I
    G --> I
    H --> I

    I --> J{Hay errores?}
    J -->|Si| K[Terminar compilacion]
    J -->|No| L[Continuar]

    style A fill:#ffebee
    style B fill:#fff3e0
    style C fill:#f3e5f5
    style D fill:#e8f5e9
    style K fill:#d0021b
    style L fill:#7ed321
```

## Patron de Diseno: Visitor

El compilador utiliza un patron similar a Visitor para recorrer el AST:

```mermaid
classDiagram
    class ASTWalker {
        <<interface>>
        +visitProgram()
        +visitStmt()
        +visitExpr()
    }

    class Analyzer {
        +analyzeStmt()
        +checkExpr()
    }

    class CodeGenerator {
        +generateStmt()
        +generateExpr()
    }

    ASTWalker <|-- Analyzer
    ASTWalker <|-- CodeGenerator
```

## Gestion de Memoria

```mermaid
flowchart TD
    A[main] --> B[Crear GPA]
    B --> C[Crear Lexer]
    B --> D[Crear Parser]
    B --> E[Crear Analyzer]
    B --> F[Crear CodeGen]

    C --> C1[No posee memoria]
    D --> D1[ArrayList de errores]
    E --> E1[HashMap de simbolos]
    E --> E2[ArrayList de errores]
    F --> F1[ArrayList de output]
    F --> F2[HashMap de tipos]

    D1 --> G[deinit]
    E1 --> G
    E2 --> G
    F1 --> G
    F2 --> G

    G --> H[GPA.deinit]

    style A fill:#4a90e2
    style G fill:#f5a623
    style H fill:#7ed321
```

## Decisiones de Arquitectura

### Por que Transpilacion a C?

1. **Simplicidad**: Mas facil de implementar y entender
2. **Portabilidad**: C se compila en cualquier plataforma
3. **Optimizacion**: GCC/Clang tienen optimizaciones maduras
4. **Debugging**: El codigo generado es legible

### Por que Zig para el Compilador?

1. **Control de memoria explicito**: Ideal para aprender
2. **Interop con C**: Sin overhead
3. **Sin runtime**: Binarios pequenos
4. **Seguridad**: Previene errores comunes

### Por que Parsing Descendente Recursivo?

1. **Simplicidad**: Facil de implementar y entender
2. **Legibilidad**: Codigo claro y mantenible
3. **Suficiente**: Adecuado para la gramatica de Boemia Script

## Metricas del Compilador

| Componente | Lineas de Codigo | Complejidad |
|------------|------------------|-------------|
| token.zig | ~180 | Baja |
| lexer.zig | ~430 | Media |
| ast.zig | ~254 | Media |
| parser.zig | ~545 | Alta |
| analyzer.zig | ~333 | Media |
| codegen.zig | ~446 | Media |
| main.zig | ~132 | Baja |
| **Total** | **~2320** | **Media** |

## Proximos Pasos

Para profundizar en cada componente:

1. [Pipeline de Compilacion](03-COMPILATION-PIPELINE.md) - Flujo detallado
2. [Lexer](04-LEXER.md) - Analisis lexico
3. [Parser](05-PARSER.md) - Analisis sintactico
4. [Analyzer](06-ANALYZER.md) - Analisis semantico
5. [CodeGen](07-CODEGEN.md) - Generacion de codigo
