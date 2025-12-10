# Integracion con GCC

## Introduccion

Boemia Script no genera codigo maquina directamente. En su lugar, transpila a codigo C y utiliza GCC (GNU Compiler Collection) o Clang para la compilacion final. Este documento describe como funciona esta integracion.

## ¿Por que GCC?

```mermaid
graph TB
    A[Ventajas de usar GCC] --> B[Compilador maduro]
    A --> C[Optimizaciones avanzadas]
    A --> D[Portabilidad]
    A --> E[Depuracion]

    B --> F[Decadas de desarrollo<br/>y pruebas]
    C --> G[Optimizaciones que superan<br/>compiladores caseros]
    D --> H[Funciona en Linux, macOS,<br/>Windows, BSD, etc]
    E --> I[Mensajes de error claros<br/>Debugging con gdb]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#7ed321
    style E fill:#7ed321
```

## Pipeline de Compilacion Completo

```mermaid
flowchart TD
    A[Archivo .bs] --> B[Lexer]
    B --> C[Parser]
    C --> D[Analyzer]
    D --> E[Code Generator]
    E --> F[Archivo .c en build/]
    F --> G[GCC Compiler]
    G --> H[Archivo objeto .o]
    H --> I[Linker]
    I --> J[Ejecutable en build/]

    style A fill:#e3f2fd
    style F fill:#fff9c4
    style J fill:#c8e6c9
```

## Organizacion de Archivos

```mermaid
graph TB
    A[Proyecto] --> B[src/]
    A --> C[build/]
    A --> D[examples/]

    B --> E[*.zig - Codigo del compilador]
    C --> F[*.c - Codigo C generado]
    C --> G[* - Ejecutables]
    D --> H[*.bs - Programas ejemplo]

    style A fill:#4a90e2
    style C fill:#f5a623
```

**Estructura de directorios**:
```
boemia-script/
├── src/
│   ├── main.zig
│   ├── lexer.zig
│   ├── parser.zig
│   ├── analyzer.zig
│   └── codegen.zig
├── build/              # Creado automaticamente
│   ├── output.c        # Codigo C generado
│   └── output          # Ejecutable final
├── examples/
│   └── hello.bs
└── build.zig
```

## Proceso de Invocacion de GCC

### Codigo de Integracion

```zig
pub fn compileToExecutable(
    allocator: std.mem.Allocator,
    program: *Program,
    output_path: []const u8,
) !void {
    // 1. Generar codigo C
    var codegen = CodeGenerator.init(allocator);
    defer codegen.deinit();
    const c_code = try codegen.generate(program);
    defer allocator.free(c_code);

    // 2. Crear directorio build/
    std.fs.cwd().makeDir("build") catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };

    // 3. Escribir archivo .c
    const c_file_path = try std.fmt.allocPrint(
        allocator,
        "build/{s}.c",
        .{output_path}
    );
    defer allocator.free(c_file_path);

    const c_file = try std.fs.cwd().createFile(c_file_path, .{});
    defer c_file.close();
    try c_file.writeAll(c_code);

    // 4. Preparar path del ejecutable
    const exec_output_path = try std.fmt.allocPrint(
        allocator,
        "build/{s}",
        .{output_path}
    );
    defer allocator.free(exec_output_path);

    // 5. Invocar GCC
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gcc",
            "-o",
            exec_output_path,
            c_file_path,
            "-std=c11",
            "-Wall",
            "-Wextra",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // 6. Verificar resultado
    if (result.term.Exited != 0) {
        std.debug.print("GCC compilation failed:\n{s}\n", .{result.stderr});
        return error.CompilationFailed;
    }

    std.debug.print("Successfully compiled to: {s}\n", .{exec_output_path});
}
```

### Flujo de Ejecucion

```mermaid
sequenceDiagram
    participant M as main.zig
    participant CG as CodeGenerator
    participant FS as FileSystem
    participant GCC as GCC Process

    M->>CG: generate(program)
    CG-->>M: codigo_c: []const u8

    M->>FS: makeDir("build/")
    M->>FS: createFile("build/output.c")
    M->>FS: writeAll(codigo_c)
    FS-->>M: Archivo escrito

    M->>GCC: spawn("gcc -o build/output build/output.c ...")
    GCC->>GCC: Compilar codigo C
    alt Compilacion exitosa
        GCC-->>M: ExitCode 0
        M->>M: Mostrar mensaje de exito
    else Error de compilacion
        GCC-->>M: ExitCode != 0 + stderr
        M->>M: Mostrar errores de GCC
    end
```

## Flags de GCC Utilizadas

```mermaid
graph TB
    A[Flags de GCC] --> B[-o output]
    A --> C[-std=c11]
    A --> D[-Wall]
    A --> E[-Wextra]

    B --> F[Especifica nombre<br/>del ejecutable]
    C --> G[Usa estandar C11<br/>para stdbool.h]
    D --> H[Activa todos<br/>los warnings]
    E --> I[Activa warnings<br/>adicionales]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#f5a623
    style E fill:#f5a623
```

### Descripcion de Flags

| Flag | Proposito | Razon |
|------|-----------|-------|
| `-o <file>` | Especifica output | Nombre del ejecutable final |
| `-std=c11` | Estandar C11 | Necesario para `bool`, `true`, `false` |
| `-Wall` | Todos los warnings | Detectar problemas potenciales |
| `-Wextra` | Warnings extras | Mayor seguridad del codigo |

### ¿Por que C11?

C11 incluye `<stdbool.h>` que define:
- `bool` como tipo
- `true` como 1
- `false` como 0

Sin C11, tendriamos que definir manualmente:
```c
typedef int bool;
#define true 1
#define false 0
```

## Manejo de Errores de GCC

### Tipos de Errores

```mermaid
graph TB
    A[Errores Posibles] --> B[GCC no encontrado]
    A --> C[Error de sintaxis C]
    A --> D[Warning en codigo C]
    A --> E[Error de linker]

    B --> F[PATH no configurado]
    C --> G[Bug en Code Generator]
    D --> H[Codigo C suboptimo]
    E --> I[Funcion no definida]

    style A fill:#d0021b
    style B fill:#f5a623
    style C fill:#f5a623
    style D fill:#fff176
    style E fill:#f5a623
```

### Captura de Errores

```zig
const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "gcc", ... },
});
defer allocator.free(result.stdout);
defer allocator.free(result.stderr);

if (result.term.Exited != 0) {
    std.debug.print("GCC compilation failed:\n{s}\n", .{result.stderr});
    return error.CompilationFailed;
}
```

### Ejemplo de Error

**Codigo Boemia con bug**:
```boemia
make x: int = 5;
print(y);  // 'y' no existe - pero paso el analyzer por un bug
```

**Codigo C generado (incorrecto)**:
```c
int main(void) {
    long long x = 5;
    printf("%lld\n", (long long)y);  // y no declarado
    return 0;
}
```

**Salida de GCC**:
```
build/output.c:5:34: error: use of undeclared identifier 'y'
    printf("%lld\n", (long long)y);
                                 ^
1 error generated.
```

## Optimizaciones de GCC

GCC puede aplicar optimizaciones al codigo C generado.

### Niveles de Optimizacion

```mermaid
graph LR
    A[Niveles de Optimizacion] --> B[-O0]
    A --> C[-O1]
    A --> D[-O2]
    A --> E[-O3]
    A --> F[-Os]

    B --> G[Sin optimizacion<br/>debug facil]
    C --> H[Optimizacion basica]
    D --> I[Optimizacion recomendada]
    E --> J[Optimizacion maxima]
    F --> K[Optimizar tamano]

    style A fill:#4a90e2
    style D fill:#7ed321
```

**Actualmente**: Boemia no especifica nivel de optimizacion (default `-O0`)

**Mejora futura**: Agregar flag `-O` al compilador:
```bash
boemia-compiler programa.bs -o output -O2
```

### Ejemplo de Optimizacion

**Codigo C generado**:
```c
int main(void) {
    long long x = 5;
    long long y = (x + (2 * 3));
    printf("%lld\n", (long long)y);
    return 0;
}
```

**Con `-O2`, GCC optimiza a**:
```c
int main(void) {
    printf("%lld\n", 11LL);  // Calculo en compile-time
    return 0;
}
```

## Alternativas a GCC

```mermaid
graph TB
    A[Compiladores C Soportados] --> B[GCC]
    A --> C[Clang]
    A --> D[MSVC]
    A --> E[TCC]

    B --> F[Default en Linux]
    C --> G[Default en macOS]
    D --> H[Windows<br/>requiere cambios]
    E --> I[Muy rapido<br/>sin optimizaciones]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
```

### Soporte de Clang

Clang es compatible con los flags de GCC:
```bash
clang -o build/output build/output.c -std=c11 -Wall -Wextra
```

**Modificacion necesaria**:
```zig
const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{
        "clang",  // En lugar de "gcc"
        "-o",
        exec_output_path,
        c_file_path,
        "-std=c11",
        "-Wall",
        "-Wextra",
    },
});
```

### Deteccion Automatica

**Mejora futura**: Detectar compilador disponible:
```zig
const compiler = detectCompiler() orelse return error.NoCompilerFound;

fn detectCompiler() ?[]const u8 {
    if (commandExists("gcc")) return "gcc";
    if (commandExists("clang")) return "clang";
    if (commandExists("cc")) return "cc";
    return null;
}
```

## Compilacion Cruzada

```mermaid
graph LR
    A[Cross-compilation] --> B[Linux a Windows]
    A --> C[macOS a Linux]
    A --> D[x86 a ARM]

    B --> E[MinGW-w64]
    C --> F[Toolchain cruzado]
    D --> G[gcc-arm-linux-gnueabihf]

    style A fill:#4a90e2
```

### Ejemplo: Linux a Windows

```bash
x86_64-w64-mingw32-gcc -o output.exe output.c -std=c11
```

**Modificacion en codegen.zig**:
```zig
const target_os = builtin.target.os.tag;
const compiler = switch (target_os) {
    .windows => "x86_64-w64-mingw32-gcc",
    .linux => "gcc",
    .macos => "clang",
    else => "gcc",
};
```

## Debugging del Codigo Generado

### Generacion de Simbolos de Debug

```mermaid
graph TB
    A[Debugging] --> B[-g flag]
    A --> C[Codigo C legible]
    A --> D[Preservar nombres]

    B --> E[Simbolos para gdb/lldb]
    C --> F[Indentacion y formato]
    D --> G[Variables con nombres originales]

    style A fill:#4a90e2
```

**Agregar flag `-g`**:
```zig
.argv = &[_][]const u8{
    "gcc",
    "-o", exec_output_path,
    c_file_path,
    "-std=c11",
    "-g",      // Simbolos de debug
    "-Wall",
    "-Wextra",
},
```

### Uso de GDB

```bash
# Compilar con -g
boemia-compiler programa.bs -o programa

# Debuggear
gdb build/programa

# Comandos GDB
(gdb) break main
(gdb) run
(gdb) next
(gdb) print x
(gdb) continue
```

## Metricas de Compilacion

### Tiempo de Compilacion

```mermaid
graph LR
    A[Tiempo Total] --> B[Boemia Frontend<br/>1-10ms]
    A --> C[Generacion C<br/>1-5ms]
    A --> D[GCC Backend<br/>50-500ms]

    style A fill:#4a90e2
    style B fill:#7ed321
    style C fill:#7ed321
    style D fill:#f5a623
```

**Conclusion**: GCC es el cuello de botella, pero es aceptable para compilacion ahead-of-time.

### Tamano de Ejecutables

| Programa | Codigo C | Ejecutable sin opt | Ejecutable -O2 | Ejecutable -Os |
|----------|----------|-------------------|----------------|----------------|
| Hello World | 150 bytes | 16 KB | 16 KB | 16 KB |
| Factorial | 300 bytes | 16 KB | 16 KB | 16 KB |
| Fibonacci | 400 bytes | 16 KB | 16 KB | 16 KB |

**Nota**: Tamano minimo debido a overhead de C runtime.

## Integracion con Sistema de Build

### Build.zig

```zig
const compile_example = b.addSystemCommand(&[_][]const u8{
    "./zig-out/bin/boemia-compiler",
    "examples/hello.bs",
    "-o",
    "hello",
});
compile_example.step.dependOn(b.getInstallStep());
example_step.dependOn(&compile_example.step);
```

### Makefile (alternativa)

```makefile
BOEMIA_COMPILER = ./zig-out/bin/boemia-compiler
EXAMPLES = $(wildcard examples/*.bs)
OUTPUTS = $(EXAMPLES:examples/%.bs=build/%)

all: $(OUTPUTS)

build/%: examples/%.bs $(BOEMIA_COMPILER)
	$(BOEMIA_COMPILER) $< -o $*

clean:
	rm -rf build/

.PHONY: all clean
```

## Mejoras Futuras

```mermaid
graph TB
    A[Mejoras Futuras] --> B[Compilador configurable]
    A --> C[Niveles de optimizacion]
    A --> D[Compilacion incremental]
    A --> E[LTO Link Time Optimization]

    B --> F[GCC, Clang, MSVC]
    C --> G[-O0, -O1, -O2, -O3]
    D --> H[Solo recompilar<br/>archivos cambiados]
    E --> I[Optimizacion entre<br/>unidades de compilacion]

    style A fill:#4a90e2
    style B fill:#f5a623
    style C fill:#f5a623
    style D fill:#f5a623
    style E fill:#f5a623
```

### Compilacion Incremental

```mermaid
sequenceDiagram
    participant U as Usuario
    participant B as Boemia Compiler
    participant C as Cache
    participant G as GCC

    U->>B: Compilar programa.bs
    B->>C: Hash del codigo fuente
    alt Hash existe en cache
        C-->>B: Usar ejecutable existente
        B-->>U: Compilacion instantanea
    else Hash no existe
        B->>G: Compilar codigo C
        G-->>B: Ejecutable
        B->>C: Guardar hash y ejecutable
        B-->>U: Compilacion completa
    end
```

### Soporte para Static/Dynamic Linking

```bash
# Static (ejecutable independiente)
boemia-compiler programa.bs -o output --static

# Dynamic (requiere libc compartido)
boemia-compiler programa.bs -o output --dynamic
```

## Diagnosticos Mejorados

### Mapping de Errores C a Boemia

**Problema actual**: Los errores de GCC muestran lineas del codigo C, no del codigo Boemia.

**Mejora futura**: Mapear errores:

```
GCC: build/output.c:5:34: error: use of undeclared identifier 'y'

Boemia: programa.bs:3:7: error: variable 'y' not declared
  print(y);
        ^
```

**Implementacion**: Generar comentarios en C con lineas originales:
```c
// Line 3 in programa.bs
printf("%lld\n", (long long)y);
```

## Seguridad

### Validacion de Paths

```zig
// Prevenir path traversal
fn sanitizePath(path: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, path, "..") != null) {
        return error.InvalidPath;
    }
    return path;
}
```

### Sandbox de Compilacion

**Mejora futura**: Compilar en ambiente aislado:
- Limitar uso de memoria de GCC
- Timeout de compilacion
- Restricciones de filesystem

## Referencias

- [Code Generator](07-CODEGEN.md) - Generacion de codigo C
- [Build System](18-BUILD-SYSTEM.md) - Sistema de build completo
- [Testing](19-TESTING.md) - Testing del compilador
