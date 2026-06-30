# Makefile - ARM64 Bare-Metal
# Compila utils.s por separado (utils.o) y enlaza cada modulo con el.
# Cumple con la Seccion 11 del PDF: "as utils.s -o utils.o"
#
# Uso:
#   make                          → compila todos los modulos
#   make SRC=modulo_1_media.s run → compila y ejecuta con qemu
#   make SRC=modulo_1_media.s gdb → espera GDB en puerto 1234
#   make clean                    → elimina la carpeta build/ y .txt de resultados

# Detectar arquitectura: en Raspberry Pi usar toolchain nativo
ifeq ($(shell uname -m), aarch64)
AS   = as
LD   = ld
QEMU =
RUN  =
else
AS   = aarch64-linux-gnu-as
LD   = aarch64-linux-gnu-ld
QEMU = qemu-aarch64
RUN  = $(QEMU)
endif

ASFLAGS  = -g
LDFLAGS  =
SRC_DIR  = src
BUILD    = build
GDB_PORT = 1234
ARGS     ?=

MODULES = modulo_1_media modulo_2_varianza modulo_3_anomalias modulo_4_prediccion modulo_5_tendencia
UTILS_O = $(BUILD)/utils.o

.PHONY: all run gdb clean info

all: $(MODULES:%=$(BUILD)/%)

$(BUILD):
	mkdir -p $(BUILD)

# Compilar utils.s por separado → utils.o (Requisito Seccion 11 del PDF)
$(UTILS_O): $(SRC_DIR)/utils.s | $(BUILD)
	$(AS) $(ASFLAGS) $< -o $@

# Regla generica: cada modulo se ensambla y se enlaza con utils.o
$(BUILD)/%: $(SRC_DIR)/%.s $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) $< -o $(BUILD)/$*.o
	$(LD) $(LDFLAGS) $(BUILD)/$*.o $(UTILS_O) -o $@

# Compilar y ejecutar un modulo especifico
# Uso: make SRC=modulo_1_media.s ARGS=4 run
SRC     ?= modulo_1_media.s
PROGRAM := $(basename $(notdir $(SRC)))
TARGET  := $(BUILD)/$(PROGRAM)

run: $(TARGET)
	$(RUN) $(TARGET) $(ARGS)

# Depuracion con GDB: inicia QEMU esperando en puerto 1234
# En Raspberry Pi usar: gdb ./build/modulo_X directamente
gdb: $(TARGET)
	@echo "Iniciando $(TARGET) en modo GDB (puerto $(GDB_PORT))..."
	@echo "En otra terminal: gdb-multiarch $(TARGET) -ex 'target remote :$(GDB_PORT)'"
	$(QEMU) -g $(GDB_PORT) $(TARGET) $(ARGS)

clean:
	rm -rf $(BUILD) resultado_*.txt

info:
	@echo "Uso:"
	@echo "  make                               → compila todos los modulos"
	@echo "  make SRC=modulo_1_media.s ARGS=4 run  → ejecuta con columna 4"
	@echo "  make SRC=modulo_2_varianza.s ARGS=4 gdb → espera GDB en puerto $(GDB_PORT)"
	@echo "  make clean                         → limpia build/ y txt"
	@echo ""
	@echo "NOTA P8: utils.s se compila separado ($(UTILS_O))"
	@echo "        Cada modulo se enlaza con utils.o (Seccion 11 PDF)"
