# Vision General del Proyecto Boemia Script

## Introduccion

Boemia Script es un lenguaje de programacion compilado con tipos estaticos, disenado desde cero con fines educativos para comprender el funcionamiento interno de los compiladores e interpretes.

## Motivacion

El desarrollo de Boemia Script surge de la necesidad de **desmitificar el proceso de compilacion** y proporcionar una herramienta practica para aprender:

- Como se transforma el codigo fuente en instrucciones ejecutables
- Como funcionan los sistemas de tipos estaticos
- Como se implementan estructuras de control de flujo
- Como se gestiona el scope y las variables
- Como se genera codigo maquina desde un AST (Abstract Syntax Tree)

## Filosofia del Proyecto

### Educacion Primero

Boemia Script no pretende competir con lenguajes de produccion. Su objetivo principal es ser una **plataforma de aprendizaje** donde cada componente del compilador es comprensible y esta completamente documentado.

### Simplicidad y Claridad

Cada decision de diseno prioriza la claridad sobre la optimizacion. El codigo del compilador esta extensamente comentado para facilitar su comprension.

### Funcionalidad Completa

A pesar de su naturaleza educativa, Boemia Script es un compilador funcional que genera ejecutables nativos reales.

## Caracteristicas Principales

### Sistema de Tipos Estaticos

```mermaid
graph LR
    A[Tipos Primitivos] --> B[int]
    A --> C[float]
    A --> D[string]
    A --> E[bool]
    A --> F[void]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
    style F fill:#7ed321
```

Boemia Script implementa verificacion de tipos en tiempo de compilacion, detectando errores antes de la ejecucion.

### Variables Mutables e Inmutables

El lenguaje distingue entre:

- **make**: Variables mutables que pueden cambiar su valor
- **seal**: Constantes inmutables que no pueden ser reasignadas

```boemia
let contador: int = 0;      // Mutable
const PI: float = 3.14159;    // Inmutable
```

### Estructuras de Control Completas

Implementa las estructuras clasicas de control de flujo:

- Condicionales: `if`, `else if`, `else`
- Bucles: `while`, `for`
- Funciones con soporte para recursion

### Generacion de Codigo Nativo

Boemia Script utiliza un enfoque de transpilacion a C, aprovechando:

- Portabilidad multiplataforma
- Optimizaciones de compiladores maduros (GCC/Clang)
- Codigo intermedio legible y debuggeable

## Arquitectura del Compilador

```mermaid
graph TB
    subgraph Input["Entrada"]
        A[Archivo .bs]
    end

    subgraph Frontend["Frontend del Compilador"]
        B[Lexer]
        C[Parser]
        D[Analyzer]
    end

    subgraph IR["Representacion Intermedia"]
        E[AST]
    end

    subgraph Backend["Backend del Compilador"]
        F[Code Generator]
        G[Compilador C]
    end

    subgraph Output["Salida"]
        H[Ejecutable Nativo]
    end

    A --> B
    B --> C
    C --> E
    E --> D
    D --> F
    F --> G
    G --> H

    style Input fill:#e3f2fd
    style Frontend fill:#fff3e0
    style IR fill:#f3e5f5
    style Backend fill:#e8f5e9
    style Output fill:#c8e6c9
```

### Fases del Compilador

1. **Analisis Lexico**: Conversion de texto a tokens
2. **Analisis Sintactico**: Construccion del AST
3. **Analisis Semantico**: Verificacion de tipos y reglas
4. **Generacion de Codigo**: Produccion de codigo C
5. **Compilacion Final**: GCC genera el binario

## Stack Tecnologico

### Zig como Lenguaje de Implementacion

```mermaid
graph LR
    A[Zig] --> B[Control de Bajo Nivel]
    A --> C[Manejo Explicito de Memoria]
    A --> D[Sin Runtime]
    A --> E[Interop con C]
    A --> F[Sistema de Tipos Robusto]

    style A fill:#f7931e
    style B fill:#4a90e2
    style C fill:#4a90e2
    style D fill:#4a90e2
    style E fill:#4a90e2
    style F fill:#4a90e2
```

#### Ventajas de Zig

**Control de Bajo Nivel**: Perfecto para implementar compiladores donde el rendimiento importa.

**Manejo Explicito de Memoria**: Permite aprender sobre gestion de memoria mediante allocators.

**Sin Runtime**: Los binarios del compilador son pequenos y eficientes.

**Interoperabilidad con C**: Facilita la generacion de codigo C sin overhead.

**Seguridad**: El sistema de tipos de Zig previene errores comunes.

### C como Target de Compilacion

La decision de transpilar a C en lugar de generar codigo maquina directo se basa en:

1. **Simplicidad Pedagogica**: Es mas facil entender la generacion de codigo C que ensamblador
2. **Portabilidad**: El codigo C se compila en cualquier plataforma
3. **Optimizacion**: Aprovechamos decadas de optimizaciones de GCC/Clang
4. **Debugging**: El codigo generado es legible por humanos

## Estado Actual del Proyecto

### Version 1.0 - Funcional

El compilador esta completamente operativo y puede compilar programas Boemia Script a ejecutables nativos.

```mermaid
graph LR
    A[Fase 1: Compilador Base] --> |Completada| B[Fase 2: Caracteristicas del Lenguaje]
    B --> |Completada| C[Fase 3: Testing]
    C --> |En Progreso| D[Fase 4: Optimizaciones]
    D --> |Futuro| E[Fase 5: Caracteristicas Avanzadas]

    style A fill:#c8e6c9
    style B fill:#c8e6c9
    style C fill:#fff9c4
    style D fill:#ffccbc
    style E fill:#f5f5f5
```

### Implementado

- Analisis lexico completo
- Parser con construccion de AST
- Verificacion de tipos
- Generacion de codigo C
- Compilacion a binarios nativos
- CLI funcional
- Variables y constantes
- Tipos primitivos (int, float, string, bool)
- Operadores aritmeticos y de comparacion
- Estructuras de control (if/else, while, for)
- Funciones con recursion
- Sistema de print con deteccion de tipos

### En Desarrollo

- Suite de tests completa
- Ejemplos adicionales
- Benchmarks de rendimiento

### Planeado (v2.0)

- Arrays y colecciones
- Structs/Tipos personalizados
- Sistema de modulos
- Inferencia de tipos
- Manejo de errores (try/catch)
- Genericos
- Garbage Collection

## Caso de Uso

### Ejemplo Simple

**Codigo Boemia Script:**

```boemia
let x: int = 42;
const mensaje: string = "Hola Mundo";

if x > 40 {
    print(mensaje);
    print(x);
}
```

**Compilacion:**

```bash
boemia-compiler programa.bs -o programa
./build/programa
```

**Salida:**

```
Hola Mundo
42
```

### Flujo de Trabajo

```mermaid
sequenceDiagram
    participant U as Usuario
    participant C as Compilador
    participant L as Lexer
    participant P as Parser
    participant A as Analyzer
    participant G as CodeGen
    participant GCC as GCC
    participant E as Ejecutable

    U->>C: boemia-compiler programa.bs
    C->>L: Tokenizar codigo fuente
    L->>P: Lista de tokens
    P->>A: AST
    A->>G: AST validado
    G->>GCC: Codigo C
    GCC->>E: Binario nativo
    E->>U: Ejecutar programa
```

## Proposito Educativo

Boemia Script es ideal para:

### Estudiantes de Compiladores

Proporciona un ejemplo completo y funcional de todas las fases de compilacion.

### Desarrolladores Curiosos

Permite entender como los lenguajes que usamos diariamente funcionan internamente.

### Instructores

Puede ser usado como material de ensenanza con codigo completamente documentado.

## Comparacion con Otros Proyectos

| Caracteristica | Boemia Script | Lenguajes de Produccion | Otros Proyectos Educativos |
|----------------|---------------|------------------------|----------------------------|
| Objetivo | Educacion | Produccion | Educacion |
| Documentacion | Extensiva | Variable | Limitada |
| Funcional | Si | Si | Parcial |
| Complejidad | Moderada | Alta | Baja |
| Codigo Fuente | Zig | C/C++/Rust | Python/JavaScript |
| Target | C → Nativo | Nativo/VM | Interprete |

## Recursos de Aprendizaje

Si estas interesado en profundizar en compiladores, estos recursos complementan Boemia Script:

- **Crafting Interpreters** por Bob Nystrom
- **Writing An Interpreter In Go** por Thorsten Ball
- **Engineering a Compiler** por Cooper y Torczon
- **Zig Language Reference** - Documentacion oficial

## Proximos Pasos

Para comenzar a explorar Boemia Script:

1. Lee la [Arquitectura del Compilador](02-ARCHITECTURE.md) para entender la estructura general
2. Estudia el [Pipeline de Compilacion](03-COMPILATION-PIPELINE.md) para ver el flujo completo
3. Profundiza en cada componente comenzando por el [Lexer](04-LEXER.md)
4. Practica con la [Guia de Uso](16-USER-GUIDE.md) y los [Ejemplos](17-EXAMPLES.md)

## Licencia y Contribuciones

Boemia Script es software libre bajo licencia MIT. Las contribuciones son bienvenidas siguiendo las guias de [Contribucion](24-CONTRIBUTING.md).
