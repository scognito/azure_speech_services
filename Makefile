# Define variables
HOOKS_DIR := .git/hooks
SOURCE_HOOK := scripts/prepare-commit-msg
TARGET_HOOK := $(HOOKS_DIR)/prepare-commit-msg

# Default target: install hooks, activate-melos
all: install-hooks activate-melos

# Install the prepare-commit-msg hook
install-hooks:
	@echo "Installing Git hooks..."
	@mkdir -p $(HOOKS_DIR)
	@cp $(SOURCE_HOOK) $(TARGET_HOOK)
	@chmod +x $(TARGET_HOOK)
	@echo "Git hooks installed successfully."

# Remove hooks (cleanup)
clean-hooks:
	@echo "Removing Git hooks..."
	@rm -f $(TARGET_HOOK)
	@echo "Git hooks removed."

# Activate melos
activate-melos:
	@echo "Activating melos..."
	@dart pub global activate melos
	@echo "Melos activated successfully."