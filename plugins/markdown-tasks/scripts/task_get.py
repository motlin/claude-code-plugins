#!/usr/bin/env python3

import sys
import os
import re

from task_blocks import collect_context, trim_trailing_blanks


def extract_first_task(filename):
    try:
        if not os.path.exists(filename):
            print(f"No tasks found (file doesn't exist)", file=sys.stderr)
            sys.exit(1)

        with open(filename, "r") as file:
            lines = file.readlines()

        task_lines = []

        for index, line in enumerate(lines):
            if re.match(r"^- \[ \]", line):
                task_lines = [line] + collect_context(lines, index)
                break

        trim_trailing_blanks(task_lines)

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
