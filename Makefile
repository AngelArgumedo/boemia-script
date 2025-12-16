# Boemia Script Compiler - Makefile

.PHONY: build test clean test-e2e test-memory test-all docker-build docker-run podman-build podman-run help

# Default target
help:
	@echo "Boemia Script Compiler - Available commands:"
	@echo ""
	@echo "  Building:"
	@echo "  make build           - Build the compiler with Zig"
	@echo ""
	@echo "  Testing:"
	@echo "  make test            - Run unit tests"
	@echo "  make test-e2e        - Run end-to-end tests"
	@echo "  make test-memory     - Run memory leak tests"
	@echo "  make test-all        - Run all tests (unit + e2e + memory)"
	@echo ""
	@echo "  Maintenance:"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make fmt             - Format Zig source code"
	@echo ""
	@echo "  Docker commands:"
	@echo "  make docker-build    - Build Docker image"
	@echo "  make docker-run      - Run compiler in Docker (interactive)"
	@echo "  make docker-compile  - Compile example in Docker"
	@echo ""
	@echo "  Podman commands:"
	@echo "  make podman-build    - Build Podman image"
	@echo "  make podman-run      - Run compiler in Podman (interactive)"
	@echo "  make podman-compile  - Compile example in Podman"

# Build the compiler
build:
	zig build

# Run unit tests
test:
	zig build test

# Run end-to-end tests
test-e2e: build
	@echo "Running end-to-end tests..."
	./scripts/run_e2e_tests.sh

# Run memory leak tests
test-memory: build
	@echo "Running memory leak tests..."
	./scripts/check_memory_leaks.sh

# Run all tests
test-all: test test-e2e test-memory
	@echo ""
	@echo "All tests completed successfully!"

# Format Zig source code
fmt:
	zig fmt src/*.zig tests/*.zig

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache build/
	find . -name "*.c" -not -path "./src/*" -delete

# Docker targets
docker-build:
	docker build -t boemia-script:latest .

docker-run:
	docker run -it --rm \
		-v $$(pwd)/examples:/workspace/examples:ro \
		-v $$(pwd)/build:/workspace/build \
		boemia-script:latest

docker-compile:
	@echo "Compiling examples/hello.bs with Docker..."
	docker run --rm \
		-v $$(pwd)/examples:/workspace/examples:ro \
		-v $$(pwd)/build:/workspace/build \
		boemia-script:latest \
		examples/hello.bs -o hello

# Podman targets
podman-build:
	podman build -t boemia-script:latest .

podman-run:
	podman run -it --rm \
		-v $$(pwd)/examples:/workspace/examples:ro \
		-v $$(pwd)/build:/workspace/build \
		boemia-script:latest

podman-compile:
	@echo "Compiling examples/hello.bs with Podman..."
	podman run --rm \
		-v $$(pwd)/examples:/workspace/examples:ro \
		-v $$(pwd)/build:/workspace/build \
		boemia-script:latest \
		examples/hello.bs -o hello

# Docker Compose targets
compose-up:
	docker-compose up -d

compose-down:
	docker-compose down

compose-logs:
	docker-compose logs -f
