#!/usr/bin/env python3

import sys
import os
import re


def count_open_tasks(filename):
    try:
        if not os.path.exists(filename):
            print("0")
            return

        with open(filename, "r") as file:
            content = file.read()

        open_tasks = re.findall(r"^- \[ \]", content, re.MULTILINE)
        print(len(open_tasks))

    except FileNotFoundError:
        print("0")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: task_count.py <filename>", file=sys.stderr)
        sys.exit(1)

    count_open_tasks(sys.argv[1])
