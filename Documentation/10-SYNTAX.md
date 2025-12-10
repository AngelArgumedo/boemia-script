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

<return_statement> ::= "return" <expression>? ";"

<print_statement> ::= "print" "(" <expression> ")" ";"

<expression_statement> ::= <expression> ";"

<block> ::= "{" <statement>* "}"

<expression> ::= <primary>
               | <expression> <binary_op> <expression>
               | <unary_op> <expression>
               | <identifier> "(" <arguments>? ")"

<primary> ::= <integer>
            | <float>
            | <string>
            | <boolean>
            | <identifier>
            | "(" <expression> ")"

<type> ::= "int" | "float" | "string" | "bool" | "void"

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
make x: int = 10;
make nombre: string = "Boemia";
make activo: bool = true;
make pi: float = 3.14159;
```

**Reglas**:
- Declaradas con la palabra clave `make`
- Requieren tipo explicito
- Deben ser inicializadas en la declaracion
- Pueden ser reasignadas posteriormente

#### Constantes Inmutables (seal)

Variables cuyo valor no puede cambiar despues de la inicializacion.

```boemia
seal MAX_USERS: int = 100;
seal PI: float = 3.14159265;
seal APP_NAME: string = "Boemia Script";
```

**Reglas**:
- Declaradas con la palabra clave `seal`
- No pueden ser reasignadas
- El compilador genera error si se intenta modificar

### Asignacion

```boemia
make x: int = 5;
x = 10;              // Valido: x es mutable
x = x + 5;           // Valido

seal y: int = 20;
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
make edad: int = 25;
make temperatura: int = -15;
make contador: int = 0;
```

Rango: -9,223,372,036,854,775,808 a 9,223,372,036,854,775,807 (64 bits)

### float - Decimales

```boemia
make pi: float = 3.14159;
make altura: float = 1.75;
make temperatura: float = -3.5;
```

Precision: Double precision IEEE 754 (64 bits)

### string - Cadenas

```boemia
make mensaje: string = "Hola Mundo";
make nombre: string = "Boemia Script";
make vacio: string = "";
```

**Caracteristicas**:
- Delimitadas por comillas dobles `"`
- Soportan multi-linea
- Inmutables (el contenido no puede cambiar)

### bool - Booleanos

```boemia
make activo: bool = true;
make completado: bool = false;
make encontrado: bool = 10 > 5;
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
make suma: int = 5 + 3;              // 8
make resta: int = 10 - 4;            // 6
make multiplicacion: int = 6 * 7;    // 42
make division: int = 20 / 4;         // 5

make compleja: int = (5 + 3) * 2;    // 16
make anidada: int = 10 + (5 * (3 - 1));  // 20
```

#### Precedencia de Operadores

| Precedencia | Operadores | Asociatividad |
|-------------|------------|---------------|
| 1 (Mayor) | `*`, `/` | Izquierda |
| 2 | `+`, `-` | Izquierda |
| 3 | `<`, `>`, `<=`, `>=` | Izquierda |
| 4 (Menor) | `==`, `!=` | Izquierda |

```boemia
make resultado: int = 2 + 3 * 4;     // 14, no 20
make resultado2: int = (2 + 3) * 4;  // 20
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
make igual: bool = 5 == 5;           // true
make diferente: bool = 5 != 3;       // true
make menor: bool = 3 < 5;            // true
make mayor: bool = 10 > 5;           // true
make menorIgual: bool = 5 <= 5;      // true
make mayorIgual: bool = 10 >= 5;     // true
```

### Concatenacion de Strings

```boemia
make saludo: string = "Hola" + " " + "Mundo";  // "Hola Mundo"
make nombre: string = "Juan";
make mensaje: string = "Hola " + nombre;       // "Hola Juan"
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
make x: int = 10;

if x > 5 {
    print("x es mayor que 5");
}
```

#### if-else

```boemia
make edad: int = 18;

if edad >= 18 {
    print("Es mayor de edad");
} else {
    print("Es menor de edad");
}
```

#### if-else if-else (Cascada)

```boemia
make nota: int = 85;

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
make edad: int = 25;
make tieneLicencia: bool = true;

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
make contador: int = 0;

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
        make producto: int = x * y;
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

make resultado: int = suma(5, 3);  // 8
print(resultado);
```

### Funciones con Multiples Parametros

```boemia
fn calcularPromedio(a: int, b: int, c: int): float {
    make suma: int = a + b + c;
    return suma / 3;
}

make prom: float = calcularPromedio(10, 20, 30);
```

### Recursion

```boemia
fn factorial(n: int): int {
    if n <= 1 {
        return 1;
    }
    return n * factorial(n - 1);
}

make resultado: int = factorial(5);  // 120
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

## Sentencia print

```boemia
print(expresion);
```

**Caracteristicas**:
- Detecta automaticamente el tipo de la expresion
- Agrega salto de linea automaticamente
- Soporta cualquier tipo primitivo

```boemia
make x: int = 42;
print(x);                    // 42

make pi: float = 3.14;
print(pi);                   // 3.140000

make mensaje: string = "Hola";
print(mensaje);              // Hola

make activo: bool = true;
print(activo);               // true

print(10 + 5);               // 15
print("Suma: " + "total");   // Suma: total
```

## Comentarios

```boemia
// Esto es un comentario de una linea

make x: int = 42;  // Comentario al final de linea

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
    make x: int = 10;
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
make a: int = 10;
make b: int = 5;

make suma: int = a + b;
make resta: int = a - b;
make mult: int = a * b;
make div: int = a / b;

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
    make fib: int = fibonacci(i);
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
make x:int=5;           // Valido
make    x   :   int   =   5   ;    // Valido (equivalente)
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
