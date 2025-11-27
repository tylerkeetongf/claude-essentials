#!/usr/bin/env bash
# SessionStart hook for loading user instructions
# Skills are loaded on-demand via the Skill tool (progressive disclosure pattern)

set -euo pipefail

# Claude Code config root directory (use $HOME, not ~ for reliable expansion)
CONFIG_ROOT="$HOME/.claude"

# Path to user instructions
CLAUDE_MD_PATH="${CONFIG_ROOT}/CLAUDE.md"

# Default instructions when no CLAUDE.md exists
# These establish baseline communication expectations for quality sessions
DEFAULT_INSTRUCTIONS="# Communication Guidelines

Be direct, practical, and clear. Speak naturally and conversationally.

## Avoid the following:
<avoid>
- Corporate buzzwords and marketing speak
- AI-sounding language or excessive enthusiasm
- Overly formal or robotic documentation style
- Dramatic hyperbole about issues or solutions
- Em dashes (—)
- Emojis (unless explicitly requested)
- Sycophancy and excessive agreement
</avoid>

## Challenge Ideas

Don't agree just to be agreeable. If you see issues with proposed approaches, point them out. The goal is building the best possible system, not validating existing ideas. Avoid phrases like \"You're absolutely right!\" unless genuinely warranted.

## Keep It Simple

- Only make changes that are directly requested or clearly necessary
- Don't add features, refactor code, or make improvements beyond what was asked
- Avoid over-engineering and premature abstractions
- A simple solution that works is better than an elegant solution that's overcomplicated

## Apply These Guidelines To

- All responses and explanations
- Code comments and documentation
- Markdown files and README content
- Commit messages and PR descriptions
- Any written communication"

# Function to escape content for JSON
escape_for_json() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}'
}

# Extract name and truncated description from SKILL.md YAML frontmatter
parse_skill() {
    local skill_file="$1"
    local in_frontmatter=false
    local name=""
    local desc=""

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                break  # End of frontmatter
            fi
            in_frontmatter=true
            continue
        fi
        if $in_frontmatter; then
            if [[ "$line" =~ ^name:\ *(.+)$ ]]; then
                name="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^description:\ *(.+)$ ]]; then
                desc="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$skill_file"

    if [[ -n "$name" && -n "$desc" ]]; then
        # Truncate description to ~100 chars at word boundary
        if [[ ${#desc} -gt 100 ]]; then
            desc="${desc:0:100}"
            desc="${desc% *}..."  # Cut at last space, add ellipsis
        fi
        echo "- ce:${name} - ${desc}"
    fi
}

# Read CLAUDE.md user instructions if available and has content
# Otherwise use sensible defaults
if [ -f "$CLAUDE_MD_PATH" ] && [ -s "$CLAUDE_MD_PATH" ]; then
    claude_md_content=$(cat "$CLAUDE_MD_PATH" 2>&1)
    claude_md_escaped=$(escape_for_json "$claude_md_content")
    additional_context="<CRITICAL_USER_INSTRUCTIONS>\n${claude_md_escaped}\n</CRITICAL_USER_INSTRUCTIONS>"
else
    # No user config, use default instructions
    default_escaped=$(escape_for_json "$DEFAULT_INSTRUCTIONS")
    additional_context="<SESSION_GUIDELINES>\n${default_escaped}\n</SESSION_GUIDELINES>"
fi

# Build dynamic skills list from SKILL.md files
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="${PLUGIN_ROOT}/skills"
SKILLS_LIST=""

if [ -d "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_file="${skill_dir}SKILL.md"
        if [ -f "$skill_file" ]; then
            skill_line=$(parse_skill "$skill_file")
            if [ -n "$skill_line" ]; then
                SKILLS_LIST="${SKILLS_LIST}${skill_line}\n"
            fi
        fi
    done
fi

# Append skills awareness to context if skills were found
if [ -n "$SKILLS_LIST" ]; then
    # Note: SKILLS_LIST already has \n literals, no need to escape
    additional_context="${additional_context}\n\n## Available Skills\n\nConsider using these skills when they match your task (invoke via Skill tool):\n\n${SKILLS_LIST}"
fi

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${additional_context}"
  }
}
EOF

exit 0
