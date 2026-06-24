#!/usr/bin/env bash

# ==============================================================================
# INSTALL SCRIPT
# ==============================================================================

# --- COLORS ---
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[0;34m'
CYAN='\e[0;36m'
BOLD='\e[1m'
DIM='\e[2m'
RESET='\e[0m'

# --- GLOBALS ---
RESULTS=()          # Collects pass/fail for every task
TOTAL_STEPS=0       # Will be set before running tasks
CURRENT_STEP=0      # Tracks progress bar position

# ==============================================================================
# CONFIG — Edit this section to personalise the script
# ==============================================================================

DOTFILES_REPO="https://github.com/Tigrjas/test"
DOTFILES_DIR="$HOME/Projects/dotfiles"

# Packages to install on each distro.
# Add or remove names from these arrays.
ARCH_PACKAGES=(
    git
    neovim
    wget
    curl
    niri
    waybar
)

FEDORA_PACKAGES=(
    git
    neovim
    wget
    curl
)

DEBIAN_PACKAGES=(
    git
    neovim
    wget
    curl
)

# Dotfiles to copy after cloning the repo.
# Format: "source_in_repo:destination_on_system"
# ~ and $HOME both work in the destination.
DOTFILE_LINKS=(
    "niri/config.kdl:$HOME/.config/niri/config.kdl"
    "waybar/config.jsonc:$HOME/.config/waybar/config.jsonc"
    "nvim:$HOME/.config/nvim"
)

# ==============================================================================
# PROGRESS BAR
# ==============================================================================

# Call this once at the start of your task run to set the total
init_progress() {
    TOTAL_STEPS=$1
    CURRENT_STEP=0
}

# Call this before each task to advance the bar
draw_progress() {
    local description="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    local bar_width=40
    local filled=$(( (CURRENT_STEP * bar_width) / TOTAL_STEPS ))
    local empty=$(( bar_width - filled ))

    # Build the filled and empty portions of the bar
    local bar_filled=""
    local bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled+="█"; done
    for ((i=0; i<empty; i++));  do bar_empty+="░"; done

    local percent=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))

    # \r returns to start of line so we overwrite it each time
    printf "\r  ${CYAN}[${bar_filled}${DIM}${bar_empty}${RESET}${CYAN}]${RESET} ${percent}%% — ${DIM}${description}${RESET}     "
}

finish_progress() {
    printf "\n"
}

# ==============================================================================
# TASK RUNNER
# Runs a command, tracks success/failure, and updates the progress bar.
# Usage: run_task "Description" "command --flags"
# ==============================================================================

run_task() {
    local description="$1"
    local command="$2"

    draw_progress "$description"

    # Run the command. Redirect all output to a log file so the terminal
    # stays clean. We can review the log if something fails.
    eval "$command" >> /tmp/install_log.txt 2>&1

    if [[ $? -eq 0 ]]; then
        RESULTS+=("SUCCESS:$description")
    else
        RESULTS+=("FAILED:$description")
    fi
}

# ==============================================================================
# SYSTEM DETECTION
# ==============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_ID_LIKE="$ID_LIKE"
    else
        OS_NAME="Unknown Linux"
        OS_ID="unknown"
        OS_ID_LIKE=""
    fi
}

detect_ram() {
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM=$(echo "scale=1; $ram_kb / 1048576" | bc)"GB"
}

detect_desktop() {
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        DESKTOP="$XDG_CURRENT_DESKTOP"
    elif [[ -n "$DESKTOP_SESSION" ]]; then
        DESKTOP="$DESKTOP_SESSION"
    elif [[ -n "$WAYLAND_DISPLAY" ]]; then
        DESKTOP="Wayland session"
    else
        DESKTOP="TTY / None"
    fi
}

detect_cpu() {
    CPU=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ //')
}

detect_shell() {
    SHELL_NAME=$(basename "$SHELL")
}

# ==============================================================================
# BANNER + SYSTEM INFO SCREEN
# ==============================================================================

print_banner() {
    clear
    printf "${CYAN}${BOLD}"
    printf "╔══════════════════════════════════════════════════════╗\n"
    printf "║           SYSTEM CONFIGURATION INSTALLER            ║\n"
    printf "╚══════════════════════════════════════════════════════╝\n"
    printf "${RESET}\n"

    printf "${BOLD}  System Scan Results:${RESET}\n"
    printf "  ─────────────────────────────────────────────────────\n"
    printf "  ${GREEN}%-20s${RESET} %s\n" "OS:"      "$OS_NAME"
    printf "  ${GREEN}%-20s${RESET} %s\n" "Distro ID:"  "$OS_ID"
    printf "  ${GREEN}%-20s${RESET} %s\n" "Based on:"   "${OS_ID_LIKE:-N/A}"
    printf "  ${GREEN}%-20s${RESET} %s\n" "RAM:"     "$RAM"
    printf "  ${GREEN}%-20s${RESET} %s\n" "CPU:"     "$CPU"
    printf "  ${GREEN}%-20s${RESET} %s\n" "Desktop:" "$DESKTOP"
    printf "  ${GREEN}%-20s${RESET} %s\n" "Shell:"   "$SHELL_NAME"
    printf "  ─────────────────────────────────────────────────────\n"
    printf "\n"
}

# ==============================================================================
# OS BRANCHING
# These functions figure out which distro family we're on.
# ==============================================================================

# Returns true if we're on an Arch-based system
is_arch()   { [[ "$OS_ID" == "arch"   || "$OS_ID_LIKE" =~ "arch"   ]]; }
is_fedora() { [[ "$OS_ID" == "fedora" || "$OS_ID_LIKE" =~ "fedora" ]]; }
is_debian() { [[ "$OS_ID" == "debian" || "$OS_ID_LIKE" =~ "debian" || "$OS_ID_LIKE" =~ "ubuntu" ]]; }

# ==============================================================================
# TASKS
# Each function below is one "phase" of the install.
# ==============================================================================

task_update() {
    printf "  ${BOLD}[1/4] Updating system...${RESET}\n"

    if is_arch; then
        run_task "Update package database" "sudo pacman -Sy --noconfirm"
        run_task "Upgrade installed packages" "sudo pacman -Su --noconfirm"
    elif is_fedora; then
        run_task "Upgrade system" "sudo dnf upgrade -y"
    elif is_debian; then
        run_task "Update package lists" "sudo apt-get update"
        run_task "Upgrade installed packages" "sudo apt-get upgrade -y"
    fi
}

task_install_packages() {
    printf "\n  ${BOLD}[2/4] Installing packages...${RESET}\n"

    if is_arch; then
        for pkg in "${ARCH_PACKAGES[@]}"; do
            run_task "Install $pkg" "sudo pacman -S --noconfirm --needed $pkg"
        done
    elif is_fedora; then
        for pkg in "${FEDORA_PACKAGES[@]}"; do
            run_task "Install $pkg" "sudo dnf install -y $pkg"
        done
    elif is_debian; then
        for pkg in "${DEBIAN_PACKAGES[@]}"; do
            run_task "Install $pkg" "sudo apt-get install -y $pkg"
        done
    fi
}

task_clone_dotfiles() {
    printf "\n  ${BOLD}[3/4] Cloning dotfiles...${RESET}\n"

    if [[ -d "$DOTFILES_DIR" ]]; then
        # Already cloned — just pull latest changes
        run_task "Pull latest dotfiles" "git -C $DOTFILES_DIR pull"
    else
        run_task "Clone dotfiles repo" "git clone $DOTFILES_REPO $DOTFILES_DIR"
    fi
}

task_copy_configs() {
    printf "\n  ${BOLD}[4/4] Copying configs...${RESET}\n"

    for entry in "${DOTFILE_LINKS[@]}"; do
        # Split "source:destination" on the colon
        local src="${entry%%:*}"        # everything before the first :
        local dst="${entry##*:}"        # everything after the last :
        local full_src="$DOTFILES_DIR/$src"

        # Create the destination directory if it doesn't exist
        mkdir -p "$(dirname "$dst")"

        run_task "Copy $src" "cp -r $full_src $dst"
    done
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================

print_report() {
    printf "\n"
    printf "  ${BOLD}╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${BOLD}║                   INSTALL REPORT                   ║${RESET}\n"
    printf "  ${BOLD}╚══════════════════════════════════════════════════════╝${RESET}\n\n"

    local passed=0
    local failed=0

    for result in "${RESULTS[@]}"; do
        local status="${result%%:*}"      # Part before the first :
        local message="${result#*:}"      # Part after the first :

        if [[ "$status" == "SUCCESS" ]]; then
            printf "  ${GREEN}✓${RESET}  %s\n" "$message"
            passed=$((passed + 1))
        else
            printf "  ${RED}✗${RESET}  %s\n" "$message"
            failed=$((failed + 1))
        fi
    done

    printf "\n  ─────────────────────────────────────────────────────\n"
    printf "  ${GREEN}%-10s${RESET} %d\n" "Passed:"  "$passed"
    printf "  ${RED}%-10s${RESET} %d\n"   "Failed:"  "$failed"

    if [[ $failed -gt 0 ]]; then
        printf "\n  ${YELLOW}See /tmp/install_log.txt for details on failures.${RESET}\n"
    fi

    printf "\n"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    # Clear the log from any previous run
    > /tmp/install_log.txt

    # Detect everything first
    detect_os
    detect_ram
    detect_desktop
    detect_cpu
    detect_shell

    # Show the info screen
    print_banner

    # Confirm before doing anything
    printf "  Proceed with setup? [y/N] "
    read -r response
    printf "\n"

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        printf "  ${YELLOW}Aborted.${RESET}\n\n"
        exit 0
    fi

    # Count total steps so the progress bar knows the full width.
    # 2 update steps + packages + 1 clone + configs
    local pkg_count
    if is_arch;   then pkg_count=${#ARCH_PACKAGES[@]}
    elif is_fedora; then pkg_count=${#FEDORA_PACKAGES[@]}
    elif is_debian; then pkg_count=${#DEBIAN_PACKAGES[@]}
    else pkg_count=0; fi

    local total=$(( 2 + pkg_count + 1 + ${#DOTFILE_LINKS[@]} ))
    init_progress $total

    # Run each phase
    task_update
    finish_progress

    task_install_packages
    finish_progress

    task_clone_dotfiles
    finish_progress

    task_copy_configs
    finish_progress

    # Show the report
    print_report
}

main
