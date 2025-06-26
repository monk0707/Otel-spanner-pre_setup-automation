Cross-Platform Development Environment Setup Script
This script automates the installation and configuration of essential development tools, including Docker or Podman for containerization and IntelliJ IDEA Ultimate Edition. It's designed to provide a consistent setup experience across different operating systems.
Supported Operating Systems
macOS: Uses Homebrew for package management.

Linux:

Standard Debian/Ubuntu-based distributions: Uses apt and snap (if available).

Google Cloudtop/gLinux environments: Includes specific checks and recommendations for gmac-updater and Podman due to Docker restrictions.

Steps for executing the script : 
step1 : Make the script executable: chmod +x setup_dev_env.sh
step2 : Run the script : ./setup.sh