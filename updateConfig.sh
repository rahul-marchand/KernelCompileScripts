#!/bin/bash
# Smart kernel config updater that only enforces system-specific requirements
# Uses checkVM.sh to detect what's actually needed

CONFIG_FILE=".config"
BACKUP_FILE=".config.backup"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE not found in current directory."
    exit 1
fi

# Create backup
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Get system-specific requirements
echo "Detecting system requirements..."
REQUIRED_CONFIGS=$(./checkVM.sh --parseable | grep "=required" | cut -d'=' -f1)

if [ -z "$REQUIRED_CONFIGS" ]; then
    echo "ERROR: No required configurations detected. Check that checkVM.sh works properly."
    exit 1
fi

echo "Found $(echo "$REQUIRED_CONFIGS" | wc -l) required configurations for this system:"
echo "$REQUIRED_CONFIGS" | sed 's/^/  /'
echo

# Update only the required configurations
echo "Updating $CONFIG_FILE with system-specific requirements..."
config_changed=false

for opt in $REQUIRED_CONFIGS; do
    if grep -q "^$opt=" "$CONFIG_FILE"; then
        # Option already present, enforce =y
        current_value=$(grep "^$opt=" "$CONFIG_FILE" | cut -d'=' -f2)
        if [ "$current_value" != "y" ]; then
            sed -i "s/^$opt=.*/$opt=y/" "$CONFIG_FILE"
            echo "[UPDATED] $opt: $current_value -> y"
            config_changed=true
        else
            echo "[OK] $opt already set to y"
        fi
    elif grep -q "^# $opt is not set" "$CONFIG_FILE"; then
        # Disabled explicitly, flip it on
        sed -i "s/^# $opt is not set/$opt=y/" "$CONFIG_FILE"
        echo "[ENABLED] $opt: disabled -> y"
        config_changed=true
    else
        # Option not found at all, add it
        echo "$opt=y" >> "$CONFIG_FILE"
        echo "[ADDED] $opt=y"
        config_changed=true
    fi
done

if ! $config_changed; then
    echo "No changes needed - all required options already correctly set."
    rm "$BACKUP_FILE"
    exit 0
fi

echo
echo "Running 'make olddefconfig' to resolve dependencies..."
if make olddefconfig; then
    echo "Dependencies resolved successfully."
else
    echo "ERROR: make olddefconfig failed. Restoring backup."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

echo
echo "Validating final configuration..."
validation_failed=false

for opt in $REQUIRED_CONFIGS; do
    if grep -q "^$opt=y" "$CONFIG_FILE"; then
        echo "[✓] $opt is enabled"
    else
        echo "[✗] $opt is NOT enabled (dependency conflict?)"
        validation_failed=true
    fi
done

if $validation_failed; then
    echo
    echo "WARNING: Some required options were disabled during dependency resolution."
    echo "This may indicate config conflicts. Manual review recommended."
    echo
    echo "To see what changed:"
    echo "  diff $BACKUP_FILE $CONFIG_FILE"
    echo
    echo "To restore original config:"
    echo "  cp $BACKUP_FILE $CONFIG_FILE"
    exit 1
else
    echo
    echo "✓ All required configurations are enabled."
    echo "Config update completed successfully."
    rm "$BACKUP_FILE"
fi