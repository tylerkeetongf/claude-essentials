#!/usr/bin/env bash
# Cross-platform notification with click-to-focus support
# macOS: Uses terminal-notifier if available (click focuses terminal), falls back to osascript
# Linux: Uses notify-send

set -euo pipefail

PROJECT=$(basename "$PWD")
MESSAGE="Waiting for input in $PROJECT"
TITLE="Claude Code"

# Flag file to track if we've shown the terminal-notifier hint
HINT_FLAG="$HOME/.cache/claude-code/notifier-hint-shown"

# macOS notification with terminal-notifier (supports click-to-activate)
notify_macos_terminal_notifier() {
    # Detect terminal and map to bundle identifier
    local app_id
    case "${TERM_PROGRAM:-}" in
        iTerm.app)      app_id="com.googlecode.iterm2" ;;
        Apple_Terminal) app_id="com.apple.Terminal" ;;
        WarpTerminal)   app_id="dev.warp.Warp-Stable" ;;
        vscode)         app_id="com.microsoft.VSCode" ;;
        Alacritty)      app_id="org.alacritty" ;;
        kitty)          app_id="net.kovidgoyal.kitty" ;;
        *)              app_id="com.apple.Terminal" ;;
    esac

    terminal-notifier \
        -title "$TITLE" \
        -message "$MESSAGE" \
        -sound "Glass" \
        -activate "$app_id" \
        -ignoreDnD \
        2>/dev/null
}

# macOS fallback with osascript (no click-to-focus, but still notifies)
notify_macos_osascript() {
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Glass\"" 2>/dev/null
}

# Show one-time hint about terminal-notifier
show_install_hint() {
    if [[ ! -f "$HINT_FLAG" ]]; then
        mkdir -p "$(dirname "$HINT_FLAG")"
        touch "$HINT_FLAG"
        # Output hint - this will appear in Claude Code's output
        echo "Tip: Install terminal-notifier for click-to-focus notifications: brew install terminal-notifier" >&2
    fi
}

# Linux notification with notify-send
notify_linux() {
    notify-send -u normal -a "$TITLE" "$TITLE" "$MESSAGE" 2>/dev/null
}

# Main: try best option available
if [[ "$OSTYPE" == darwin* ]]; then
    if command -v terminal-notifier >/dev/null 2>&1; then
        notify_macos_terminal_notifier
    elif command -v osascript >/dev/null 2>&1; then
        show_install_hint
        notify_macos_osascript
    fi
elif command -v notify-send >/dev/null 2>&1; then
    notify_linux
fi

exit 0
