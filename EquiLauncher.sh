#!/bin/bash

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# --- OS & Architecture Detection ---
OS="$(uname -s)"
ARCH="$(uname -m)"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
WORK_DIR="$HOME/.local/share/EquiLauncher"
LOG_PATH="$(cd "$(dirname "$0")" && pwd)/EquiLauncher_Debug.log"

if [ "$OS" = "Darwin" ]; then
    DISCORD_DIR="$HOME/Library/Application Support/discord"
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.equilauncher.startup.plist"
elif [ "$OS" = "Linux" ]; then
    DISCORD_DIR="$HOME/.config/discord"
    AUTOSTART_DIR="$HOME/.config/autostart"
    AUTOSTART_DESKTOP="$AUTOSTART_DIR/equilauncher.desktop"
else
    echo -e "${RED}[ERROR] Operating system $OS is not supported by this script.${NC}"
    exit 1
fi

mkdir -p "$WORK_DIR"

# --- Helper: Find index.js ---
find_discord_index() {
    if [ ! -d "$DISCORD_DIR" ]; then
        return 1
    fi
    # Search for index.js in modules/discord_desktop_core
    find "$DISCORD_DIR" -name "index.js" 2>/dev/null | grep "discord_desktop_core" | head -n 1
}

# --- Helper: Download tool ---
download_file() {
    local url="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -L -sS "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        echo -e "${RED}[ERROR] curl or wget is required for downloading.${NC}"
        return 1
    fi
}

# --- Helper: Kill Discord ---
kill_discord() {
    echo -e "${MAGENTA}[*] Stopping Discord if running...${NC}"
    if [ "$OS" = "Darwin" ]; then
        pkill -x "Discord" 2>/dev/null
        sleep 1
    elif [ "$OS" = "Linux" ]; then
        pkill -I -f "discord" 2>/dev/null
        sleep 1
    fi
}

discord_is_running() {
    if [ "$OS" = "Darwin" ]; then
        pgrep -x "Discord" >/dev/null 2>&1
    else
        pgrep -f "[d]iscord" >/dev/null 2>&1
    fi
}

confirm_restart_for_repair() {
    local mod="$1"
    local message="Мод $mod отключился после обновления Discord. Перезапустить Discord сейчас, чтобы восстановить мод?"

    if [ "$OS" = "Darwin" ]; then
        osascript -e "display dialog \"$message\" with title \"EquiLauncher — требуется восстановление\" buttons {\"Отложить\", \"Перезапустить сейчас\"} default button \"Отложить\" with icon caution" 2>/dev/null | grep -q "Перезапустить сейчас"
    elif command -v zenity >/dev/null 2>&1; then
        zenity --question --title="EquiLauncher — требуется восстановление" --text="$message" --ok-label="Перезапустить сейчас" --cancel-label="Отложить"
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --warningyesno "$message" --title "EquiLauncher — требуется восстановление" --yes-label "Перезапустить сейчас" --no-label "Отложить"
    else
        command -v notify-send >/dev/null 2>&1 && notify-send -u critical "EquiLauncher — требуется восстановление" "$message Откройте EquiLauncher вручную, когда будет удобно."
        return 1
    fi
}

# --- Helper: Launch Discord ---
launch_discord() {
    echo -e "${BLUE}[*] Launching Discord...${NC}"
    if [ "$OS" = "Darwin" ]; then
        open -a "Discord"
    elif [ "$OS" = "Linux" ]; then
        if command -v flatpak >/dev/null 2>&1 && flatpak list | grep -q "com.discordapp.Discord"; then
            flatpak run com.discordapp.Discord &
        elif command -v discord >/dev/null 2>&1; then
            discord &
        elif [ -f "/usr/bin/discord" ]; then
            /usr/bin/discord &
        elif [ -f "/usr/share/discord/Discord" ]; then
            /usr/share/discord/Discord &
        else
            echo -e "${YELLOW}[!] Could not find discord executable in standard paths. Please run it manually.${NC}"
        fi
    fi
}

# --- Install Equicord ---
install_equicord() {
    local non_disruptive="${1:-false}"
    local discord_was_running=false
    if discord_is_running; then
        discord_was_running=true
    fi
    local index_file
    index_file="$(find_discord_index)"
    
    if [ -z "$index_file" ] || [ ! -f "$index_file" ]; then
        echo -e "${RED}[ERROR] Discord installation not found or index.js missing!${NC}"
        return 1
    fi

    if ! grep -q "Equicord" "$index_file"; then
        echo -e "${MAGENTA}[!] Patch missing. Recovering...${NC}"
        
        local exe=""
        if [ "$OS" = "Darwin" ]; then
            if [ "$ARCH" = "arm64" ]; then
                exe="$WORK_DIR/EquilotlCli-darwin-arm64"
                local url="https://github.com/Equicord/Equilotl/releases/latest/download/EquilotlCli-darwin-arm64"
            else
                exe="$WORK_DIR/EquilotlCli-darwin-x64"
                local url="https://github.com/Equicord/Equilotl/releases/latest/download/EquilotlCli-darwin-x64"
            fi
        else
            exe="$WORK_DIR/EquilotlCli-linux"
            local url="https://github.com/Equicord/Equilotl/releases/latest/download/EquilotlCli-linux"
        fi

        if [ ! -f "$exe" ]; then
            echo -e "${CYAN}[*] Downloading Equicord installer...${NC}"
            download_file "$url" "$exe" || return 1
            chmod +x "$exe"
        fi

        if [ "$discord_was_running" = "true" ]; then
            if [ "$non_disruptive" = "true" ]; then
                if ! confirm_restart_for_repair "Equicord"; then
                    echo -e "${YELLOW}[!] Repair postponed by the user.${NC}"
                    return 0
                fi
                kill_discord
                discord_was_running=false
            else
                kill_discord
            fi
        fi
        
        echo -e "${CYAN}[*] Applying patch...${NC}"
        "$exe" -install -branch stable
    else
        echo -e "${GREEN}[+] Status: Patched & Ready${NC}"
    fi

    if [ "$non_disruptive" != "true" ] || [ "$discord_was_running" != "true" ]; then
        launch_discord
    fi
}

# --- Install Vencord ---
install_vencord() {
    local non_disruptive="${1:-false}"
    local discord_was_running=false
    if discord_is_running; then
        discord_was_running=true
    fi
    local index_file
    index_file="$(find_discord_index)"
    
    if [ -z "$index_file" ] || [ ! -f "$index_file" ]; then
        echo -e "${RED}[ERROR] Discord installation not found or index.js missing!${NC}"
        return 1
    fi

    if ! grep -q "Vencord" "$index_file"; then
        echo -e "${MAGENTA}[!] Patch missing. Recovering...${NC}"
        
        if [ "$OS" = "Darwin" ]; then
            # Vencord doesn't have CLI for Mac in GitHub releases, download and open the GUI app
            local app_zip="$WORK_DIR/VencordInstaller.MacOS.zip"
            if [ ! -d "$WORK_DIR/VencordInstaller.app" ]; then
                echo -e "${CYAN}[*] Downloading Vencord Installer...${NC}"
                download_file "https://github.com/Vencord/Installer/releases/latest/download/VencordInstaller.MacOS.zip" "$app_zip" || return 1
                unzip -o "$app_zip" -d "$WORK_DIR" > /dev/null
                rm -f "$app_zip"
            fi
            if [ "$discord_was_running" = "true" ]; then
                if [ "$non_disruptive" = "true" ]; then
                    if ! confirm_restart_for_repair "Vencord"; then
                        echo -e "${YELLOW}[!] Repair postponed by the user.${NC}"
                        return 0
                    fi
                    kill_discord
                    discord_was_running=false
                else
                    kill_discord
                fi
            fi
            echo -e "${CYAN}[*] Opening Vencord Installer. Please click Install/Repair in the app window.${NC}"
            open "$WORK_DIR/VencordInstaller.app"
        else
            # Linux has a CLI binary
            local exe="$WORK_DIR/VencordInstallerCli-linux"
            if [ ! -f "$exe" ]; then
                echo -e "${CYAN}[*] Downloading Vencord installer...${NC}"
                download_file "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux" "$exe" || return 1
                chmod +x "$exe"
            fi
            if [ "$discord_was_running" = "true" ]; then
                if [ "$non_disruptive" = "true" ]; then
                    if ! confirm_restart_for_repair "Vencord"; then
                        echo -e "${YELLOW}[!] Repair postponed by the user.${NC}"
                        return 0
                    fi
                    kill_discord
                    discord_was_running=false
                else
                    kill_discord
                fi
            fi
            echo -e "${CYAN}[*] Applying patch...${NC}"
            "$exe" -install -branch stable
        fi
    else
        echo -e "${GREEN}[+] Status: Patched & Ready${NC}"
    fi

    if { [ "$OS" != "Darwin" ] || grep -q "Vencord" "$index_file"; } && \
       { [ "$non_disruptive" != "true" ] || [ "$discord_was_running" != "true" ]; }; then
        launch_discord
    fi
}

# --- Run Modes ---
run_normal() {
    local mod="$1"
    local non_disruptive="${2:-false}"
    if [ "$mod" = "Vencord" ]; then
        install_vencord "$non_disruptive"
    else
        install_equicord "$non_disruptive"
    fi
}

run_debug() {
    local mod="$1"
    echo -e "${YELLOW}[*] Starting EquiLauncher in Debug Mode ($mod)...${NC}"
    {
        run_normal "$mod"
    } 2>&1 | tee "$LOG_PATH"
    echo -e "\n${YELLOW}[!] Debug log saved to: $LOG_PATH${NC}"
    read -n 1 -r -s -p "Press any key to close..."
    echo
}

# --- Autostart Setup ---
add_startup() {
    local mod="$1"
    local arg="--silent"
    if [ "$mod" = "Vencord" ]; then
        arg="--silent-vencord"
    fi

    echo -e "${CYAN}[*] Adding $mod to Startup...${NC}"

    if [ "$OS" = "Darwin" ]; then
        mkdir -p "$LAUNCH_AGENT_DIR"
        cat <<EOF > "$LAUNCH_AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <key>com.equilauncher.startup</key>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_PATH</string>
        <string>$arg</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
        chmod 644 "$LAUNCH_AGENT_PLIST"
        # Load the agent
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null
        launchctl load "$LAUNCH_AGENT_PLIST"
        echo -e "${GREEN}[+] Done! LaunchAgent plist created & loaded at $LAUNCH_AGENT_PLIST.${NC}"
    else
        mkdir -p "$AUTOSTART_DIR"
        cat <<EOF > "$AUTOSTART_DESKTOP"
[Desktop Entry]
Type=Application
Name=EquiLauncher
Comment=Patches and Launches Discord
Exec="$SCRIPT_PATH" $arg
Icon=discord
Terminal=false
Categories=Network;InstantMessaging;
X-GNOME-Autostart-enabled=true
EOF
        chmod +x "$AUTOSTART_DESKTOP"
        echo -e "${GREEN}[+] Done! Desktop Entry created at $AUTOSTART_DESKTOP.${NC}"
    fi

    read -n 1 -r -s -p "Press any key to return to menu..."
    echo
}

# Allow behavior tests to load the functions without starting the menu.
if [ "${EQUILAUNCHER_SOURCE_ONLY:-false}" = "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# --- CLI Arguments parsing ---
if [ "$1" = "--silent" ] || [ "$1" = "--startup" ]; then
    run_normal "Equicord" true
    exit 0
elif [ "$1" = "--silent-vencord" ]; then
    run_normal "Vencord" true
    exit 0
fi

# --- Main Interactive Menu Loop ---
while true; do
    clear
    echo -e "${YELLOW}"
    echo " _____ ____  _   _ _____  _____ _______       _____ _______ "
    echo "|  ____/ __ \| | | |_   _|/ ____|__   __|/\   |  __ \__   __|"
    echo "| |__ | |  | | | | | | | | (___    | |  /  \  | |__) | | |   "
    echo "|  __|| |  | | | | | | |  \___ \   | | / /\ \ |  _  /  | |   "
    echo "| |___| |__| | |_| |_| |_ ____) |  | |/ ____ \| | \ \  | |   "
    echo "|______\___\_\\___/|_____|_____/   |_/_/    \_\_|  \_\ |_|   "
    echo -e "                              v1.2.1${NC}"
    echo
    echo "========================================="
    echo -e "${CYAN}--- Запуск ---${NC}"
    echo "1. Запустить Equicord"
    echo "2. Запустить Vencord"
    echo
    echo -e "${YELLOW}--- Отладка ---${NC}"
    echo "3. Запустить в режиме отладки (Equicord)"
    echo "4. Запустить в режиме отладки (Vencord)"
    echo
    echo -e "${GREEN}--- Автозагрузка ---${NC}"
    echo "5. Добавить в автозагрузку (Equicord)"
    echo "6. Добавить в автозагрузку (Vencord)"
    echo
    echo -e "${GRAY}0. Выход${NC}"
    echo "========================================="
    
    read -p "Выберите действие: " choice
    
    case "$choice" in
        1)
            run_normal "Equicord"
            exit 0
            ;;
        2)
            run_normal "Vencord"
            exit 0
            ;;
        3)
            run_debug "Equicord"
            exit 0
            ;;
        4)
            run_debug "Vencord"
            exit 0
            ;;
        5)
            add_startup "Equicord"
            ;;
        6)
            add_startup "Vencord"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Неверный выбор, попробуйте еще раз.${NC}"
            sleep 1
            ;;
    esac
done
