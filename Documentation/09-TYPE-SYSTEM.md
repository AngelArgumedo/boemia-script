# Sistema de Tipos

## Introduccion

El sistema de tipos de Boemia Script es estatico, fuertemente tipado y explicito. Cada variable debe declararse con un tipo que se verifica en tiempo de compilacion.

## Filosofia del Sistema de Tipos

```mermaid
graph TB
    A[Principios del Sistema de Tipos] --> B[Estatico]
    A --> C[Fuertemente Tipado]
    A --> D[Explicito]
    A --> E[Simple]

    B --> F[Tipos verificados<br/>en compilacion]
    C --> G[Sin conversiones<br/>implicitas peligrosas]
    D --> H[Tipos declarados<br/>explicitamente]
    E --> I[Solo tipos basicos<br/>necesarios]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
```

## Tipos de Datos

```mermaid
classDiagram
    class DataType {
        <<enumeration>>
        INT
        FLOAT
        STRING
        BOOL
        VOID
        +fromString(s) DataType
        +toString() string
    }

    class Symbol {
        data_type: DataType
        is_const: bool
    }

    Symbol --> DataType
```

### Tipos Primitivos

| Tipo | Descripcion | Tamano | Valores | Uso |
|------|-------------|--------|---------|-----|
| `int` | Entero con signo | 64 bits | -2^63 a 2^63-1 | Numeros enteros, contadores |
| `float` | Punto flotante | 64 bits | IEEE 754 double | Numeros decimales, cientificos |
| `string` | Cadena de texto | Variable | Secuencia de chars | Texto, mensajes |
| `bool` | Booleano | 1 byte | true, false | Condiciones, flags |
| `void` | Sin valor | 0 | - | Funciones sin retorno |

### Representacion en Memoria

```mermaid
graph TB
    A[Tipos en Memoria] --> B[int: 8 bytes]
    A --> C[float: 8 bytes]
    A --> D[string: Puntero 8 bytes]
    A --> E[bool: 1 byte]

    B --> F[long long en C]
    C --> G[double en C]
    D --> H[char* en C]
    E --> I[bool en C]

    style A fill:#4a90e2
```

## Declaracion de Tipos

### Sintaxis de Declaracion

```mermaid
flowchart TD
    A[Declaracion] --> B[make/seal]
    B --> C[nombre]
    C --> D[:]
    D --> E[tipo]
    E --> F[=]
    F --> G[valor]
    G --> H[;]

    style A fill:#4a90e2
    style E fill:#f5a623
```

**Ejemplos**:
```boemia
let x: int = 42;
let pi: float = 3.14159;
let nombre: string = "Boemia";
let activo: bool = true;
const CONSTANTE: int = 100;
```

### Tipo Explicito vs Inferido

**Actual (Explicito)**:
```boemia
let x: int = 5;  // Tipo debe declararse
```

**Futuro (Inferencia)**:
```boemia
make x = 5;  // Tipo inferido como int
```

## Verificacion de Tipos

```mermaid
sequenceDiagram
    participant P as Parser
    participant A as Analyzer
    participant ST as Symbol Table

    P->>A: VariableDecl(name, type, value)
    A->>A: checkExpr(value)
    A->>A: Obtener tipo de expresion
    alt Tipos compatibles
        A->>ST: Agregar simbolo
        A-->>P: OK
    else Tipos incompatibles
        A-->>P: Error: TypeMismatch
    end
```

### Reglas de Compatibilidad

```mermaid
graph TB
    A[Compatibilidad de Tipos] --> B[Identicos]
    A --> C[Promocion]
    A --> D[Incompatibles]

    B --> E[int = int<br/>float = float<br/>string = string]
    C --> F[int + float = float]
    D --> G[int != string<br/>bool != int]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#f5a623
    style D fill:#d0021b
```

## Operaciones por Tipo

### Operaciones Aritmeticas

```mermaid
graph TB
    A[Operaciones Aritmeticas] --> B[int + int]
    A --> C[float + float]
    A --> D[int + float]
    A --> E[string + string]

    B --> F[Resultado: int]
    C --> G[Resultado: float]
    D --> H[Resultado: float<br/>promocion]
    E --> I[Resultado: string<br/>concatenacion]

    style A fill:#4a90e2
    style F fill:#7ed321
    style G fill:#7ed321
    style H fill:#f5a623
    style I fill:#7ed321
```

**Tabla de Operaciones**:

| Operador | int | float | string | bool | Resultado |
|----------|-----|-------|--------|------|-----------|
| `+` | Si | Si | Si (concat) | No | Mismo tipo o float |
| `-` | Si | Si | No | No | Mismo tipo o float |
| `*` | Si | Si | No | No | Mismo tipo o float |
| `/` | Si | Si | No | No | Mismo tipo o float |

**Ejemplos**:
```boemia
let a: int = 5 + 3;           // int: 8
let b: float = 2.5 + 1.5;     // float: 4.0
let c: float = 5 + 2.5;       // float: 7.5 (promocion)
let d: string = "Hola" + " Mundo";  // string: "Hola Mundo"
```

### Operaciones de Comparacion

```mermaid
graph TB
    A[Operaciones de Comparacion] --> B[Tipos identicos]
    A --> C[Retorna bool]

    B --> D[int == int: OK]
    B --> E[float == float: OK]
    B --> F[string == string: OK]
    B --> G[int == float: ERROR]

    C --> H[Siempre bool]

    style A fill:#4a90e2
    style G fill:#d0021b
    style H fill:#7ed321
```

**Tabla de Comparaciones**:

| Operador | Operandos | Resultado | Notas |
|----------|-----------|-----------|-------|
| `==`, `!=` | Mismo tipo | bool | Igualdad/desigualdad |
| `<`, `>`, `<=`, `>=` | Mismo tipo numerico o string | bool | Ordenamiento |

**Ejemplos**:
```boemia
let x: int = 5;
let y: int = 10;
let resultado: bool = x < y;        // true
let igual: bool = x == 5;           // true
let diferente: bool = x != y;       // true

let nombre: string = "Ana";
let otro: string = "Zoe";
let orden: bool = nombre < otro;    // true (orden lexicografico)
```

### Operaciones Logicas

```mermaid
graph TB
    A[Operaciones Logicas] --> B[Solo bool]
    B --> C[Resultado: bool]

    C --> D[true && true: true]
    C --> E[true || false: true]
    C --> F[!true: false]

    style A fill:#4a90e2
    style C fill:#7ed321
```

**Nota actual**: Boemia actualmente no implementa `&&`, `||`, solo `!` (NOT).

**Mejora futura**: Agregar operadores logicos.

## Promocion de Tipos

```mermaid
flowchart TD
    A[Expresion Mixta] --> B{Tipos diferentes?}
    B -->|No| C[Usar tipo comun]
    B -->|Si| D{Uno es int, otro float?}
    D -->|Si| E[Promover a float]
    D -->|No| F[Error: TypeMismatch]

    style A fill:#4a90e2
    style C fill:#7ed321
    style E fill:#f5a623
    style F fill:#d0021b
```

**Regla de Promocion**: En operaciones aritmeticas, si un operando es `int` y el otro es `float`, el `int` se promueve a `float`.

### Ejemplos de Promocion

```boemia
let a: int = 5;
let b: float = 2.5;
let c: float = a + b;  // a promovido a float, resultado: 7.5

let x: int = 10;
let y: float = x / 3.0;  // x promovido a float, resultado: 3.333...
```

**Implementacion en el Analyzer**:
```zig
switch (bin.operator) {
    .ADD, .SUB, .MUL, .DIV => {
        if (left_type == .INT and right_type == .INT) {
            break :blk .INT;
        } else if (left_type == .FLOAT and right_type == .FLOAT) {
            break :blk .FLOAT;
        } else if ((left_type == .INT or left_type == .FLOAT) and
                   (right_type == .INT or right_type == .FLOAT)) {
            break :blk .FLOAT;  // Promocion
        }
        return AnalyzerError.InvalidOperation;
    },
}
```

## Constantes (seal)

```mermaid
graph TB
    A[seal vs make] --> B[seal - Inmutable]
    A --> C[make - Mutable]

    B --> D[No se puede reasignar]
    B --> E[Verificado en Analyzer]
    C --> F[Permite reasignacion]

    style A fill:#4a90e2
    style B fill:#f5a623
    style C fill:#7ed321
```

### Declaracion de Constantes

```boemia
const PI: float = 3.14159;
const MAX_SIZE: int = 1000;
const NOMBRE: string = "Boemia Script";
```

### Verificacion de Inmutabilidad

```mermaid
sequenceDiagram
    participant A as Analyzer
    participant ST as Symbol Table

    Note over A: Analizar assignment
    A->>ST: get(variable_name)
    ST-->>A: Symbol con is_const
    alt is_const == true
        A->>A: Error: ConstantAssignment
    else is_const == false
        A->>A: Verificar tipos
        A->>A: OK
    end
```

**Codigo de verificacion**:
```zig
const symbol = self.symbol_table.get(assign.name) orelse {
    return AnalyzerError.UndefinedVariable;
};

if (symbol.is_const) {
    const err = try std.fmt.allocPrint(
        self.allocator,
        "Cannot assign to constant '{s}'",
        .{assign.name},
    );
    try self.errors.append(self.allocator, err);
    return AnalyzerError.ConstantAssignment;
}
```

**Ejemplo de error**:
```boemia
const PI: float = 3.14;
PI = 3.15;  // Error: Cannot assign to constant 'PI'
```

## Tipo Void

```mermaid
graph TB
    A[void] --> B[Funciones sin retorno]
    A --> C[No puede asignarse]
    A --> D[No puede usarse en expresiones]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#d0021b
    style D fill:#d0021b
```

**Uso de void**:
```boemia
fn mostrarMensaje(texto: string): void {
    print(texto);
    // No retorna valor
}
```

**No valido**:
```boemia
make x: void = algo();  // Error: void no puede asignarse
```

## Coercion y Casting

### Estado Actual: Sin Coercion Implicita

```mermaid
graph LR
    A[Sin Coercion] --> B[Seguridad]
    A --> C[Claridad]
    A --> D[Sin sorpresas]

    B --> E[No hay conversiones<br/>inesperadas]
    C --> F[Intencion explicita]
    D --> G[Comportamiento predecible]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
```

**No permitido**:
```boemia
let x: int = 5;
let y: float = x;  // Error: TypeMismatch
```

### Mejora Futura: Casting Explicito

```boemia
let x: int = 5;
let y: float = float(x);  // Casting explicito

let z: int = int(3.14);   // z = 3
```

**Sintaxis propuesta**:
```
cast_expr := TYPE '(' expression ')'
```

## Tabla de Simbolos y Tipos

```mermaid
classDiagram
    class SymbolTable {
        -map: HashMap~string, Symbol~
        +put(name, symbol) void
        +get(name) Symbol?
        +remove(name) void
    }

    class Symbol {
        +data_type: DataType
        +is_const: bool
    }

    class DataType {
        <<enum>>
        INT
        FLOAT
        STRING
        BOOL
        VOID
    }

    SymbolTable --> Symbol
    Symbol --> DataType
```

### Ejemplo de Tabla de Simbolos

```boemia
let x: int = 5;
const PI: float = 3.14;
let nombre: string = "Hola";
```

**Tabla interna**:
```
Symbol Table:
  "x"      -> Symbol { data_type: INT,    is_const: false }
  "PI"     -> Symbol { data_type: FLOAT,  is_const: true  }
  "nombre" -> Symbol { data_type: STRING, is_const: false }
```

## Verificacion de Tipos en Expresiones

```mermaid
flowchart TD
    A[checkExpr] --> B{Tipo de Expresion}

    B -->|Literal| C[Retornar tipo directo]
    B -->|Identifier| D[Buscar en symbol table]
    B -->|Binary| E[Verificar operandos]
    B -->|Unary| F[Verificar operando]
    B -->|Call| G[Verificar funcion]

    C --> H[int, float, string, bool]
    D --> I{Existe variable?}
    I -->|Si| J[Retornar tipo de variable]
    I -->|No| K[Error: UndefinedVariable]

    E --> L[checkExpr left]
    E --> M[checkExpr right]
    L --> N{Tipos compatibles?}
    M --> N
    N -->|Si| O[Retornar tipo resultado]
    N -->|No| P[Error: TypeMismatch]

    style A fill:#4a90e2
    style H fill:#7ed321
    style J fill:#7ed321
    style O fill:#7ed321
    style K fill:#d0021b
    style P fill:#d0021b
```

### Inferencia de Tipos en Expresiones

```mermaid
sequenceDiagram
    participant A as Analyzer

    Note over A: Expresion: x + y * 2
    A->>A: checkExpr(x + y * 2)
    A->>A: checkExpr(x) -> INT
    A->>A: checkExpr(y * 2)
    A->>A: checkExpr(y) -> INT
    A->>A: checkExpr(2) -> INT
    A->>A: INT * INT -> INT
    A->>A: INT + INT -> INT
    Note over A: Resultado final: INT
```

## Errores de Tipos

```mermaid
graph TB
    A[Errores de Tipos] --> B[TypeMismatch]
    A --> C[UndefinedVariable]
    A --> D[InvalidOperation]
    A --> E[ConstantAssignment]

    B --> F[Tipos incompatibles<br/>en operacion/asignacion]
    C --> G[Variable no declarada]
    D --> H[Operacion no soportada<br/>para tipos dados]
    E --> I[Intento de modificar<br/>constante]

    style A fill:#d0021b
```

### Ejemplos de Errores

**TypeMismatch**:
```boemia
let x: int = "texto";
// Error: Type mismatch: cannot assign string to int

let a: int = 5;
let b: string = "10";
let c: int = a + b;
// Error: Invalid operation: int ADD string
```

**UndefinedVariable**:
```boemia
print(variable_no_declarada);
// Error: Undefined variable 'variable_no_declarada'
```

**InvalidOperation**:
```boemia
let texto: string = "Hola";
let numero: int = texto * 2;
// Error: Invalid operation: string MUL int
```

**ConstantAssignment**:
```boemia
const MAX: int = 100;
MAX = 200;
// Error: Cannot assign to constant 'MAX'
```

## Mejoras Futuras

```mermaid
graph TB
    A[Mejoras Futuras] --> B[Inferencia de Tipos]
    A --> C[Casting Explicito]
    A --> D[Tipos Compuestos]
    A --> E[Genericos]
    A --> F[Null Safety]

    B --> G[make x = 5<br/>infiere int]
    C --> H[int valor = float pi<br/>con cast]
    D --> I[Arrays, Structs,<br/>Tuples]
    E --> J[Funciones genericas]
    F --> K[Tipos opcionales<br/>int? puede ser null]

    style A fill:#4a90e2
```

### Inferencia de Tipos

```boemia
// Actual
let x: int = 5;

// Futuro
make x = 5;  // Tipo inferido: int
make y = 3.14;  // Tipo inferido: float
make z = "Hola";  // Tipo inferido: string
```

### Tipos Compuestos

```boemia
// Arrays
make numeros: []int = [1, 2, 3, 4, 5];

// Structs
struct Persona {
    nombre: string,
    edad: int
}

make juan: Persona = Persona{
    nombre: "Juan",
    edad: 30
};

// Tuples
make punto: (int, int) = (10, 20);
```

### Null Safety

```boemia
// Tipos opcionales
let nombre: string? = null;  // Puede ser string o null
let edad: int? = 25;

// Verificacion
if nombre != null {
    print(nombre);
}
```

## Comparacion con Otros Lenguajes

| Caracteristica | Boemia | Python | JavaScript | Rust | C |
|----------------|--------|--------|------------|------|---|
| Tipado | Estatico | Dinamico | Dinamico | Estatico | Estatico |
| Fuerza | Fuerte | Fuerte | Debil | Muy fuerte | Debil |
| Inferencia | No | Si | No | Si | No |
| Null safety | No | No | No | Si | No |
| Generics | No | Si | No | Si | No |

## Performance del Sistema de Tipos

| Operacion | Complejidad | Razon |
|-----------|-------------|-------|
| Buscar tipo de variable | O(1) | HashMap |
| Verificar compatibilidad | O(1) | Comparacion simple |
| Analizar expresion | O(n) | n = profundidad |
| Promocion de tipos | O(1) | Regla fija |

## Referencias

- [Analyzer](06-ANALYZER.md) - Analisis semantico y verificacion de tipos
- [AST Structure](13-AST-STRUCTURE.md) - Estructura del AST
- [Operators Reference](21-OPERATORS-REFERENCE.md) - Referencia de operadores
