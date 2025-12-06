#!/usr/bin/env bash
# SessionStart hook for injecting skills awareness and activation instructions
# Skills are loaded on-demand via the Skill tool (progressive disclosure pattern)

set -euo pipefail

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
        # Truncate description to ~200 chars at word boundary
        if [[ ${#desc} -gt 200 ]]; then
            desc="${desc:0:200}"
            desc="${desc% *}..."  # Cut at last space, add ellipsis
        fi
        echo "ce:${name}|${desc}"
    fi
}

# Build dynamic skills list from SKILL.md files
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="${PLUGIN_ROOT}/skills"
SKILL_NAMES=()
SKILLS_LIST=""

if [ -d "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_file="${skill_dir}SKILL.md"
        if [ -f "$skill_file" ]; then
            skill_data=$(parse_skill "$skill_file")
            if [ -n "$skill_data" ]; then
                skill_name="${skill_data%%|*}"
                skill_desc="${skill_data#*|}"
                SKILL_NAMES+=("$skill_name")
                SKILLS_LIST="${SKILLS_LIST}- ${skill_name}: ${skill_desc}
"
            fi
        fi
    done
fi

# Build example evaluation using actual skill names
build_example() {
    local count=${#SKILL_NAMES[@]}

    if [ $count -eq 0 ]; then
        echo "- No skills available"
        return
    fi

    # Show 3 skills: first YES, others NO
    local max=$((count < 3 ? count : 3))
    for ((i=0; i<max; i++)); do
        if [ $i -eq 0 ]; then
            echo "- ${SKILL_NAMES[$i]}: YES - matches current task"
        else
            echo "- ${SKILL_NAMES[$i]}: NO - not relevant"
        fi
    done

    # Show activation with multiple skills if available
    echo ""
    echo "[Then IMMEDIATELY use Skill() tool:]"
    echo "> Skill(${SKILL_NAMES[0]})"
    if [ $count -gt 1 ]; then
        echo "> Skill(${SKILL_NAMES[1]})  // if also relevant"
    fi
    echo ""
    echo "[THEN and ONLY THEN start implementation]"
}

# Output context injection as JSON if skills were found
if [ -n "$SKILLS_LIST" ]; then
    example_block=$(build_example)

    # Use the stronger instructional format from on-submit.sh with dynamic skills
    additional_context="<INSTRUCTION>
MANDATORY SKILL ACTIVATION SEQUENCE

Step 1 - EVALUATE (do this in your response):
For each skill below, state: [skill-name] - YES/NO - [reason]

Available skills:
${SKILLS_LIST}
Step 2 - ACTIVATE (do this immediately after Step 1):
IF any skills are YES: Use Skill(<skill-name>) tool for EACH relevant skill NOW
IF no skills are YES: State \"No skills needed\" and proceed

Step 3 - IMPLEMENT:
Only after Step 2 is complete, proceed with implementation.

CRITICAL: You MUST call Skill() tool in Step 2. Do NOT skip to implementation.
The evaluation (Step 1) is WORTHLESS unless you ACTIVATE (Step 2) the skills.

Example of correct sequence:
${example_block}
</INSTRUCTION>"

    # Escape for JSON - works on both macOS and Linux
    additional_context=$(printf '%s' "$additional_context" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')

    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${additional_context}"
  }
}
EOF
fi

exit 0
