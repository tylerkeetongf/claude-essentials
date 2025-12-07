#!/usr/bin/env bash
# SessionStart hook for injecting skills awareness and activation instructions
# Skills are loaded on-demand via the Skill tool (progressive disclosure pattern)
# Updates project CLAUDE.md with available skills (idempotent) so that subagents gain access to the skills list
# Implements "Diff & Patch" to avoid double-injecting context if CLAUDE.md is already up to date

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

# Main logic to check, update, and notify
if [ -n "$SKILLS_LIST" ]; then
    example_block=$(build_example)

    # 1. Prepare content strings
    START_MARKER="<!-- DYNAMIC_SKILLS_START -->"
    END_MARKER="<!-- DYNAMIC_SKILLS_END -->"

    # The core content payload
    INJECTED_CONTENT="### Available Skills (Auto-Generated)

<INSTRUCTION>
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

    # 2. Determine paths and flags
    PROJECT_CLAUDE_MD="${PLUGIN_ROOT}/../../CLAUDE.md"
    SHOULD_UPDATE=false

    # 3. Check if file exists and compare content
    if [ ! -f "$PROJECT_CLAUDE_MD" ]; then
        # Case A: File doesn't exist - create it
        echo "# CLAUDE.md" > "$PROJECT_CLAUDE_MD"
        echo "" >> "$PROJECT_CLAUDE_MD"
        echo "${START_MARKER}" >> "$PROJECT_CLAUDE_MD"
        echo "${INJECTED_CONTENT}" >> "$PROJECT_CLAUDE_MD"
        echo "${END_MARKER}" >> "$PROJECT_CLAUDE_MD"
        SHOULD_UPDATE=true
    else
        # Case B: File exists - check if markers and content match
        if grep -Fq "$START_MARKER" "$PROJECT_CLAUDE_MD" && grep -Fq "$END_MARKER" "$PROJECT_CLAUDE_MD"; then
            # Extract current content between markers (handling newlines carefully)
            # We match strictly what is between the markers
            EXISTING_CONTENT=$(perl -0777 -ne 'print $1 if /<!-- DYNAMIC_SKILLS_START -->\n?(.*?)\n?<!-- DYNAMIC_SKILLS_END -->/s' "$PROJECT_CLAUDE_MD")

            # Compare. If they differ, we need to update.
            # Note: We check if strict strings match.
            if [[ "$EXISTING_CONTENT" != "$INJECTED_CONTENT" ]]; then
                export CONTENT="$INJECTED_CONTENT"
                # Update logic: Replace block with fresh content
                perl -i -0777 -pe 's/(<!-- DYNAMIC_SKILLS_START -->)(.*?)(<!-- DYNAMIC_SKILLS_END -->)/$1\n$ENV{CONTENT}\n$3/s' "$PROJECT_CLAUDE_MD"
                SHOULD_UPDATE=true
            fi
        else
            # Case C: Markers missing - append them
            echo "" >> "$PROJECT_CLAUDE_MD"
            echo "${START_MARKER}" >> "$PROJECT_CLAUDE_MD"
            echo "${INJECTED_CONTENT}" >> "$PROJECT_CLAUDE_MD"
            echo "${END_MARKER}" >> "$PROJECT_CLAUDE_MD"
            SHOULD_UPDATE=true
        fi
    fi

    # 4. Conditionally Output JSON
    # Only output if we updated the file.
    # If we updated, it means the Main Agent (which loaded the old file) has stale context.
    # If we didn't update, the Main Agent loaded the correct file, so we stay silent.
    if [ "$SHOULD_UPDATE" = true ]; then
        # Add a system notice so Claude knows why this is appearing
        JSON_TEXT="[SYSTEM UPDATE: Skills list refreshed]
${INJECTED_CONTENT}"

        json_content=$(printf '%s' "$JSON_TEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')

        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${json_content}"
  }
}
EOF
    fi
fi

exit 0
