#!/usr/bin/env python3

import sys
import os
import re


def extract_first_todo(filename):
    try:
        if not os.path.exists(filename):
            print(f"No todos found (file doesn't exist)", file=sys.stderr)
            sys.exit(1)

        with open(filename, "r") as file:
            lines = file.readlines()

        todo_lines = []
        in_todo = False

        for i, line in enumerate(lines):
            if re.match(r"^- \[ \]", line):
                if in_todo:
                    break
                todo_lines.append(line)
                in_todo = True
            elif in_todo:
                if re.match(r"^[\s\t]+", line) and line.strip():
                    todo_lines.append(line)
                elif re.match(r"^- \[[x>]\]", line):
                    break
                elif re.match(r"^#", line):
                    break
                elif line.strip() == "":
                    todo_lines.append(line)
                else:
                    break

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
