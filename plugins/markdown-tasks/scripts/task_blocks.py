"""Shared parsing rules for the markdown checkbox task lists in .llm/."""

import os
import re
from datetime import date

CHECKBOX_PATTERN = re.compile(r"^- \[.\]")
HEADING_PATTERN = re.compile(r"^#")
INDENT_PATTERN = re.compile(r"^[\s\t]+")
BLOCKED_PATTERN = re.compile(r"^- \[!\]")


def stamp(label, detail=None):
    """Return an indented context line recording a state change and its session.

    Codex runs these scripts without CLAUDE_CODE_SESSION_ID, so the session
    field is dropped rather than filled with a placeholder.
    """
    today = date.today().strftime("%Y-%m-%d")
    session = os.environ.get("CLAUDE_CODE_SESSION_ID", "").strip()

    line = f"  {label} {today} session {session}" if session else f"  {label} {today}"

    return f"{line}: {detail}" if detail else line


def collect_context(lines, start):
    """Return the context lines belonging to the task opened at lines[start].

    Indented non-blank lines and blank lines continue the task. Another
    checkbox or a heading ends it.
    """
    context = []
    index = start + 1

    while index < len(lines):
        line = lines[index]

        if INDENT_PATTERN.match(line) and line.strip():
            context.append(line)
        elif CHECKBOX_PATTERN.match(line) or HEADING_PATTERN.match(line):
            break
        elif line.strip() == "":
            context.append(line)
        else:
            break

        index += 1

    return context


def trim_trailing_blanks(lines):
    while lines and lines[-1].strip() == "":
        lines.pop()

    return lines


def split_blocked_tasks(lines):
    """Return the lines that stay in the file and the blocked task blocks."""
    remaining = []
    blocks = []
    index = 0

    while index < len(lines):
        line = lines[index]

        if not BLOCKED_PATTERN.match(line):
            remaining.append(line)
            index += 1
            continue

        context = collect_context(lines, index)
        index += 1 + len(context)
        blocks.append(trim_trailing_blanks([line] + context))

    return remaining, blocks


def describe_blocked(count):
    return f"{count} blocked task" if count == 1 else f"{count} blocked tasks"


def block_text(block):
    return "".join(block).rstrip("\n")


def join_sections(sections):
    """Join document sections with one blank line between them."""
    return "\n\n".join(sections) + "\n"
