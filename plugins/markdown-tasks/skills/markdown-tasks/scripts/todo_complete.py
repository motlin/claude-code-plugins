#!/usr/bin/env python3

import sys
import re
import argparse


def mark_first_todo(filename, mark_type):
    try:
        with open(filename, "r") as file:
            lines = file.readlines()

        modified = False
        todo_lines = []
        found_todo = False

        for i, line in enumerate(lines):
            if re.match(r"^- \[ \]", line):
                if mark_type == "progress":
                    lines[i] = re.sub(r"^- \[ \]", "- [>]", line)
                else:
                    lines[i] = re.sub(r"^- \[ \]", "- [x]", line)

                todo_lines.append(lines[i])
                modified = True
                found_todo = True

                # Collect associated lines for this todo
                j = i + 1
                while j < len(lines):
                    next_line = lines[j]
                    if re.match(r"^[\s\t]+", next_line) and next_line.strip():
                        todo_lines.append(next_line)
                    elif re.match(r"^- \[[x>\s]\]", next_line):
                        break
                    elif re.match(r"^#", next_line):
                        break
                    elif next_line.strip() == "":
                        todo_lines.append(next_line)
                    else:
                        break
                    j += 1
                break

        if modified:
            with open(filename, "w") as file:
                file.writelines(lines)

            # Remove trailing empty lines from output
            while todo_lines and todo_lines[-1].strip() == "":
                todo_lines.pop()

            print("".join(todo_lines), end="")
        else:
            print("No incomplete todos found", file=sys.stderr)
            sys.exit(1)

    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Mark first incomplete todo as done or in-progress"
    )
    parser.add_argument("filename", help="File containing todos")
    parser.add_argument(
        "--progress",
        action="store_true",
        help="Mark as in-progress [>] instead of done [x]",
    )
    parser.add_argument(
        "--done", action="store_true", help="Mark as done [x] (default)"
    )

    args = parser.parse_args()

    if args.progress and args.done:
        print("Error: Cannot specify both --progress and --done", file=sys.stderr)
        sys.exit(1)

    mark_type = "progress" if args.progress else "done"
    mark_first_todo(args.filename, mark_type)
