#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Get the actual user who ran sudo
REAL_USER=$(who am i | awk '{print $1}')
REAL_HOME=$(eval echo ~$REAL_USER)

# Define paths
VENV_DIR="$REAL_HOME/.claudius_env"
CONFIG_DIR="$REAL_HOME/.config/claudius"
SCRIPT_NAME="claudius"
INSTALL_DIR="/usr/local/bin"

echo "Installing for user: $REAL_USER"
echo "Home directory: $REAL_HOME"
echo "Virtual env directory: $VENV_DIR"

# Check if source script exists
if [ ! -f "$(pwd)/claudius" ]; then
    echo "Error: Source script 'claudius' not found in current directory"
    echo "Current directory: $(pwd)"
    echo "Files in current directory:"
    ls -la
    exit 1
fi

# Remove existing installation if present
echo "Cleaning up any existing installation..."
rm -rf "$VENV_DIR"
rm -f "$INSTALL_DIR/$SCRIPT_NAME"

# Create directories and set ownership
echo "Creating directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$VENV_DIR"
mkdir -p "$VENV_DIR/bin"
chown -R $REAL_USER:$(id -gn $REAL_USER) "$CONFIG_DIR"
chown -R $REAL_USER:$(id -gn $REAL_USER) "$VENV_DIR"
echo "Setting permissions for config directory..."
chmod 755 "$CONFIG_DIR"
chown -R $REAL_USER:$(id -gn $REAL_USER) "$CONFIG_DIR"

# Create virtual environment
echo "Creating virtual environment..."
sudo -H -u $REAL_USER python3 -m venv "$VENV_DIR"

# Install required packages
echo "Installing required packages..."
sudo -H -u $REAL_USER bash -c "source $VENV_DIR/bin/activate && pip install anthropic rich pyperclip python-dotenv PyYAML"

# Copy main script with verbose output
echo "Installing main script..."
echo "Source script location: $(pwd)/claudius"
echo "Destination: $VENV_DIR/bin/claudius_script"
cp -v "$(pwd)/claudius" "$VENV_DIR/bin/claudius_script"

if [ $? -ne 0 ]; then
    echo "Error: Failed to copy script"
    exit 1
fi

echo "Setting permissions..."
chmod +x "$VENV_DIR/bin/claudius_script"
chown $REAL_USER:$(id -gn $REAL_USER) "$VENV_DIR/bin/claudius_script"

# Create wrapper script with absolute paths
echo "Creating launcher script..."
cat > "$INSTALL_DIR/$SCRIPT_NAME" << EOL
#!/bin/bash
source "$VENV_DIR/bin/activate"
"$VENV_DIR/bin/python" "$VENV_DIR/bin/claudius_script"
deactivate
EOL

# Set permissions for wrapper script
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
chown $REAL_USER:$(id -gn $REAL_USER) "$INSTALL_DIR/$SCRIPT_NAME"

echo "Verifying installation..."
echo "Contents of $VENV_DIR/bin:"
ls -la "$VENV_DIR/bin"

if [ -f "$VENV_DIR/bin/claudius_script" ]; then
    echo "Main script installed successfully"
else
    echo "Error: Main script not installed"
    exit 1
fi

if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    echo "Wrapper script installed successfully"
else
    echo "Error: Wrapper script not installed"
    exit 1
fi

echo "Installation complete! You can now run 'claudius' from anywhere."
