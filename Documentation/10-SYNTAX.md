# Sintaxis del Lenguaje Boemia Script

## Introduccion

Este documento describe la sintaxis completa del lenguaje de programacion Boemia Script, incluyendo todas las construcciones sintacticas, reglas gramaticales y ejemplos practicos.

## Gramatica del Lenguaje

### Notacion BNF

```
<program> ::= <statement>*

<statement> ::= <variable_decl>
              | <assignment>
              | <if_statement>
              | <while_statement>
              | <for_statement>
              | <function_decl>
              | <struct_decl>
              | <return_statement>
              | <print_statement>
              | <expression_statement>
              | <block>

<variable_decl> ::= ("make" | "seal") <identifier> ":" <type> "=" <expression> ";"

<assignment> ::= <identifier> "=" <expression> ";"

<if_statement> ::= "if" <expression> "{" <statement>* "}"
                   ("else" "if" <expression> "{" <statement>* "}")*
                   ("else" "{" <statement>* "}")?

<while_statement> ::= "while" <expression> "{" <statement>* "}"

<for_statement> ::= "for" <identifier> ":" <type> "=" <expression> ";"
                    <expression> ";" <assignment> "{" <statement>* "}"

<function_decl> ::= "fn" <identifier> "(" <parameters>? ")" ":" <type>
                    "{" <statement>* "}"

<struct_decl> ::= "struct" <identifier> "{" <field_list> "}"

<field_list> ::= <field> ("," <field>)*

<field> ::= <identifier> ":" <type>

<return_statement> ::= "return" <expression>? ";"

<print_statement> ::= "print" "(" <expression> ")" ";"

<expression_statement> ::= <expression> ";"

<block> ::= "{" <statement>* "}"

<expression> ::= <primary>
               | <expression> <binary_op> <expression>
               | <unary_op> <expression>
               | <identifier> "(" <arguments>? ")"
               | <struct_literal>
               | <array_literal>
               | <expression> "[" <expression> "]"
               | <expression> "." <identifier>

<primary> ::= <integer>
            | <float>
            | <string>
            | <boolean>
            | <identifier>
            | "(" <expression> ")"

<struct_literal> ::= <identifier> "{" <field_value_list>? "}"

<field_value_list> ::= <field_value> ("," <field_value>)*

<field_value> ::= <identifier> ":" <expression>

<array_literal> ::= "[" <expression_list>? "]"

<expression_list> ::= <expression> ("," <expression>)*

<type> ::= "int" | "float" | "string" | "bool" | "void"
         | "[" <type> "]"
         | <identifier>

<binary_op> ::= "+" | "-" | "*" | "/" | "==" | "!=" | "<" | ">" | "<=" | ">="

<unary_op> ::= "-" | "!"
```

## Declaraciones

### Declaracion de Variables

```mermaid
graph TB
    A[Declaracion de Variable] --> B[Mutables: make]
    A --> C[Inmutables: seal]

    B --> D[Sintaxis:<br/>make nombre: tipo = valor;]
    C --> E[Sintaxis:<br/>seal nombre: tipo = valor;]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#f5a623
```

#### Variables Mutables (make)

Variables que pueden cambiar su valor durante la ejecucion.

```boemia
let x: int = 10;
let nombre: string = "Boemia";
let activo: bool = true;
let pi: float = 3.14159;
```

**Reglas**:
- Declaradas con la palabra clave `make`
- Requieren tipo explicito
- Deben ser inicializadas en la declaracion
- Pueden ser reasignadas posteriormente

#### Constantes Inmutables (seal)

Variables cuyo valor no puede cambiar despues de la inicializacion.

```boemia
const MAX_USERS: int = 100;
const PI: float = 3.14159265;
const APP_NAME: string = "Boemia Script";
```

**Reglas**:
- Declaradas con la palabra clave `seal`
- No pueden ser reasignadas
- El compilador genera error si se intenta modificar

### Asignacion

```boemia
let x: int = 5;
x = 10;              // Valido: x es mutable
x = x + 5;           // Valido

const y: int = 20;
y = 30;              // ERROR: y es inmutable
```

```mermaid
flowchart TD
    A[Asignacion] --> B{Variable es mutable?}
    B -->|Si - make| C[Permitir asignacion]
    B -->|No - seal| D[ERROR: Constante no puede cambiar]

    style C fill:#7ed321
    style D fill:#d0021b
```

## Tipos de Datos

```mermaid
graph TB
    A[Tipos Primitivos] --> B[int<br/>Enteros de 64 bits]
    A --> C[float<br/>Decimales de 64 bits]
    A --> D[string<br/>Cadenas de texto]
    A --> E[bool<br/>Booleanos]
    A --> F[void<br/>Sin tipo de retorno]

    B --> B1[Ejemplo: 42, -100, 0]
    C --> C1[Ejemplo: 3.14, -2.5, 0.001]
    D --> D1[Ejemplo: "hola", "mundo"]
    E --> E1[Ejemplo: true, false]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
    style F fill:#7ed321
```

### int - Enteros

```boemia
let edad: int = 25;
let temperatura: int = -15;
let contador: int = 0;
```

Rango: -9,223,372,036,854,775,808 a 9,223,372,036,854,775,807 (64 bits)

### float - Decimales

```boemia
let pi: float = 3.14159;
let altura: float = 1.75;
let temperatura: float = -3.5;
```

Precision: Double precision IEEE 754 (64 bits)

### string - Cadenas

```boemia
let mensaje: string = "Hola Mundo";
let nombre: string = "Boemia Script";
let vacio: string = "";
```

**Caracteristicas**:
- Delimitadas por comillas dobles `"`
- Soportan multi-linea
- Inmutables (el contenido no puede cambiar)

### bool - Booleanos

```boemia
let activo: bool = true;
let completado: bool = false;
let encontrado: bool = 10 > 5;
```

Valores: `true` o `false`

## Expresiones

### Expresiones Aritmeticas

```mermaid
graph LR
    A[Operadores Aritmeticos] --> B[+ Suma]
    A --> C[- Resta]
    A --> D[* Multiplicacion]
    A --> E[/ Division]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
```

```boemia
let suma: int = 5 + 3;              // 8
let resta: int = 10 - 4;            // 6
let multiplicacion: int = 6 * 7;    // 42
let division: int = 20 / 4;         // 5

let compleja: int = (5 + 3) * 2;    // 16
let anidada: int = 10 + (5 * (3 - 1));  // 20
```

#### Precedencia de Operadores

| Precedencia | Operadores | Asociatividad |
|-------------|------------|---------------|
| 1 (Mayor) | `*`, `/` | Izquierda |
| 2 | `+`, `-` | Izquierda |
| 3 | `<`, `>`, `<=`, `>=` | Izquierda |
| 4 (Menor) | `==`, `!=` | Izquierda |

```boemia
let resultado: int = 2 + 3 * 4;     // 14, no 20
let resultado2: int = (2 + 3) * 4;  // 20
```

### Expresiones de Comparacion

```mermaid
graph TB
    A[Operadores de Comparacion] --> B[== Igualdad]
    A --> C[!= Desigualdad]
    A --> D[< Menor que]
    A --> E[> Mayor que]
    A --> F[<= Menor o igual]
    A --> G[>= Mayor o igual]

    B --> H[Retorna bool]
    C --> H
    D --> H
    E --> H
    F --> H
    G --> H

    style A fill:#4a90e2
    style H fill:#7ed321
```

```boemia
let igual: bool = 5 == 5;           // true
let diferente: bool = 5 != 3;       // true
let menor: bool = 3 < 5;            // true
let mayor: bool = 10 > 5;           // true
let menorIgual: bool = 5 <= 5;      // true
let mayorIgual: bool = 10 >= 5;     // true
```

### Concatenacion de Strings

```boemia
let saludo: string = "Hola" + " " + "Mundo";  // "Hola Mundo"
let nombre: string = "Juan";
let mensaje: string = "Hola " + nombre;       // "Hola Juan"
```

## Estructuras de Control

### Condicionales if/else

```mermaid
flowchart TD
    A[if condicion] --> B{condicion es true?}
    B -->|Si| C[Ejecutar bloque then]
    B -->|No| D{Hay else?}
    D -->|Si| E[Ejecutar bloque else]
    D -->|No| F[Continuar]
    C --> F
    E --> F

    style A fill:#4a90e2
    style C fill:#7ed321
    style E fill:#f5a623
    style F fill:#7ed321
```

#### if Simple

```boemia
let x: int = 10;

if x > 5 {
    print("x es mayor que 5");
}
```

#### if-else

```boemia
let edad: int = 18;

if edad >= 18 {
    print("Es mayor de edad");
} else {
    print("Es menor de edad");
}
```

#### if-else if-else (Cascada)

```boemia
let nota: int = 85;

if nota >= 90 {
    print("A");
} else if nota >= 80 {
    print("B");
} else if nota >= 70 {
    print("C");
} else if nota >= 60 {
    print("D");
} else {
    print("F");
}
```

**Flujo de Ejecucion**:

```mermaid
flowchart TD
    A[Evaluar primera condicion] --> B{condicion true?}
    B -->|Si| C[Ejecutar bloque y terminar]
    B -->|No| D{Hay else if?}
    D -->|Si| E[Evaluar siguiente condicion]
    E --> B
    D -->|No| F{Hay else?}
    F -->|Si| G[Ejecutar bloque else]
    F -->|No| H[Continuar]

    style C fill:#7ed321
    style G fill:#f5a623
    style H fill:#7ed321
```

#### if Anidados

```boemia
let edad: int = 25;
let tieneLicencia: bool = true;

if edad >= 18 {
    if tieneLicencia == true {
        print("Puede conducir");
    } else {
        print("Necesita obtener licencia");
    }
} else {
    print("Muy joven para conducir");
}
```

### Bucle while

```mermaid
flowchart TD
    A[while condicion] --> B{condicion true?}
    B -->|Si| C[Ejecutar cuerpo]
    C --> B
    B -->|No| D[Continuar]

    style A fill:#4a90e2
    style C fill:#7ed321
    style D fill:#7ed321
```

```boemia
let contador: int = 0;

while contador < 5 {
    print(contador);
    contador = contador + 1;
}
// Imprime: 0, 1, 2, 3, 4
```

**Importante**: La condicion se evalua ANTES de cada iteracion. Si es falsa desde el inicio, el cuerpo nunca se ejecuta.

### Bucle for

```mermaid
flowchart TD
    A[for init; condicion; update] --> B[Ejecutar init]
    B --> C{condicion true?}
    C -->|Si| D[Ejecutar cuerpo]
    D --> E[Ejecutar update]
    E --> C
    C -->|No| F[Continuar]

    style A fill:#4a90e2
    style D fill:#7ed321
    style E fill:#f5a623
    style F fill:#7ed321
```

```boemia
for i: int = 0; i < 10; i = i + 1 {
    print(i);
}
// Imprime: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
```

**Componentes**:
1. **Inicializacion**: `i: int = 0` - Se ejecuta una vez al inicio
2. **Condicion**: `i < 10` - Se evalua antes de cada iteracion
3. **Actualizacion**: `i = i + 1` - Se ejecuta despues de cada iteracion

#### for Anidados

```boemia
for x: int = 1; x <= 3; x = x + 1 {
    for y: int = 1; y <= 3; y = y + 1 {
        let producto: int = x * y;
        print(producto);
    }
}
```

## Funciones

```mermaid
graph TB
    A[Declaracion de Funcion] --> B[Nombre]
    A --> C[Parametros]
    A --> D[Tipo de Retorno]
    A --> E[Cuerpo]

    C --> C1[Lista de param: tipo]
    D --> D1[void o tipo primitivo]
    E --> E1[Bloque de statements]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
```

### Sintaxis

```boemia
fn nombreFuncion(param1: tipo1, param2: tipo2): tipoRetorno {
    // cuerpo
    return valor;
}
```

### Funciones sin Parametros

```boemia
fn saludar(): void {
    print("Hola Mundo");
}

saludar();  // Llamada
```

### Funciones con Parametros

```boemia
fn suma(a: int, b: int): int {
    return a + b;
}

let resultado: int = suma(5, 3);  // 8
print(resultado);
```

### Funciones con Multiples Parametros

```boemia
fn calcularPromedio(a: int, b: int, c: int): float {
    let suma: int = a + b + c;
    return suma / 3;
}

let prom: float = calcularPromedio(10, 20, 30);
```

### Recursion

```boemia
fn factorial(n: int): int {
    if n <= 1 {
        return 1;
    }
    return n * factorial(n - 1);
}

let resultado: int = factorial(5);  // 120
print(resultado);
```

**Flujo de Recursion**:

```mermaid
graph TD
    A[factorial 5] --> B[5 * factorial 4]
    B --> C[4 * factorial 3]
    C --> D[3 * factorial 2]
    D --> E[2 * factorial 1]
    E --> F[1 - caso base]

    F --> G[Retorna 1]
    G --> H[2 * 1 = 2]
    H --> I[3 * 2 = 6]
    I --> J[4 * 6 = 24]
    J --> K[5 * 24 = 120]

    style A fill:#4a90e2
    style F fill:#7ed321
    style K fill:#7ed321
```

## Structs

```mermaid
graph TB
    A[Structs] --> B[Declaracion]
    A --> C[Instanciacion]
    A --> D[Acceso a Campos]

    B --> B1[struct Nombre ...]
    C --> C1[Nombre { ... }]
    D --> D1[variable.campo]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
```

### Declaracion de Structs

```boemia
struct NombreStruct {
    campo1: tipo1,
    campo2: tipo2,
    campo3: tipo3
}
```

**Reglas**:
- Declarados con la palabra clave `struct`
- Nombre debe comenzar con may\u00fascula (convención)
- Campos separados por comas
- Cada campo tiene nombre y tipo
- Los structs deben declararse antes de usarse

**Ejemplos**:

```boemia
struct Point {
    x: int,
    y: int
}

struct Player {
    name: string,
    score: int,
    isActive: bool
}

struct Vector2D {
    x: float,
    y: float
}
```

### Instanciacion de Structs

```boemia
let variable: NombreStruct = NombreStruct {
    campo1: valor1,
    campo2: valor2,
    campo3: valor3
};
```

**Reglas**:
- Se usa el nombre del struct como constructor
- Todos los campos deben especificarse
- Valores separados por comas
- Sintaxis: `campo: valor`

**Ejemplos**:

```boemia
let p1: Point = Point { x: 10, y: 20 };
let p2: Point = Point { x: 5, y: 15 };

let player: Player = Player {
    name: "Alice",
    score: 100,
    isActive: true
};

let vec: Vector2D = Vector2D { x: 1.5, y: 2.3 };
```

### Acceso a Campos

```boemia
variable.campo
```

**Ejemplos**:

```boemia
let p: Point = Point { x: 10, y: 20 };
let x_val: int = p.x;  // 10
let y_val: int = p.y;  // 20

print(p.x);
print(p.y);
```

### Structs Anidados

Los structs pueden contener otros structs como campos.

**Declaracion**:

```boemia
struct Point {
    x: int,
    y: int
}

struct Rectangle {
    topLeft: Point,
    width: int,
    height: int
}
```

**Instanciacion con variable existente**:

```boemia
let origin: Point = Point { x: 0, y: 0 };
let rect: Rectangle = Rectangle {
    topLeft: origin,
    width: 100,
    height: 50
};
```

**Instanciacion con literal anidado**:

```boemia
let rect2: Rectangle = Rectangle {
    topLeft: Point { x: 10, y: 20 },
    width: 200,
    height: 150
};
```

**Acceso anidado**:

```boemia
let top_x: int = rect.topLeft.x;  // 0
let top_y: int = rect.topLeft.y;  // 0

print(rect2.topLeft.x);  // 10
print(rect2.topLeft.y);  // 20
```

### Arrays de Structs

```boemia
let puntos: [Point] = [
    Point { x: 0, y: 0 },
    Point { x: 10, y: 20 },
    Point { x: 30, y: 40 }
];

let primer_punto: Point = puntos[0];
print(primer_punto.x);  // 0
```

### Structs con Arrays

```boemia
struct Team {
    name: string,
    members: [string],
    scores: [int]
}

let team: Team = Team {
    name: "Alpha",
    members: ["Alice", "Bob", "Carlos"],
    scores: [100, 85, 92]
};

print(team.members[0]);  // "Alice"
print(team.scores[0]);   // 100
```

### Limitaciones Actuales

- No hay métodos en structs (solo datos)
- No hay herencia
- No hay constructores especiales
- Todos los campos son públicos
- No hay valores por defecto

Ver [Documentación de Structs](27-STRUCTS.md) para más detalles.

## Sentencia print

```boemia
print(expresion);
```

**Caracteristicas**:
- Detecta automaticamente el tipo de la expresion
- Agrega salto de linea automaticamente
- Soporta cualquier tipo primitivo

```boemia
let x: int = 42;
print(x);                    // 42

let pi: float = 3.14;
print(pi);                   // 3.140000

let mensaje: string = "Hola";
print(mensaje);              // Hola

let activo: bool = true;
print(activo);               // true

print(10 + 5);               // 15
print("Suma: " + "total");   // Suma: total
```

## Comentarios

```boemia
// Esto es un comentario de una linea

let x: int = 42;  // Comentario al final de linea

// Los comentarios son ignorados por el compilador
// Pueden usarse para documentar el codigo
```

**Reglas**:
- Comienzan con `//`
- Se extienden hasta el final de la linea
- No existen comentarios multi-linea (por ahora)

## Bloques de Codigo

```boemia
{
    let x: int = 10;
    print(x);
}
// x no existe fuera del bloque
```

```mermaid
graph TB
    A[Bloque Externo] --> B[Variable global visible]
    A --> C[Bloque Interno]
    C --> D[Variables internas]
    D --> E[No visibles fuera]

    style A fill:#4a90e2
    style C fill:#7ed321
    style E fill:#d0021b
```

## Ejemplos Completos

### Ejemplo 1: Calculadora Simple

```boemia
let a: int = 10;
let b: int = 5;

let suma: int = a + b;
let resta: int = a - b;
let mult: int = a * b;
let div: int = a / b;

print(suma);   // 15
print(resta);  // 5
print(mult);   // 50
print(div);    // 2
```

### Ejemplo 2: Numeros Pares

```boemia
for i: int = 1; i <= 10; i = i + 1 {
    if i % 2 == 0 {
        print(i);
    }
}
// Imprime: 2, 4, 6, 8, 10
```

### Ejemplo 3: Fibonacci

```boemia
fn fibonacci(n: int): int {
    if n <= 1 {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

for i: int = 0; i < 10; i = i + 1 {
    let fib: int = fibonacci(i);
    print(fib);
}
// Imprime: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
```

## Reglas Lexicas

### Identificadores

**Reglas**:
- Empiezan con letra (a-z, A-Z) o underscore (_)
- Pueden contener letras, digitos (0-9) y underscores
- Case-sensitive: `contador` != `Contador`
- No pueden ser palabras reservadas

**Validos**:
```
x
contador
miVariable
_privado
valor2
suma_total
```

**Invalidos**:
```
2variable   // Empieza con digito
mi-variable // Contiene guion
make        // Palabra reservada
```

### Espacios en Blanco

Espacios, tabs y saltos de linea se ignoran, excepto:
- Dentro de strings
- Para separar tokens

```boemia
let x:int=5;           // Valido
let    x   :   int   =   5   ;    // Valido (equivalente)
```

## Palabras Reservadas

Lista completa de palabras que no pueden usarse como identificadores:

```
make    seal    fn      return
if      else    while   for
print   true    false
int     float   string  bool
```

## Limitaciones Actuales

1. No soporta arrays
2. No soporta structs/objetos
3. No tiene sistema de modulos
4. No tiene manejo de errores (try/catch)
5. Comentarios solo de una linea
6. Strings inmutables

## Proximos Pasos

Ver [Sistema de Tipos](09-TYPE-SYSTEM.md) para detalles sobre verificacion de tipos.
Ver [Ejemplos Practicos](17-EXAMPLES.md) para mas casos de uso.
