AS       = as
LD       = ld

BUILD    ?= .
SRC      ?= motor.s

PROGRAM := $(basename $(notdir $(SRC)))
OBJ     := $(BUILD)/$(PROGRAM).o
TARGET  := $(BUILD)/$(PROGRAM)

ASFLAGS ?= -g -I .
LDFLAGS ?=

.PHONY: all run clean

all: $(TARGET)

$(OBJ): $(SRC) $(wildcard utils/*.s)
	$(AS) $(ASFLAGS) -o $@ $(SRC)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

run: $(TARGET)
	sudo python3 main.py

clean:
	rm -f $(OBJ) $(TARGET)
