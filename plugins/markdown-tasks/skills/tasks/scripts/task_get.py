#!/usr/bin/env python3

import sys
import os
import re


def extract_first_task(filename):
    try:
        if not os.path.exists(filename):
            print(f"No tasks found (file doesn't exist)", file=sys.stderr)
            sys.exit(1)

        with open(filename, "r") as file:
            lines = file.readlines()

        task_lines = []
        in_task = False

        for i, line in enumerate(lines):
            if re.match(r"^- \[ \]", line):
                if in_task:
                    break
                task_lines.append(line)
                in_task = True
            elif in_task:
                if re.match(r"^[\s\t]+", line) and line.strip():
                    task_lines.append(line)
                elif re.match(r"^- \[[x>]\]", line):
                    break
                elif re.match(r"^#", line):
                    break
                elif line.strip() == "":
                    task_lines.append(line)
                else:
                    break

        while task_lines and task_lines[-1].strip() == "":
            task_lines.pop()

        if task_lines:
            print("".join(task_lines), end="")

    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: task-get <filename>", file=sys.stderr)
        sys.exit(1)

    extract_first_task(sys.argv[1])
