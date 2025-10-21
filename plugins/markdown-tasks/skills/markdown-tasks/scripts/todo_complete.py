#!/usr/bin/env python3

import sys
import os
import subprocess
import re
import argparse


def find_git_root(start_path):
    try:
        result = subprocess.run(
            ["git", "-C", start_path, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def is_file_in_git_status(filename):
    directory = os.path.dirname(filename) or "."
    git_root = find_git_root(directory)

    if not git_root:
        return False

    absolute_filename = os.path.realpath(filename)
    git_root_real = os.path.realpath(git_root)
    relative_filename = os.path.relpath(absolute_filename, git_root_real)

    try:
        result = subprocess.run(
            ["git", "-C", git_root, "status", "--short", relative_filename],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return False


def is_file_tracked(filename):
    directory = os.path.dirname(filename) or "."
    git_root = find_git_root(directory)

    if not git_root:
        return False

    absolute_filename = os.path.realpath(filename)
    git_root_real = os.path.realpath(git_root)
    relative_filename = os.path.relpath(absolute_filename, git_root_real)

    try:
        result = subprocess.run(
            ["git", "-C", git_root, "ls-files", relative_filename],
            capture_output=True,
            text=True,
            check=True,
        )
        return bool(result.stdout.strip())
    except subprocess.CalledProcessError:
        return False


def verify_gitignored(filename):
    status = is_file_in_git_status(filename)
    if not status:
        return

    if is_file_tracked(filename):
        print(
            f"Warning: {filename} is tracked by git and cannot be excluded. Run: git rm --cached {filename}",
            file=sys.stderr,
        )
    else:
        print(
            f"Warning: {filename} is not gitignored. Add /.llm to .git/info/exclude",
            file=sys.stderr,
        )


def mark_first_todo(filename, mark_type):
    try:
        if not os.path.exists(filename):
            print(f"No todos found (file doesn't exist)", file=sys.stderr)
            sys.exit(1)

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

            verify_gitignored(filename)

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
