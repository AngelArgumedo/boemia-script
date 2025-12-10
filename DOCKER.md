# Boemia Script Compiler - Docker/Podman Guide

Este documento explica cómo usar el compilador de Boemia Script con Docker o Podman.

## Construcción de la Imagen

### Con Docker

```bash
# Construir la imagen
docker build -t boemia-script:latest .

# O usando el Makefile
make docker-build
```

### Con Podman

```bash
# Construir la imagen
podman build -t boemia-script:latest .

# O usando el Makefile
make podman-build
```

## Uso Básico

### Compilar un Programa

#### Docker

```bash
# Compilar un archivo .bs
docker run --rm \
  -v $(pwd)/examples:/workspace/examples:ro \
  -v $(pwd)/build:/workspace/build \
  boemia-script:latest \
  examples/hello.bs -o hello

# Ejecutar el programa compilado
./build/hello
```

#### Podman

```bash
# Compilar un archivo .bs
podman run --rm \
  -v $(pwd)/examples:/workspace/examples:ro \
  -v $(pwd)/build:/workspace/build \
  boemia-script:latest \
  examples/hello.bs -o hello

# Ejecutar el programa compilado
./build/hello
```

### Modo Interactivo

#### Docker

```bash
# Ejecutar en modo interactivo
docker run -it --rm \
  -v $(pwd)/examples:/workspace/examples:ro \
  -v $(pwd)/build:/workspace/build \
  boemia-script:latest /bin/sh

# Dentro del contenedor, puedes compilar programas
boemia-compiler examples/hello.bs -o hello
./build/hello
```

#### Podman

```bash
# Ejecutar en modo interactivo
podman run -it --rm \
  -v $(pwd)/examples:/workspace/examples:ro \
  -v $(pwd)/build:/workspace/build \
  boemia-script:latest /bin/sh

# Dentro del contenedor
boemia-compiler examples/hello.bs -o hello
./build/hello
```

## Usando Docker Compose

```bash
# Iniciar el servicio
docker-compose up -d

# Ejecutar comandos en el contenedor
docker-compose exec boemia-compiler boemia-compiler examples/hello.bs -o hello

# Ver logs
docker-compose logs -f

# Detener el servicio
docker-compose down
```

## Usando el Makefile

El proyecto incluye un Makefile con comandos útiles:

```bash
# Ver todos los comandos disponibles
make help

# Docker
make docker-build    # Construir imagen Docker
make docker-run      # Ejecutar en modo interactivo
make docker-compile  # Compilar ejemplo hello.bs

# Podman
make podman-build    # Construir imagen Podman
make podman-run      # Ejecutar en modo interactivo
make podman-compile  # Compilar ejemplo hello.bs
```

## Volúmenes

La imagen está configurada con dos puntos de montaje:

1. **`/workspace/examples`** (read-only): Para archivos fuente .bs
2. **`/workspace/build`**: Para programas compilados

Esto permite compilar programas desde tu host y guardar los ejecutables en `./build/`.

## Estructura de la Imagen

- **Stage 1 (Builder)**: Compila el compilador de Boemia Script usando Zig
- **Stage 2 (Runtime)**: Imagen ligera con solo el compilador y GCC para generar ejecutables

### Tamaño de la Imagen

La imagen final es pequeña (~50-100MB) gracias al multi-stage build usando Alpine Linux.

## Ejemplos de Uso

### Compilar todos los ejemplos

```bash
# Docker
for file in examples/*.bs; do
  name=$(basename "$file" .bs)
  docker run --rm \
    -v $(pwd)/examples:/workspace/examples:ro \
    -v $(pwd)/build:/workspace/build \
    boemia-script:latest \
    examples/$name.bs -o $name
done

# Podman (reemplazar 'docker' por 'podman')
```

### Usar con archivos locales

```bash
# Crear un nuevo archivo .bs
echo 'make x: int = 42; print(x);' > myprogram.bs

# Compilarlo con Docker
docker run --rm \
  -v $(pwd):/workspace \
  boemia-script:latest \
  myprogram.bs -o myprogram

# Ejecutarlo
./build/myprogram
```

## Troubleshooting

### Error: "permission denied"

Si recibes errores de permisos al escribir en `build/`:

```bash
# Crear el directorio con permisos adecuados
mkdir -p build
chmod 777 build
```

### Error: "gcc: command not found"

La imagen incluye GCC. Si ves este error, reconstruye la imagen:

```bash
docker build --no-cache -t boemia-script:latest .
```

## Diferencias entre Docker y Podman

Podman es compatible con Docker a nivel de comandos. Simplemente reemplaza `docker` por `podman` en todos los comandos. La principal diferencia es que Podman no requiere un daemon y ejecuta contenedores sin privilegios de root por defecto.
