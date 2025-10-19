#!/usr/bin/env python3

import sys
import re


def extract_first_todo(filename):
    try:
        with open(filename, "r") as file:
            lines = file.readlines()

        todo_lines = []
        in_todo = False

        for i, line in enumerate(lines):
            # Check for incomplete checkbox
            if re.match(r"^- \[ \]", line):
                if in_todo:
                    # We've found another todo, stop here
                    break
                todo_lines.append(line)
                in_todo = True
            elif in_todo:
                # Check if this line is part of the current todo
                # It should be indented (start with spaces or tabs)
                if re.match(r"^[\s\t]+", line) and line.strip():
                    todo_lines.append(line)
                elif re.match(r"^- \[[x>]\]", line):
                    # Found a complete or in-progress checkbox, stop
                    break
                elif re.match(r"^#", line):
                    # Found a markdown header, stop
                    break
                elif line.strip() == "":
                    # Empty line might be part of the todo, include it
                    todo_lines.append(line)
                else:
                    # Non-indented content that's not a checkbox or header, stop
                    break

        # Remove trailing empty lines
        while todo_lines and todo_lines[-1].strip() == "":
            todo_lines.pop()

        if todo_lines:
            print("".join(todo_lines), end="")

    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: todo-get <filename>", file=sys.stderr)
        sys.exit(1)

    extract_first_todo(sys.argv[1])
