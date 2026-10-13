BUILD_DIR := build
BIN_DIR := bin

.PHONY: clean

release:
	@cmake -B$(BUILD_DIR)/release -DCMAKE_BUILD_TYPE=Release
	@cmake --build $(BUILD_DIR)/release --parallel 4
	@mkdir -p $(BIN_DIR)
	@cp $(BUILD_DIR)/release/superfamiconv $(BIN_DIR)/

debug:
	@cmake -B$(BUILD_DIR)/debug -DCMAKE_BUILD_TYPE=Debug
	@cmake --build $(BUILD_DIR)/debug --parallel 4
	@mkdir -p $(BIN_DIR)
	@cp $(BUILD_DIR)/debug/superfamiconv $(BIN_DIR)/

all: clean release

clean:
	@rm -rf $(BUILD_DIR) $(BIN_DIR)
