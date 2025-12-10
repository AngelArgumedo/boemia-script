# Boemia Script Compiler - Dockerfile
# Multi-stage build for optimal image size

# Stage 1: Build stage
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    zig \
    gcc \
    musl-dev \
    git

# Set working directory
WORKDIR /app

# Copy source files
COPY src/ ./src/
COPY build.zig ./
COPY build.zig.zon ./

# Build the compiler
RUN zig build -Doptimize=ReleaseSafe

# Stage 2: Runtime stage
FROM alpine:latest

# Install runtime dependencies (only GCC for compiling generated C code)
RUN apk add --no-cache gcc musl-dev

# Create app directory
WORKDIR /app

# Copy the compiled binary from builder stage
COPY --from=builder /app/zig-out/bin/boemia-compiler /usr/local/bin/boemia-compiler

# Create directory for user programs
RUN mkdir -p /workspace

# Set working directory to workspace
WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["boemia-compiler"]

# Default help command
CMD ["--help"]
