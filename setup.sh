#!/bin/bash

# Cross-Platform Development Environment Setup Script
# This script automates the installation and configuration of Docker/Podman, IntelliJ UE.
# Supports: macOS, Linux (Cloudtop/gLinux)

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt user for input
prompt_user() {
    local prompt_text="$1"
    local var_name="$2"
    read -p "$(echo -e "${YELLOW}[PROMPT]${NC} ${prompt_text}"): " "$var_name"
}

# --- OS Detection ---

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ARCH=$(uname -m)
        print_info "Detected macOS on $ARCH architecture"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            VERSION=$VERSION_ID
        fi
        # Check if it's gLinux/Cloudtop
        if command_exists glinux-add-repo; then
            IS_CLOUDTOP=true
            print_info "Detected Cloudtop/gLinux environment"
        else
            IS_CLOUDTOP=false
            print_info "Detected Linux: $DISTRO $VERSION"
        fi
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# --- Main Script Logic ---

# Check for Git
if ! command_exists git; then
    print_error "Git is not installed. Please install it first."
    exit 1
fi

# Initial setup
detect_os
print_section "Starting Development Environment Setup"
print_info "Operating System: $OS"
[[ "$IS_CLOUDTOP" == "true" ]] && print_info "Environment: Cloudtop/gLinux"

# Step 1: System Updates
print_section "System Updates"
if [[ "$OS" == "macos" ]]; then
    print_info "Checking for Homebrew..."
    if ! command_exists brew; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    print_info "Updating Homebrew packages..."
    brew update
elif [[ "$IS_CLOUDTOP" == "true" ]]; then
    print_info "Updating gmac to latest version..."
    if command_exists gmac-updater; then
        gmac-updater
    else
        print_warning "gmac-updater not found. Skipping gmac update."
    fi
    sudo apt update
else
    print_info "Updating system packages..."
    sudo apt update
fi

# Step 2: Install Development Tools
print_section "Development Tools Installation"

# Install IntelliJ
if [[ "$OS" == "macos" ]]; then
    if ! brew list --cask intellij-idea &>/dev/null; then
        print_info "Installing IntelliJ IDEA Ultimate..."
        brew install --cask intellij-idea
    else
        print_info "IntelliJ IDEA is already installed."
    fi
elif [[ "$OS" == "linux" ]]; then
    if ! command_exists intellij-ue-stable && ! command_exists idea && ! snap list | grep -q "intellij-idea-ultimate"; then
        if [[ "$IS_CLOUDTOP" == "true" ]]; then
            print_info "Installing IntelliJ UE..."
            sudo apt install -y intellij-ue-stable
        else
            print_info "Installing IntelliJ IDEA..."
            if command_exists snap; then
                sudo snap install intellij-idea-ultimate --classic
            else
                print_warning "Snap not found. Please install IntelliJ IDEA manually from https://www.jetbrains.com/idea/download/"
            fi
        fi
    else
        print_info "IntelliJ is already installed."
    fi
fi

# Install make/build tools and jq
print_info "Installing build tools and jq..."
if [[ "$OS" == "macos" ]]; then
    xcode-select --install 2>/dev/null || print_info "Xcode command line tools already installed."
    if ! command_exists jq; then brew install jq; else print_info "jq is already installed."; fi
else
    sudo apt install -y build-essential jq
fi

# Step 3: Select and Install Container Runtime
select_container_runtime() {
    if [[ "$IS_CLOUDTOP" == "true" ]]; then
        print_info "Docker is blacklisted on gmac. Would you like to use Podman instead?"
        read -p "$(echo -e "${YELLOW}[PROMPT]${NC} Use Podman? (recommended for gmac) [y/n]"): " use_podman
        if [[ "$use_podman" =~ ^[Yy]$ ]]; then
            CONTAINER_RUNTIME="podman"
        else
            CONTAINER_RUNTIME="docker"
            print_warning "Docker selected on gmac. This may not be supported."
        fi
    else
        print_info "Select container runtime:"
        echo "1) Docker (traditional)"
        echo "2) Podman (rootless, Docker-compatible)"
        read -p "$(echo -e "${YELLOW}[PROMPT]${NC} Enter your choice [1-2]"): " runtime_choice
        case $runtime_choice in
            1) CONTAINER_RUNTIME="docker" ;;
            2) CONTAINER_RUNTIME="podman" ;;
            *) print_error "Invalid choice"; exit 1 ;;
        esac
    fi
    print_info "Selected container runtime: $CONTAINER_RUNTIME"
}

select_container_runtime

print_section "Container Runtime Installation: $CONTAINER_RUNTIME"
# Docker Installation Logic
if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
    if ! command_exists docker; then
        print_info "Installing Docker..."
        if [[ "$OS" == "macos" ]]; then
            print_info "Installing Docker Desktop..."
            brew install --cask docker
            print_warning "Please start Docker Desktop from your Applications folder. The script will continue once it is running."
            until docker info > /dev/null 2>&1; do
                sleep 5
            done
        elif [[ "$OS" == "linux" ]]; then
            # (Assuming standard linux; CloudTop case might need specific gLinux commands)
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            sudo usermod -aG docker $USER
            print_warning "You might need to log out and back in for Docker group changes to take effect."
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
        print_success "Docker installed successfully."
    else
        print_info "Docker is already installed."
    fi
# Podman Installation Logic
elif [[ "$CONTAINER_RUNTIME" == "podman" ]]; then
    if ! command_exists podman; then
        print_info "Installing Podman..."
        if [[ "$OS" == "macos" ]]; then
            brew install podman podman-compose
            podman machine init
            podman machine start
        elif [[ "$OS" == "linux" ]]; then
            sudo apt install -y podman
            # Install podman-compose if needed
            if ! command_exists podman-compose; then
                print_info "Installing podman-compose..."
                sudo apt install -y python3-pip
                pip3 install podman-compose
                export PATH=$PATH:$HOME/.local/bin
                echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
                print_warning "Added podman-compose to PATH. You may need to source your .bashrc or restart your terminal."
            fi
        fi
        print_success "Podman installed successfully."
    else
        print_info "Podman is already installed."
    fi
fi
