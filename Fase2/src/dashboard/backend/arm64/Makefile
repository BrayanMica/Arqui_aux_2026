# Makefile - Compilacion de modulos ARM64
# Cada modulo incluye utils.s via .include y se compila como un solo archivo.
#
# Uso:
#   make                          -> compila todos los modulos
#   make clean                    -> elimina build/ y archivos de resultado

ifeq ($(shell uname -m), aarch64)
AS   = as
LD   = ld
QEMU =
else
AS   = aarch64-linux-gnu-as
LD   = aarch64-linux-gnu-ld
QEMU = qemu-aarch64
endif

ASFLAGS  = -g -I src
LDFLAGS  =
SRC_DIR  = src
BUILD    = build
GDB_PORT = 1234

MODULES = modulo_1_media modulo_2_varianza modulo_3_anomalias \
          modulo_4_prediccion modulo_5_tendencia

.PHONY: all clean run gdb info

all: $(MODULES:%=$(BUILD)/%)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%: $(SRC_DIR)/%.s $(SRC_DIR)/utils.s | $(BUILD)
	$(AS) $(ASFLAGS) $< -o $(BUILD)/$*.o
	$(LD) $(LDFLAGS) $(BUILD)/$*.o -o $@

# Ejecutar un modulo especifico
# Uso: make run MOD=modulo_1_media ARGS=6
MOD  ?= modulo_1_media
ARGS ?=
run: $(BUILD)/$(MOD)
	$(QEMU) $(BUILD)/$(MOD) $(ARGS)

# Depuracion con GDB
# Uso: make gdb MOD=modulo_1_media ARGS=6
gdb: $(BUILD)/$(MOD)
	@echo "Iniciando $(BUILD)/$(MOD) en modo GDB (puerto $(GDB_PORT))..."
	@echo "En otra terminal: gdb-multiarch $(BUILD)/$(MOD) -ex 'target remote :$(GDB_PORT)'"
	$(QEMU) -g $(GDB_PORT) $(BUILD)/$(MOD) $(ARGS)

clean:
	rm -rf $(BUILD) resultado_*.txt qemu_*.core

info:
	@echo "Uso:"
	@echo "  make                                    -> compila todos los modulos"
	@echo "  make run MOD=modulo_1_media ARGS=6     -> ejecuta modulo con columna 6"
	@echo "  make gdb MOD=modulo_1_media ARGS=6     -> depura con GDB en puerto $(GDB_PORT)"
	@echo "  make clean                              -> elimina build/ y archivos .txt"
