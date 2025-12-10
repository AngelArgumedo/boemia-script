# Analisis Semantico - Analyzer

## Introduccion

El Analyzer (Analizador Semantico) es la tercera fase del compilador. Su responsabilidad es verificar que el programa sea semanticamente correcto, es decir, que tenga sentido mas alla de la sintaxis.

## Que es el Analisis Semantico?

Mientras el Parser verifica la sintaxis (estructura), el Analyzer verifica la semantica (significado):

- ¿Las variables estan declaradas antes de usarse?
- ¿Los tipos son compatibles en las operaciones?
- ¿Se asigna a constantes?
- ¿Las condiciones son booleanas?

### Ejemplo

```boemia
make x: int = "texto";  // Error semantico: tipo incompatible
seal PI: float = 3.14;
PI = 3.15;              // Error semantico: asignacion a constante
```

## Estructura del Analyzer

```mermaid
classDiagram
    class Analyzer {
        -allocator: Allocator
        -symbol_table: StringHashMap~Symbol~
        -errors: ArrayList~string~
        +init(allocator) Analyzer
        +deinit() void
        +analyze(program) void
        -analyzeStmt(stmt) DataType
        -checkExpr(expr) DataType
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

    Analyzer --> Symbol
    Symbol --> DataType
```

## Tabla de Simbolos

La tabla de simbolos es una estructura de datos que mapea nombres de variables a su informacion de tipo.

```mermaid
graph LR
    A[Symbol Table] --> B[x: Symbol]
    A --> C[y: Symbol]
    A --> D[PI: Symbol]

    B --> E[data_type: INT<br/>is_const: false]
    C --> F[data_type: FLOAT<br/>is_const: false]
    D --> G[data_type: FLOAT<br/>is_const: true]

    style A fill:#4a90e2
    style E fill:#7ed321
    style F fill:#7ed321
    style G fill:#f5a623
```

### Operaciones en la Tabla de Simbolos

| Operacion | Metodo | Complejidad |
|-----------|--------|-------------|
| Insertar simbolo | `put(name, symbol)` | O(1) promedio |
| Buscar simbolo | `get(name)` | O(1) promedio |
| Eliminar simbolo | `remove(name)` | O(1) promedio |
| Verificar existencia | `contains(name)` | O(1) promedio |

## Proceso de Analisis

```mermaid
flowchart TD
    A[analyze program] --> B{Para cada statement}
    B --> C[analyzeStmt]
    C --> D{Tipo de statement?}

    D -->|variable_decl| E[Verificar declaracion]
    D -->|assignment| F[Verificar asignacion]
    D -->|if_stmt| G[Verificar if]
    D -->|while_stmt| H[Verificar while]
    D -->|for_stmt| I[Verificar for]
    D -->|expr_stmt| J[checkExpr]
    D -->|print_stmt| J
    D -->|function_decl| K[Verificar funcion]

    E --> L[Agregar a symbol_table]
    F --> M[Verificar en symbol_table]
    G --> N[Verificar condicion bool]
    H --> N
    I --> N

    L --> B
    M --> B
    N --> B
    J --> B
    K --> B

    B -->|No hay mas| O[Analisis completo]

    style A fill:#4a90e2
    style O fill:#7ed321
```

## Verificaciones Principales

### 1. Declaracion de Variables

```mermaid
sequenceDiagram
    participant A as Analyzer
    participant S as Symbol Table

    A->>S: get(variable_name)
    alt Variable existe
        S-->>A: Symbol encontrado
        A->>A: Error: RedeclaredVariable
    else Variable no existe
        S-->>A: null
        A->>A: checkExpr(value)
        A->>A: Verificar tipos compatibles
        A->>S: put(name, Symbol)
    end
```

**Codigo**:
```zig
if (self.symbol_table.get(decl.name)) |_| {
    return AnalyzerError.RedeclaredVariable;
}

const expr_type = try self.checkExpr(&decl.value);

if (expr_type != decl.data_type) {
    return AnalyzerError.TypeMismatch;
}

try self.symbol_table.put(decl.name, Symbol{
    .data_type = decl.data_type,
    .is_const = decl.is_const,
});
```

**Errores detectados**:
- Redeclaracion de variable
- Tipo incompatible en inicializacion

### 2. Asignacion a Variables

```mermaid
flowchart TD
    A[Analizar assignment] --> B[Buscar variable en tabla]
    B --> C{Variable existe?}
    C -->|No| D[Error: UndefinedVariable]
    C -->|Si| E{Variable es constante?}
    E -->|Si| F[Error: ConstantAssignment]
    E -->|No| G[Verificar tipo de expresion]
    G --> H{Tipos compatibles?}
    H -->|No| I[Error: TypeMismatch]
    H -->|Si| J[Asignacion valida]

    style A fill:#4a90e2
    style J fill:#7ed321
    style D fill:#d0021b
    style F fill:#d0021b
    style I fill:#d0021b
```

**Codigo**:
```zig
const symbol = self.symbol_table.get(assign.name) orelse {
    return AnalyzerError.UndefinedVariable;
};

if (symbol.is_const) {
    return AnalyzerError.ConstantAssignment;
}

const expr_type = try self.checkExpr(&assign.value);
if (expr_type != symbol.data_type) {
    return AnalyzerError.TypeMismatch;
}
```

**Errores detectados**:
- Variable no declarada
- Asignacion a constante (seal)
- Tipo incompatible

### 3. Verificacion de Tipos en Expresiones

```mermaid
flowchart TD
    A[checkExpr] --> B{Tipo de expresion?}

    B -->|integer| C[Retornar INT]
    B -->|float| D[Retornar FLOAT]
    B -->|string| E[Retornar STRING]
    B -->|boolean| F[Retornar BOOL]
    B -->|identifier| G[Buscar en symbol_table]
    B -->|binary| H[Verificar operacion binaria]
    B -->|unary| I[Verificar operacion unaria]
    B -->|call| J[Verificar llamada funcion]

    G --> K{Existe variable?}
    K -->|No| L[Error: UndefinedVariable]
    K -->|Si| M[Retornar tipo de variable]

    H --> N[checkExpr left]
    H --> O[checkExpr right]
    N --> P[Verificar compatibilidad]
    O --> P

    style A fill:#4a90e2
    style L fill:#d0021b
```

**Ejemplo - Operacion Binaria**:
```zig
const left_type = try self.checkExpr(&bin.left);
const right_type = try self.checkExpr(&bin.right);

switch (bin.operator) {
    .ADD, .SUB, .MUL, .DIV => {
        if (left_type == .INT and right_type == .INT) {
            return .INT;
        } else if (left_type == .FLOAT and right_type == .FLOAT) {
            return .FLOAT;
        } else if ((left_type == .INT or left_type == .FLOAT) and
                   (right_type == .INT or right_type == .FLOAT)) {
            return .FLOAT;  // Promocion a float
        }
        return AnalyzerError.InvalidOperation;
    },
    .EQ, .NEQ, .LT, .GT, .LTE, .GTE => {
        if (left_type != right_type) {
            return AnalyzerError.TypeMismatch;
        }
        return .BOOL;
    },
}
```

### 4. Condiciones Booleanas

```mermaid
flowchart TD
    A[Verificar If/While/For] --> B[checkExpr condition]
    B --> C{Tipo == BOOL?}
    C -->|No| D[Error: TypeMismatch]
    C -->|Si| E[Analizar cuerpo]

    style A fill:#4a90e2
    style E fill:#7ed321
    style D fill:#d0021b
```

**Codigo**:
```zig
const cond_type = try self.checkExpr(&if_stmt.condition);
if (cond_type != .BOOL) {
    const err = try std.fmt.allocPrint(
        self.allocator,
        "If condition must be bool, got {s}",
        .{cond_type.toString()},
    );
    try self.errors.append(self.allocator, err);
    return AnalyzerError.TypeMismatch;
}
```

## Reglas de Tipos

### Operaciones Aritmeticas (+ - * /)

| Izquierda | Derecha | Resultado | Valido |
|-----------|---------|-----------|--------|
| INT | INT | INT | Si |
| FLOAT | FLOAT | FLOAT | Si |
| INT | FLOAT | FLOAT | Si (promocion) |
| FLOAT | INT | FLOAT | Si (promocion) |
| STRING | STRING | STRING | Solo para + (concatenacion) |
| Otros | Otros | - | No |

```mermaid
graph TB
    A[Operacion Aritmetica] --> B{Ambos INT?}
    B -->|Si| C[Resultado: INT]
    B -->|No| D{Ambos FLOAT?}
    D -->|Si| E[Resultado: FLOAT]
    D -->|No| F{Uno INT, otro FLOAT?}
    F -->|Si| G[Promocion a FLOAT]
    F -->|No| H{Operador + y ambos STRING?}
    H -->|Si| I[Concatenacion STRING]
    H -->|No| J[Error: InvalidOperation]

    style C fill:#7ed321
    style E fill:#7ed321
    style G fill:#f5a623
    style I fill:#7ed321
    style J fill:#d0021b
```

### Operaciones de Comparacion (== != < > <= >=)

| Izquierda | Derecha | Resultado | Valido |
|-----------|---------|-----------|--------|
| INT | INT | BOOL | Si |
| FLOAT | FLOAT | BOOL | Si |
| STRING | STRING | BOOL | Si |
| BOOL | BOOL | BOOL | Si |
| Tipos diferentes | - | - | No |

**Regla importante**: Los tipos deben ser identicos, no hay promocion.

### Operaciones Unarias

| Operador | Tipo Operando | Resultado | Valido |
|----------|---------------|-----------|--------|
| `-` (negacion) | INT | INT | Si |
| `-` (negacion) | FLOAT | FLOAT | Si |
| `-` (negacion) | Otros | - | No |
| `!` (not) | BOOL | BOOL | Si |
| `!` (not) | Otros | - | No |

## Scope y Bloques

El Analyzer maneja scopes para variables declaradas dentro de bloques.

```mermaid
sequenceDiagram
    participant A as Analyzer
    participant S as Symbol Table

    Note over A,S: Analizar if statement
    A->>S: Guardar conteo inicial

    loop Analizar then_block
        A->>A: analyzeStmt
        A->>S: Agregar variables
    end

    A->>S: Recolectar variables nuevas
    A->>S: Remover variables del then_block

    alt Hay else_block
        loop Analizar else_block
            A->>A: analyzeStmt
            A->>S: Agregar variables
        end
        A->>S: Remover variables del else_block
    end

    Note over A,S: Variables locales eliminadas
```

**Problema resuelto**: Variables declaradas en un bloque no escapan su scope.

```boemia
if true {
    make x: int = 5;
}
print(x);  // Error: x no existe fuera del if
```

**Implementacion**:
```zig
// Guardar conteo de simbolos antes del bloque
const then_vars_start_count = self.symbol_table.count();

// Analizar bloque
for (if_stmt.then_block) |*s| {
    try self.analyzeStmt(s);
}

// Recolectar variables agregadas
var then_vars: std.ArrayList([]const u8) = .empty;
var it = self.symbol_table.iterator();
var count: usize = 0;
while (it.next()) |entry| : (count += 1) {
    if (count >= then_vars_start_count) {
        try then_vars.append(self.allocator, entry.key_ptr.*);
    }
}

// Remover variables del bloque
for (then_vars.items) |var_name| {
    _ = self.symbol_table.remove(var_name);
}
```

## Manejo de Funciones

### Declaracion de Funcion

```mermaid
flowchart TD
    A[Analizar function_decl] --> B[Agregar parametros a symbol_table]
    B --> C{Para cada parametro}
    C --> D[put param_name, Symbol]
    D --> C
    C --> E{Para cada statement en body}
    E --> F[analyzeStmt]
    F --> E
    E --> G[Remover parametros del scope]
    G --> H[Funcion analizada]

    style A fill:#4a90e2
    style H fill:#7ed321
```

**Codigo**:
```zig
for (func.params) |param| {
    try self.symbol_table.put(param.name, Symbol{
        .data_type = param.data_type,
        .is_const = false,
    });
}

for (func.body) |*s| {
    try self.analyzeStmt(s);
}
```

### Llamada a Funcion

Actualmente simplificado, retorna VOID:
```zig
.call => |call| {
    _ = call;
    // Verificacion completa de tipos pendiente
    break :blk .VOID;
}
```

**Mejora futura**: Tabla de funciones con tipos de parametros y retorno.

## Errores del Analyzer

```mermaid
graph TB
    A[Analyzer Errors] --> B[UndefinedVariable]
    A --> C[TypeMismatch]
    A --> D[ConstantAssignment]
    A --> E[RedeclaredVariable]
    A --> F[InvalidOperation]

    B --> G[Variable usada sin declarar]
    C --> H[Tipos incompatibles en operacion]
    D --> I[Intento de modificar constante]
    E --> J[Variable declarada dos veces]
    F --> K[Operacion invalida para tipos]

    style A fill:#d0021b
    style B fill:#f5a623
    style C fill:#f5a623
    style D fill:#f5a623
    style E fill:#f5a623
    style F fill:#f5a623
```

### Ejemplos de Mensajes de Error

```
Error: Variable 'x' is already declared
Error: Type mismatch: cannot assign string to int
Error: Cannot assign to constant 'PI'
Error: Undefined variable 'y'
Error: If condition must be bool, got int
Error: Cannot compare int with string
Error: Invalid operation: string * int
```

## Flujo Completo del Analisis

```mermaid
sequenceDiagram
    participant M as main.zig
    participant A as Analyzer
    participant S as Symbol Table

    M->>A: init(allocator)
    A->>S: Crear tabla vacia
    M->>A: analyze(program)

    loop Para cada statement
        A->>A: analyzeStmt(stmt)
        alt Declaracion
            A->>S: Verificar no existe
            A->>A: checkExpr(value)
            A->>S: put(name, symbol)
        else Asignacion
            A->>S: Verificar existe
            A->>S: Verificar no es const
            A->>A: checkExpr(value)
        else Expresion
            A->>A: checkExpr(expr)
            A->>S: Buscar identificadores
        end
    end

    alt Hay errores
        A-->>M: Error con lista de mensajes
    else Sin errores
        A-->>M: OK
    end

    M->>A: deinit()
    A->>S: Limpiar tabla
```

## Tabla de Decisiones de Tipos

### Promocion de Tipos

```mermaid
graph LR
    A[INT] -->|En operacion con FLOAT| B[Promovido a FLOAT]
    C[FLOAT] -->|Sin cambios| C

    D[Operacion Mixta] --> E[int + float]
    E --> F[Resultado: float]

    style B fill:#f5a623
    style F fill:#f5a623
```

**Regla**: En operaciones aritmeticas mixtas (int y float), el resultado es float.

### Compatibilidad de Tipos

| Operacion | int | float | string | bool | void |
|-----------|-----|-------|--------|------|------|
| Aritmetica (+,-,*,/) | Si | Si | Solo + | No | No |
| Comparacion (==,!=) | Si | Si | Si | Si | No |
| Ordenamiento (<,>,<=,>=) | Si | Si | Si | No | No |
| Negacion (-) | Si | Si | No | No | No |
| Not (!) | No | No | No | Si | No |

## Optimizaciones

### Tabla de Hash Eficiente

```mermaid
graph TB
    A[StringHashMap] --> B[Hash Function]
    B --> C[Bucket Array]
    C --> D[Symbol Entry 1]
    C --> E[Symbol Entry 2]
    C --> F[Symbol Entry 3]

    D --> G[name: x<br/>type: INT<br/>const: false]
    E --> H[name: PI<br/>type: FLOAT<br/>const: true]
    F --> I[name: texto<br/>type: STRING<br/>const: false]

    style A fill:#4a90e2
    style B fill:#f5a623
```

**Ventajas**:
- Busqueda O(1) promedio
- Insercion O(1) promedio
- Eliminacion O(1) promedio

### Un Solo Recorrido

El Analyzer solo recorre el AST una vez, verificando todas las reglas semanticas simultaneamente.

## Testing del Analyzer

```mermaid
graph TB
    A[Analyzer Tests] --> B[Test Variables]
    A --> C[Test Tipos]
    A --> D[Test Constantes]
    A --> E[Test Scope]
    A --> F[Test Errores]

    B --> B1[Declaracion valida]
    B --> B2[Redeclaracion]
    B --> B3[Variable no definida]

    C --> C1[Compatibilidad tipos]
    C --> C2[Promocion tipos]
    C --> C3[Operaciones invalidas]

    D --> D1[Seal valido]
    D --> D2[Asignacion a seal]

    E --> E1[Variables en bloques]
    E --> E2[Scope de if/else]
    E --> E3[Scope de funciones]

    F --> F1[Mensajes de error]
    F --> F2[Recuperacion]

    style A fill:#4a90e2
```

## Performance del Analyzer

| Operacion | Complejidad |
|-----------|-------------|
| analyze(program) | O(n) donde n = nodos del AST |
| analyzeStmt() | O(1) |
| checkExpr() | O(m) donde m = profundidad expresion |
| symbol_table.get() | O(1) promedio |
| symbol_table.put() | O(1) promedio |
| **Total** | **O(n)** lineal en tamano del AST |

## Integracion con Otras Fases

```mermaid
sequenceDiagram
    participant P as Parser
    participant A as Analyzer
    participant C as CodeGen

    P->>A: Program (AST)

    A->>A: Verificar tipos
    A->>A: Verificar variables
    A->>A: Verificar constantes

    alt Errores encontrados
        A-->>P: Lista de errores
        P->>P: Mostrar errores al usuario
    else Sin errores
        A-->>C: AST validado
        C->>C: Generar codigo
    end
```

## Limitaciones Actuales

1. **Sin tabla de funciones**: Las funciones no se verifican completamente
2. **Scope global**: Solo hay un scope global (se limpia en bloques)
3. **Sin inferencia de tipos**: Los tipos deben declararse explicitamente
4. **Sin verificacion de return**: No verifica que funciones retornen valores

## Mejoras Futuras

```mermaid
graph TB
    A[Mejoras Futuras] --> B[Tabla de Funciones]
    A --> C[Scope Stack]
    A --> D[Verificacion de Return]
    A --> E[Inferencia de Tipos]

    B --> F[Verificar parametros<br/>en llamadas]
    C --> G[Scopes anidados<br/>correctos]
    D --> H[Todas las rutas<br/>retornan valor]
    E --> I[make x = 5<br/>infiere int]

    style A fill:#4a90e2
    style B fill:#f5a623
    style C fill:#f5a623
    style D fill:#f5a623
    style E fill:#f5a623
```

## Proximos Pasos

Una vez que el AST ha sido validado semanticamente, el [Code Generator](07-CODEGEN.md) puede generar codigo C con confianza.

## Referencias

- [Type System](09-TYPE-SYSTEM.md) - Sistema de tipos en detalle
- [Error Handling](14-ERROR-HANDLING.md) - Manejo de errores
- [AST Structure](13-AST-STRUCTURE.md) - Estructura del AST
