"""Shared parsing rules for the markdown checkbox task lists in .llm/."""

import re

CHECKBOX_PATTERN = re.compile(r"^- \[.\]")
HEADING_PATTERN = re.compile(r"^#")
INDENT_PATTERN = re.compile(r"^[\s\t]+")


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
