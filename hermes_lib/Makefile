# -----------------------------------------------------------------------------
# Hermes Library Makefile - FINAL CORRECTED VERSION (with robust prep)
# -----------------------------------------------------------------------------

# Compiler
ZIG := zig

# Paths
SRC_DIR := src
OUT_DIR := ../include
SRC     := $(SRC_DIR)/main.zig
HEADER  := $(OUT_DIR)/hermes.h

# Common Libs (We only include -lc and -lenet, as requested)
LIBS    := -lc -lenet

# Detect OS
ifeq ($(OS),Windows_NT)
    PLATFORM := Windows
    LIB_NAME := hermes.dll
    RM := del /Q /F
    MKDIR := mkdir
else
    UNAME_S := $(shell uname -s)
    RM := rm -f
    MKDIR := mkdir -p # Note: mkdir -p is used for Unix/Linux/Mac
    
    ifeq ($(UNAME_S),Linux)
        PLATFORM := Linux
        LIB_NAME := libhermes.so
    endif
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := macOS
        LIB_NAME := libhermes.dylib
        # FIX: Added Homebrew path for Apple Silicon
        ZIG_LDFLAGS := -L/opt/homebrew/lib
    endif
endif

ZIG_LDFLAGS ?=

# Full path to the output binary
BINARY := $(OUT_DIR)/$(LIB_NAME)

# -----------------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------------

.PHONY: all clean prep info

all: $(BINARY)

# NEW: The 'prep' target ensures all necessary directories exist using the 
# platform-specific command defined above.
prep:
	@echo "Running preparation step: Ensuring directory $(OUT_DIR) exists."
	@$(MKDIR) $(OUT_DIR) 2> /dev/null || true

# The binary now depends on the source and the 'prep' step.
$(BINARY): $(SRC) prep
	@echo "Building for $(PLATFORM)..."
	$(ZIG) build-lib $(SRC) -dynamic -femit-h=$(HEADER) -femit-bin=$(BINARY) $(LIBS) $(ZIG_LDFLAGS)
	@echo "✅ SUCCESS! Library built at: $(BINARY)"
	@echo "✅ Header generated at: $(HEADER)"

# Clean up generated files
clean:
	@echo "Cleaning up $(LIB_NAME) and $(HEADER)..."
	-$(RM) $(BINARY)
	-$(RM) $(HEADER)
	-$(RM) -r zig-cache zig-out
