# Estructuras de Control

## Introduccion

Las estructuras de control permiten alterar el flujo secuencial de ejecucion de un programa. Boemia Script soporta condicionales (if/else) y bucles (while, for).

## If Statement

### Sintaxis

```mermaid
flowchart TD
    A[if statement] --> B[if condition]
    B --> C[then block]
    C --> D{else?}
    D -->|Si| E[else block o else if]
    D -->|No| F[Fin]

    style A fill:#4a90e2
    style C fill:#7ed321
    style E fill:#f5a623
```

**Gramatica**:
```
if_stmt := 'if' expression '{' block '}' ('else' (if_stmt | '{' block '}'))?
```

**Sintaxis basica**:
```boemia
if condition {
    // codigo si verdadero
}
```

**Con else**:
```boemia
if condition {
    // codigo si verdadero
} else {
    // codigo si falso
}
```

**Else if (encadenado)**:
```boemia
if condition1 {
    // codigo si condition1 es verdadero
} else if condition2 {
    // codigo si condition2 es verdadero
} else {
    // codigo si ambas son falsas
}
```

### Ejemplos

**If simple**:
```boemia
make x: int = 10;

if x > 5 {
    print(x);
}
```

**If-else**:
```boemia
make edad: int = 18;

if edad >= 18 {
    print("Mayor de edad");
} else {
    print("Menor de edad");
}
```

**If-else if-else**:
```boemia
make nota: int = 85;

if nota >= 90 {
    print("A");
} else if nota >= 80 {
    print("B");
} else if nota >= 70 {
    print("C");
} else {
    print("F");
}
```

### Condiciones

Las condiciones deben ser expresiones de tipo `bool`:

```boemia
// Valido: comparaciones
if x > 5 { }
if x == y { }
if nombre != "Juan" { }

// Valido: literales booleanos
if true { }
if false { }

// Valido: variables booleanas
make activo: bool = true;
if activo { }

// Invalido: tipos no booleanos
if 5 { }           // Error: tipo int no es bool
if "texto" { }     // Error: tipo string no es bool
```

### AST del If Statement

```mermaid
classDiagram
    class IfStmt {
        +condition: Expr
        +then_block: []Stmt
        +else_block: ?[]Stmt
    }

    class Expr {
        <<union>>
        binary
        identifier
        boolean
    }

    class Stmt {
        <<union>>
    }

    IfStmt --> Expr
    IfStmt --> Stmt
```

### Parsing del If

```mermaid
sequenceDiagram
    participant P as Parser

    P->>P: Token IF encontrado
    P->>P: nextToken() - consume IF
    P->>P: parseExpression() - condicion
    P->>P: Verificar LBRACE
    P->>P: nextToken() - consume LBRACE
    P->>P: parseBlock() - then_block
    P->>P: Verificar peek == ELSE
    alt Hay ELSE
        P->>P: nextToken() - consume RBRACE
        P->>P: nextToken() - consume ELSE
        alt Siguiente es IF
            P->>P: parseIfStatement() recursivo
        else Siguiente es LBRACE
            P->>P: parseBlock() - else_block
        end
    end
    P->>P: Retornar IfStmt
```

### Generacion de Codigo C

```boemia
if x > 5 {
    print(x);
} else {
    print(0);
}
```

**C generado**:
```c
if ((x > 5)) {
    printf("%lld\n", (long long)x);
} else {
    printf("%lld\n", (long long)0);
}
```

## While Statement

### Sintaxis

```mermaid
flowchart LR
    A[while] --> B[condition]
    B --> C[body]
    C -->|Repetir| B
    C -->|condition false| D[Fin]

    style A fill:#4a90e2
    style C fill:#7ed321
```

**Gramatica**:
```
while_stmt := 'while' expression '{' block '}'
```

**Sintaxis basica**:
```boemia
while condition {
    // codigo que se repite
}
```

### Ejemplos

**While simple**:
```boemia
make i: int = 0;
while i < 10 {
    print(i);
    i = i + 1;
}
```

**While con condicion compleja**:
```boemia
make x: int = 100;
make y: int = 50;

while x > y {
    x = x - 10;
    print(x);
}
```

**While infinito (hasta break - futuro)**:
```boemia
// Actualmente no soportado - sin break/continue
while true {
    // se ejecuta infinitamente
}
```

### AST del While Statement

```mermaid
classDiagram
    class WhileStmt {
        +condition: Expr
        +body: []Stmt
    }

    class Expr {
        <<union>>
    }

    class Stmt {
        <<union>>
    }

    WhileStmt --> Expr
    WhileStmt --> Stmt
```

### Generacion de Codigo C

```boemia
make i: int = 0;
while i < 10 {
    print(i);
    i = i + 1;
}
```

**C generado**:
```c
long long i = 0;
while ((i < 10)) {
    printf("%lld\n", (long long)i);
    i = (i + 1);
}
```

## For Statement

### Sintaxis

```mermaid
flowchart TD
    A[for] --> B[init]
    B --> C[condition]
    C -->|true| D[body]
    D --> E[update]
    E --> C
    C -->|false| F[Fin]

    style A fill:#4a90e2
    style D fill:#7ed321
```

**Gramatica**:
```
for_stmt := 'for' init_stmt expression ';' update_stmt '{' block '}'
init_stmt := IDENTIFIER ':' TYPE '=' expression ';'
update_stmt := IDENTIFIER '=' expression
```

**Sintaxis basica**:
```boemia
for variable: tipo = inicio; condicion; actualizacion {
    // codigo del bucle
}
```

### Caracteristica Especial: Declaracion Inline

El for permite declarar la variable sin usar `make`:

```boemia
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}
// i no existe fuera del bucle
```

### Ejemplos

**For clasico**:
```boemia
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}
```

**For con paso diferente**:
```boemia
for i: int = 0; i < 100; i = i + 10 {
    print(i);  // 0, 10, 20, ..., 90
}
```

**For descendente**:
```boemia
for i: int = 10; i > 0; i = i - 1 {
    print(i);  // 10, 9, 8, ..., 1
}
```

**For con uso de variable declarada antes**:
```boemia
make contador: int = 0;
for i: int = 0; i < 5; i = i + 1 {
    contador = contador + i;
}
print(contador);  // 10 (0+1+2+3+4)
```

### AST del For Statement

```mermaid
classDiagram
    class ForStmt {
        +init: ?*Stmt
        +condition: Expr
        +update: ?*Stmt
        +body: []Stmt
    }

    class Stmt {
        <<union>>
        variable_decl
        assignment
    }

    class Expr {
        <<union>>
    }

    ForStmt --> Stmt
    ForStmt --> Expr
```

### Parsing del For

El for es mas complejo porque debe parsear:
1. Init: declaracion de variable inline
2. Condition: expresion booleana
3. Update: asignacion sin punto y coma
4. Body: bloque de statements

```mermaid
sequenceDiagram
    participant P as Parser

    P->>P: Token FOR encontrado
    P->>P: nextToken() - consume FOR

    alt Declaracion inline
        P->>P: Parsear nombre: tipo = valor;
        P->>P: Crear VariableDecl
    else Statement normal
        P->>P: parseStatement() - init
    end

    P->>P: parseExpression() - condition
    P->>P: Verificar SEMICOLON
    P->>P: nextToken() - consume SEMICOLON

    P->>P: Parsear nombre = valor - update
    P->>P: Crear Assignment

    P->>P: Verificar LBRACE
    P->>P: nextToken() - consume LBRACE
    P->>P: parseBlock() - body

    P->>P: Retornar ForStmt
```

### Generacion de Codigo C

```boemia
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}
```

**C generado**:
```c
for (long long i = 0; i < 10; i = (i + 1)) {
    printf("%lld\n", (long long)i);
}
```

**Nota**: La condicion se genera sin parentesis extra en el for C, pero las expresiones si se envuelven.

## Bloques

### Que es un Bloque?

Un bloque es una secuencia de statements encerrados entre llaves `{}`.

```mermaid
graph TB
    A[Bloque] --> B[Statement 1]
    A --> C[Statement 2]
    A --> D[Statement 3]
    A --> E[Statement N]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
```

**Sintaxis**:
```boemia
{
    make x: int = 5;
    print(x);
}
```

### Scope de Bloques

Variables declaradas en un bloque solo existen dentro de ese bloque:

```boemia
if true {
    make x: int = 5;
    print(x);  // OK: x existe aqui
}
print(x);  // Error: x no existe fuera del bloque
```

**Implementacion en Analyzer**:

```mermaid
sequenceDiagram
    participant A as Analyzer
    participant ST as Symbol Table

    Note over A: Entrar a bloque
    A->>ST: Guardar conteo inicial
    A->>A: Analizar statements del bloque
    A->>ST: Agregar variables nuevas

    Note over A: Salir de bloque
    A->>ST: Recolectar variables agregadas
    A->>ST: Remover todas las variables del bloque
    Note over A: Variables locales eliminadas
```

### Bloques Anidados

```boemia
if x > 0 {
    make a: int = 10;
    if y > 0 {
        make b: int = 20;
        print(a);  // OK: a existe en scope padre
        print(b);  // OK: b existe en scope actual
    }
    print(a);  // OK: a existe en este scope
    print(b);  // Error: b solo existia en bloque hijo
}
```

## Comparacion de Estructuras de Control

```mermaid
graph TB
    A[Estructuras de Control] --> B[If]
    A --> C[While]
    A --> D[For]

    B --> E[Ejecucion condicional<br/>una vez]
    C --> F[Repeticion con<br/>condicion]
    D --> G[Repeticion con<br/>contador]

    E --> H[Casos: validacion,<br/>alternativas]
    F --> I[Casos: hasta que<br/>condicion cambie]
    G --> J[Casos: numero fijo<br/>de iteraciones]

    style A fill:#4a90e2
```

| Estructura | Uso | Ejemplo |
|------------|-----|---------|
| `if` | Decision unica | Verificar edad, validar entrada |
| `while` | Repetir hasta condicion | Leer hasta EOF, esperar input |
| `for` | Repetir N veces | Iterar 0 a N, procesar elementos |

## Ejemplos Complejos

### Factorial con While

```boemia
make n: int = 5;
make factorial: int = 1;
make i: int = 1;

while i <= n {
    factorial = factorial * i;
    i = i + 1;
}
print(factorial);  // 120
```

### Fibonacci con For

```boemia
make n: int = 10;
make a: int = 0;
make b: int = 1;

print(a);
print(b);

for i: int = 2; i < n; i = i + 1 {
    make temp: int = a + b;
    print(temp);
    a = b;
    b = temp;
}
```

### Numero Primo con If y While

```boemia
make numero: int = 17;
make es_primo: bool = true;
make divisor: int = 2;

if numero < 2 {
    es_primo = false;
} else {
    while divisor * divisor <= numero {
        if numero / divisor * divisor == numero {
            es_primo = false;
        }
        divisor = divisor + 1;
    }
}

if es_primo {
    print("Es primo");
} else {
    print("No es primo");
}
```

## Limitaciones Actuales

```mermaid
graph TB
    A[Limitaciones] --> B[Sin break/continue]
    A --> C[Sin switch/case]
    A --> D[Sin do-while]
    A --> E[Sin operador ternario]

    style A fill:#d0021b
    style B fill:#f5a623
    style C fill:#f5a623
    style D fill:#f5a623
    style E fill:#f5a623
```

### Break y Continue (Futuro)

```boemia
// Futuro: break
for i: int = 0; i < 100; i = i + 1 {
    if i == 50 {
        break;  // Salir del bucle
    }
    print(i);
}

// Futuro: continue
for i: int = 0; i < 10; i = i + 1 {
    if i == 5 {
        continue;  // Saltar esta iteracion
    }
    print(i);  // No imprime 5
}
```

### Switch/Case (Futuro)

```boemia
// Futuro: switch
make opcion: int = 2;

switch opcion {
    case 1:
        print("Opcion uno");
    case 2:
        print("Opcion dos");
    case 3:
        print("Opcion tres");
    default:
        print("Opcion desconocida");
}
```

### Operador Ternario (Futuro)

```boemia
// Futuro: operador ternario
make resultado: int = x > 5 ? 10 : 20;
```

## Mejores Practicas

### 1. Condiciones Claras

```boemia
// Bueno: condicion clara
if edad >= 18 {
    // ...
}

// Malo: condicion compleja sin explicacion
if x > 5 && y < 10 || z == 20 {
    // difcil de entender
}
```

### 2. Evitar Bucles Infinitos

```boemia
// Bueno: condicion que eventualmente sera falsa
make i: int = 0;
while i < 10 {
    print(i);
    i = i + 1;  // i eventualmente sera >= 10
}

// Malo: sin actualizacion, bucle infinito
make j: int = 0;
while j < 10 {
    print(j);
    // falta: j = j + 1
}
```

### 3. Usar For para Contadores

```boemia
// Bueno: usar for para contadores conocidos
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}

// Funciona pero verboso: while para contador
make i: int = 0;
while i < 10 {
    print(i);
    i = i + 1;
}
```

## Testing de Estructuras de Control

```mermaid
graph TB
    A[Tests] --> B[If Tests]
    A --> C[While Tests]
    A --> D[For Tests]

    B --> B1[If simple]
    B --> B2[If-else]
    B --> B3[Else-if anidado]
    B --> B4[Scope de variables]

    C --> C1[While con contador]
    C --> C2[While con condicion]
    C --> C3[While anidado]

    D --> D1[For basico]
    D --> D2[For con paso]
    D --> D3[For anidado]
    D --> D4[Scope de variable]

    style A fill:#4a90e2
```

## Referencias

- [Syntax](10-SYNTAX.md) - Sintaxis completa del lenguaje
- [Functions and Scope](12-FUNCTIONS-SCOPE.md) - Funciones y scope
- [Examples](17-EXAMPLES.md) - Ejemplos de codigo
