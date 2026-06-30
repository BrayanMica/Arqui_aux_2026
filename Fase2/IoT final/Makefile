AS       = aarch64-linux-gnu-as
LD       = aarch64-linux-gnu-ld
QEMU     = qemu-aarch64

BUILD    ?= build
SRC      ?= motor.s
ARGS     ?=

PROGRAM := $(basename $(notdir $(SRC)))
OBJ     := $(BUILD)/$(PROGRAM).o
TARGET  := $(BUILD)/$(PROGRAM)

ASFLAGS ?= -g -I .
LDFLAGS ?=

.PHONY: all run clean

all: $(TARGET)

$(BUILD):
	mkdir -p $(BUILD)

$(OBJ): $(SRC) $(wildcard utils/*.s) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $(SRC)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

run: $(TARGET)
	$(QEMU) $(TARGET) $(ARGS)

clean:
	rm -rf $(BUILD)
