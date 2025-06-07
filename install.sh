#!/bin/bash
# macOS Installation Script for syspolicy project
# Compatible with both zsh and bash
# No sudo/admin privileges required
# Uses Homebrew instead of conda for Python installation

set -e  # Exit on any error

# Global variables
AUTO_YES=false
PROJECT_DIR="${HOME}/.local/share/src/syspolicy"  # Default project directory, can be customized

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [-h|--help]"
            echo "  -y, --yes    Skip all prompts and install automatically"
            echo "  -h, --help   Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PROJECT_DIR  Custom project directory (default: ~/.local/share/src/syspolicy)"
            echo ""
            echo "Examples:"
            echo "  # Use default directory"
            echo "  $0"
            echo ""
            echo "  # Use custom directory"
            echo "  PROJECT_DIR=~/my-projects/syspolicy $0"
            echo ""
            echo "  # Auto-install with custom directory"
            echo "  PROJECT_DIR=~/my-projects/syspolicy $0 -y"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt user for confirmation
prompt_user() {
    local message="$1"
    if [ "$AUTO_YES" = true ]; then
        print_status "$message (auto-confirmed with -y flag)"
        return 0
    fi
    
    echo -n -e "${YELLOW}[PROMPT]${NC} $message [Y/n]: "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]|"")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to detect architecture and set Homebrew prefix
detect_homebrew_prefix() {
    if [[ $(uname -m) == "arm64" ]]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

# Function to check if Homebrew is installed
check_homebrew() {
    local homebrew_prefix=$(detect_homebrew_prefix)
    if [ -f "${homebrew_prefix}/bin/brew" ]; then
        echo "${homebrew_prefix}/bin/brew"
        return 0
    elif command_exists brew; then
        echo "brew"
        return 0
    else
        return 1
    fi
}

# Function to install Homebrew
install_homebrew() {
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    local homebrew_prefix=$(detect_homebrew_prefix)
    if [ -f "${homebrew_prefix}/bin/brew" ]; then
        export PATH="${homebrew_prefix}/bin:$PATH"
        print_success "Homebrew installed successfully!"
        return 0
    else
        print_error "Homebrew installation failed!"
        return 1
    fi
}

# Function to check Python 3.13 installation
check_python313() {
    local homebrew_prefix=$(detect_homebrew_prefix)
    local python_path="${homebrew_prefix}/bin/python3.13"
    
    if [ -f "$python_path" ]; then
        local version=$("$python_path" --version 2>&1)
        if [[ "$version" =~ Python\ 3\.13\. ]]; then
            echo "$python_path"
            return 0
        fi
    fi
    
    # Check if python3.13 is in PATH
    if command_exists python3.13; then
        local version=$(python3.13 --version 2>&1)
        if [[ "$version" =~ Python\ 3\.13\. ]]; then
            echo "python3.13"
            return 0
        fi
    fi
    
    return 1
}

# Function to get Python 3.13 installation info for display
get_python313_info() {
    local homebrew_prefix=$(detect_homebrew_prefix)
    local python_path="${homebrew_prefix}/bin/python3.13"
    
    if [ -f "$python_path" ]; then
        local version=$("$python_path" --version 2>&1)
        if [[ "$version" =~ Python\ 3\.13\. ]]; then
            print_success "Found Python 3.13: $version"
            return 0
        fi
    fi
    
    # Check if python3.13 is in PATH
    if command_exists python3.13; then
        local version=$(python3.13 --version 2>&1)
        if [[ "$version" =~ Python\ 3\.13\. ]]; then
            print_success "Found Python 3.13 in PATH: $version"
            return 0
        fi
    fi
    
    return 1
}

# Function to check pip3 availability
check_pip3() {
    local homebrew_prefix=$(detect_homebrew_prefix)
    local pip3_path="${homebrew_prefix}/bin/pip3"
    
    if [ -f "$pip3_path" ]; then
        echo "$pip3_path"
        return 0
    elif command_exists pip3; then
        echo "pip3"
        return 0
    else
        return 1
    fi
}

# Function to download and extract repository using git clone or fallback to zip download
setup_syspolicy_repo() {
    local repo_url="https://github.com/0x0FFF0/macrig.git"
    local repo_zip_url="https://github.com/0x0FFF0/macrig/archive/refs/heads/main.zip"
    local work_dir=$(dirname "$PROJECT_DIR")
    local repo_dir="$PROJECT_DIR"
    
    print_status "Target project directory: $repo_dir"
    
    # Create working directory if it doesn't exist
    if [ ! -d "$work_dir" ]; then
        print_status "Creating working directory: $work_dir"
        mkdir -p "$work_dir"
    fi
    
    # Check if project directory already exists
    if [ -d "$repo_dir" ]; then
        print_warning "Directory $repo_dir already exists"
        if prompt_user "Remove existing project directory and download fresh copy?"; then
            print_status "Removing existing project directory..."
            rm -rf "$repo_dir"
        else
            print_status "Using existing project directory..."
            cd "$repo_dir"
            return 0
        fi
    fi
    
    # Change to working directory
    cd "$work_dir"
    
    # Method 1: Try git clone first
    if command_exists git; then
        print_status "Attempting to clone repository using git..."
        if git clone "$repo_url" "$(basename "$repo_dir")"; then
            print_success "Repository cloned successfully using git!"
            cd "$repo_dir"
            
            # Show git information
            print_status "Git repository information:"
            echo "  - Repository URL: $repo_url"
            echo "  - Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
            echo "  - Latest commit: $(git log --oneline -1 2>/dev/null || echo 'unknown')"
            
            return 0
        else
            print_warning "Git clone failed, falling back to zip download method..."
        fi
    else
        print_warning "Git is not installed, using zip download method..."
    fi
    
    # Method 2: Fallback to downloading zip file
    print_status "Downloading repository as zip file..."
    local zip_filename="macrig-main.zip"
    
    if command_exists curl; then
        if ! curl -L -o "$zip_filename" "$repo_zip_url"; then
            print_error "Failed to download repository zip file!"
            print_error "Please check the repository URL and your internet connection."
            return 1
        fi
    elif command_exists wget; then
        if ! wget -O "$zip_filename" "$repo_zip_url"; then
            print_error "Failed to download repository zip file!"
            print_error "Please check the repository URL and your internet connection."
            return 1
        fi
    else
        print_error "Neither curl nor wget is available. Cannot download repository."
        return 1
    fi
    
    # Extract the repository
    print_status "Extracting repository from zip file..."
    if command_exists unzip; then
        if ! unzip -q "$zip_filename"; then
            print_error "Failed to extract zip file!"
            return 1
        fi
        
        # Find the extracted directory (it might be named macrig-main or similar)
        local extracted_dir=""
        for dir in macrig-* macrig; do
            if [ -d "$dir" ]; then
                extracted_dir="$dir"
                break
            fi
        done
        
        if [ -n "$extracted_dir" ]; then
            mv "$extracted_dir" "$(basename "$repo_dir")"
            print_success "Repository extracted to $repo_dir"
        else
            print_error "Could not find extracted directory!"
            return 1
        fi
        
        # Clean up zip file
        rm -f "$zip_filename"
        
        # Change to project directory
        cd "$repo_dir"
        
        print_status "Repository downloaded and extracted successfully!"
        
    else
        print_error "unzip command not found. Cannot extract repository."
        return 1
    fi
}

# Function to create syspolicy script
create_syspolicy_script() {
    local python_cmd="$1"
    local script_dir="$HOME/.local/bin"
    local script_path="$script_dir/syspolicy"
    
    print_status "Creating syspolicy script..."
    
    # Create script directory if it doesn't exist
    if [ ! -d "$script_dir" ]; then
        print_status "Creating script directory: $script_dir"
        mkdir -p "$script_dir"
    fi
    
    # Create the script file with clean content
    print_status "Writing syspolicy script to: $script_path"
    cat > "$script_path" << 'EOF'
#!/bin/bash
# syspolicy wrapper script
cd ~/.local/share/src/syspolicy && PYTHON_CMD syspolicy.py "$@"
EOF
    
    # Replace PYTHON_CMD placeholder with actual python command
    sed -i.bak "s|PYTHON_CMD|$python_cmd|g" "$script_path"
    rm -f "$script_path.bak"
    
    # Make the script executable
    chmod +x "$script_path"
    print_success "Created executable syspolicy script at: $script_path"
    
    # Add ~/.local/bin to PATH if not already present
    local shell_rc=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if PATH export already exists
    if [ -f "$shell_rc" ] && grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$shell_rc"; then
        print_status "PATH already includes ~/.local/bin in $shell_rc"
    else
        print_status "Adding ~/.local/bin to PATH in $shell_rc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        print_success "Added ~/.local/bin to PATH in $shell_rc"
    fi
    
    # Export PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    print_success "Added ~/.local/bin to current session PATH"
    
    return 0
}

# Main installation function
main() {
    print_status "Starting macOS installation script for syspolicy project..."
    print_status "Using Homebrew for Python 3.13 installation"
    
    local homebrew_prefix=$(detect_homebrew_prefix)
    print_status "Detected architecture: $(uname -m)"
    print_status "Homebrew prefix: $homebrew_prefix"
    
    # Check if Homebrew is installed
    BREW_CMD=""
    if BREW_CMD=$(check_homebrew); then
        print_success "Homebrew is already installed"
        print_status "Brew command: $BREW_CMD"
    else
        if ! prompt_user "Homebrew is not installed. Install Homebrew now?"; then
            print_error "Homebrew installation declined. Cannot proceed without Homebrew."
            exit 1
        fi
        
        if ! install_homebrew; then
            exit 1
        fi
        
        # Re-check after installation
        if BREW_CMD=$(check_homebrew); then
            print_status "Brew command: $BREW_CMD"
        else
            print_error "Homebrew installation verification failed!"
            exit 1
        fi
    fi
    
    # Update Homebrew
    if ! prompt_user "Update Homebrew before installing Python?"; then
        print_status "Skipping Homebrew update..."
    else
        print_status "Updating Homebrew..."
        $BREW_CMD update
        print_success "Homebrew updated successfully!"
    fi
    
    # Check if Python 3.13 is installed
    PYTHON_CMD=""
    if PYTHON_CMD=$(check_python313); then
        get_python313_info
        print_success "Python 3.13 is already installed"
        print_status "Python command: $PYTHON_CMD"
    else
        if ! prompt_user "Install Python 3.13 using Homebrew?"; then
            print_error "Python 3.13 installation declined. Cannot proceed without Python 3.13."
            exit 1
        fi
        
        print_status "Installing Python 3.13..."
        $BREW_CMD install python@3.13
        
        # Verify installation
        if PYTHON_CMD=$(check_python313); then
            get_python313_info
            print_success "Python 3.13 installed successfully!"
            print_status "Python command: $PYTHON_CMD"
        else
            print_error "Python 3.13 installation verification failed!"
            exit 1
        fi
    fi
    
    # Check pip3 availability
    PIP3_CMD=""
    if PIP3_CMD=$(check_pip3); then
        print_success "pip3 is available"
        print_status "pip3 command: $PIP3_CMD"
    else
        print_error "pip3 is not available! This should be installed with Python 3.13."
        exit 1
    fi
    
    # Set up project repository
    if ! prompt_user "Download and set up project repository?"; then
        print_warning "Repository setup skipped."
    else
        if ! setup_syspolicy_repo; then
            print_error "Failed to set up project repository!"
            exit 1
        fi
        print_success "Project repository set up successfully!"
        print_status "Working directory: $(pwd)"
    fi
    
    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        print_warning "requirements.txt not found in current directory!"
        print_status "Current directory: $(pwd)"
        print_status "Looking for requirements.txt..."
        
        # Try to find requirements.txt in common locations
        local req_file=""
        for file in "requirements.txt" "./requirements.txt" "../requirements.txt"; do
            if [ -f "$file" ]; then
                req_file="$file"
                break
            fi
        done
        
        if [ -n "$req_file" ]; then
            print_success "Found requirements.txt at: $req_file"
        else
            print_error "Could not find requirements.txt file!"
            print_status "Please ensure requirements.txt exists in the project directory."
            exit 1
        fi
    else
        req_file="requirements.txt"
    fi
    
    # Install Python dependencies
    if ! prompt_user "Install Python dependencies from requirements.txt?"; then
        print_warning "Dependency installation skipped."
    else
        print_status "Installing Python dependencies from $req_file..."
        
        # Use pip3 to install requirements
        $PIP3_CMD install -r "$req_file"
        
        print_success "Dependencies installed successfully!"
    fi
    
    # Create syspolicy script
    print_status "Setting up syspolicy command-line script..."
    if ! create_syspolicy_script "$PYTHON_CMD"; then
        print_error "Failed to create syspolicy script!"
        exit 1
    fi
    
    # Change to project directory
    print_status "Changing to project directory: $PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Check if main application files exist and provide instructions
    local main_files=("syspolicy.py" "main.py" "app.py" "run.py")
    local found_main=""
    
    for file in "${main_files[@]}"; do
        if [ -f "$file" ]; then
            found_main="$file"
            break
        fi
    done
    
    print_success "Installation completed successfully!"
    echo
    print_status "Installation summary:"
    echo "  - Homebrew prefix: $homebrew_prefix"
    echo "  - Brew command: $BREW_CMD"
    echo "  - Python command (brew-managed): $PYTHON_CMD"
    echo "  - pip3 command: $PIP3_CMD"
    echo "  - Project directory: $PROJECT_DIR"
    echo "  - Script directory: $HOME/.local/bin"
    echo
    
    if [ -n "$found_main" ]; then
        print_success "Found main application file: $found_main"
        print_status "You can now run the application using:"
        echo -e "  ${GREEN}syspolicy${NC} (from anywhere)"
        echo -e "  ${GREEN}cd $PROJECT_DIR && python3 $found_main${NC}"
        echo
    else
        print_warning "No main application file found in current directory."
        print_status "Available Python files:"
        if ls *.py >/dev/null 2>&1; then
            for py_file in *.py; do
                echo "  - $py_file"
            done
        else
            echo "  - No Python files found"
        fi
        echo
    fi
    
    print_status "Next steps:"
    echo -e "  1. Restart your terminal or run: ${GREEN}source ~/.zshrc${NC} (or ~/.bashrc)"
    echo -e "  2. Run your application: ${GREEN}syspolicy${NC}"
    echo -e "  3. Or navigate to project: ${GREEN}cd $PROJECT_DIR${NC}"
    echo
    print_status "Current working directory: $(pwd)"
}

# Run main function
main "$@"
