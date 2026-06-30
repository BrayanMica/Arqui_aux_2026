#!/bin/bash
# build_run.sh — Compila y ejecuta un modulo ARM64
# Uso: ./build_run.sh <nombre_del_archivo>

set -e

# 1. Verificar si se proporcionó un nombre
if [ "$#" -ne 1 ]; then
    echo "Error: Falta especificar el nombre del archivo"
    echo "Uso: $0 <nombre_del_archivo>"
    exit 1
fi

# 2. Limpiar el nombre (quita el .s si lo escribiste por costumbre)
BASENAME="${1%.s}"

# 3. Asignar el archivo origen en la misma carpeta
SRC="${BASENAME}.s"

# 4. Verificar que el archivo exista en la carpeta actual
if [ ! -f "$SRC" ]; then
    echo "Error: El archivo '$SRC' no se encuentra en esta carpeta."
    exit 1
fi

AS="aarch64-linux-gnu-as"
LD="aarch64-linux-gnu-ld"
QEMU="qemu-aarch64"

BUILD_DIR="build"

mkdir -p "$BUILD_DIR"

echo "[1/2] Ensamblando $SRC ..."
"$AS" -g -o "$BUILD_DIR/$BASENAME.o" "$SRC"

echo "[2/2] Enlazando ..."
"$LD" -o "$BUILD_DIR/$BASENAME" "$BUILD_DIR/$BASENAME.o"

echo "----------------------------------------"
echo "Ejecutando $BASENAME..."
"$QEMU" "$BUILD_DIR/$BASENAME"
