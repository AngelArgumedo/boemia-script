# Scripts de Testing y Utilidades

Este directorio contiene scripts para testing automatizado y utilidades de desarrollo.

## Scripts Disponibles

### run_e2e_tests.sh

Script para ejecutar tests end-to-end completos.

**Proposito:** Compilar y ejecutar todos los ejemplos, verificando que funcionan correctamente.

**Uso:**
```bash
./scripts/run_e2e_tests.sh
```

**Que hace:**
1. Verifica que el compilador este construido
2. Verifica que GCC este instalado
3. Para cada ejemplo en `examples/`:
   - Compila .bs a C
   - Compila C a ejecutable con GCC
   - Ejecuta el programa
   - Verifica el output esperado
4. Genera reporte de resultados

**Output:**
- Resultados en consola con colores
- Logs detallados en `test-results/`
- Exit code 0 si todo pasa, 1 si hay fallos

**Ejemplos testeados:**
- hello.bs
- simple.bs
- types.bs
- conditionals.bs
- loops.bs
- test_array_operations.bs
- test_array_parsing.bs
- test_arrays_complete.bs
- test_arrays_nested.bs
- test_for_in.bs

### check_memory_leaks.sh

Script para detectar memory leaks en el codigo generado.

**Proposito:** Verificar que no haya memory leaks en los programas compilados.

**Uso:**
```bash
./scripts/check_memory_leaks.sh
```

**Que hace:**
1. Detecta el sistema operativo
2. Selecciona herramienta apropiada:
   - Linux: Valgrind
   - macOS: leaks
3. Para ejemplos con arrays:
   - Compila con simbolos de debug
   - Ejecuta con leak detector
   - Analiza resultado
4. Genera reporte de leaks

**Output:**
- Resultados en consola con colores
- Logs detallados en `memory-test-results/`
- Exit code 0 si no hay leaks, 1 si los hay

**Requisitos:**
- Linux: `sudo apt-get install valgrind`
- macOS: leaks viene preinstalado

## Uso con Makefile

Los scripts estan integrados en el Makefile para uso conveniente:

```bash
# Ejecutar solo tests unitarios
make test

# Ejecutar tests end-to-end
make test-e2e

# Ejecutar tests de memoria
make test-memory

# Ejecutar todos los tests
make test-all
```

## Uso en CI/CD

Estos scripts son ejecutados automaticamente por GitHub Actions en cada push y PR.

Ver `.github/workflows/ci.yml` para detalles de integracion.

## Desarrollo de Nuevos Tests

### Agregar un nuevo test E2E

1. Crear archivo `.bs` en `examples/`
2. Editar `run_e2e_tests.sh`
3. Agregar entrada al final de la seccion de tests:

```bash
# Test X: Descripcion
if [ -f "$PROJECT_ROOT/examples/mi_test.bs" ]; then
    run_test "mi_test" "$PROJECT_ROOT/examples/mi_test.bs" "" check_mi_test
fi
```

4. Si necesitas verificacion custom, agregar funcion:

```bash
check_mi_test() {
    grep -q "expected_output" "$1"
}
```

### Agregar un nuevo test de memoria

Los tests de memoria se ejecutan automaticamente para todos los ejemplos que contengan arrays.

Si quieres agregar uno especifico:

1. Editar `check_memory_leaks.sh`
2. Agregar al final de la seccion de tests:

```bash
if [ -f "$PROJECT_ROOT/examples/mi_test_arrays.bs" ]; then
    TOTAL=$((TOTAL + 1))
    if test_memory "mi_test" "$PROJECT_ROOT/examples/mi_test_arrays.bs"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi
```

## Debugging de Fallos

### Test E2E falla

```bash
# 1. Ver logs detallados
cat test-results/nombre_test_compiler.log
cat test-results/nombre_test_gcc.log
cat test-results/nombre_test_output.txt

# 2. Ejecutar manualmente
./zig-out/bin/boemia-compiler examples/failing_test.bs
gcc build/output.c -o test -lm
./test

# 3. Ver codigo C generado
cat build/output.c
```

### Test de memoria falla

```bash
# 1. Ver logs detallados
cat memory-test-results/nombre_test_valgrind.log  # Linux
cat memory-test-results/nombre_test_leaks.log     # macOS

# 2. Ejecutar manualmente con mas detalle (Linux)
./zig-out/bin/boemia-compiler examples/test.bs
gcc build/output.c -o test -lm -g
valgrind --leak-check=full --show-leak-kinds=all ./test

# 3. Ejecutar manualmente (macOS)
./zig-out/bin/boemia-compiler examples/test.bs
gcc build/output.c -o test -lm
leaks -atExit -- ./test
```

## Notas Tecnicas

### run_e2e_tests.sh

- Usa bash strict mode: `set -e`
- Colores ANSI para output
- Funciones reutilizables para tests
- Limpieza automatica de temporales

### check_memory_leaks.sh

- Deteccion automatica de OS
- Manejo de diferencias entre valgrind y leaks
- Compilacion con simbolos de debug (-g)
- Parsing de output de leak detectors

## Contribuir

Al agregar nuevos tests, asegurate de:

1. Documentar que testea
2. Incluir expected output si aplica
3. Agregar comentarios explicativos
4. Testear localmente antes de commit
5. Actualizar este README si es necesario

## Ver Tambien

- [Documentation/26-CI-CD.md](../Documentation/26-CI-CD.md) - Documentacion completa de CI/CD
- [Documentation/19-TESTING.md](../Documentation/19-TESTING.md) - Estrategia general de testing
- `.github/workflows/ci.yml` - Configuracion de GitHub Actions
