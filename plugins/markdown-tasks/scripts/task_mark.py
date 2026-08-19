#!/usr/bin/env python3

import sys
import os
import subprocess
import re
import argparse

from task_blocks import collect_context, stamp, trim_trailing_blanks


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


def insert_reason(lines, start, context, reason):
    """Insert the reason below the task body, above any trailing blank lines."""
    body_length = len(trim_trailing_blanks(list(context)))
    position = start + 1 + body_length

    if not lines[position - 1].endswith("\n"):
        lines[position - 1] += "\n"

    lines.insert(position, stamp("Blocked", reason) + "\n")


def mark_first_task(filename, marker, reason):
    try:
        if not os.path.exists(filename):
            print(f"No tasks found (file doesn't exist)", file=sys.stderr)
            sys.exit(1)

        with open(filename, "r") as file:
            lines = file.readlines()

        modified = False
        task_lines = []

        for index, line in enumerate(lines):
            if re.match(r"^- \[ \]", line):
                lines[index] = f"- [{marker}]" + line[len("- [ ]") :]
                context = collect_context(lines, index)

                if reason:
                    insert_reason(lines, index, context, reason)
                    context = collect_context(lines, index)

                task_lines = [lines[index]] + context
                modified = True
                break

        if modified:
            with open(filename, "w") as file:
                file.writelines(lines)

            verify_gitignored(filename)

            trim_trailing_blanks(task_lines)

            print("".join(task_lines), end="")
        else:
            print("No incomplete tasks found", file=sys.stderr)
            sys.exit(1)

    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Mark the first incomplete task with a marker character"
    )
    parser.add_argument("filename", help="File containing tasks")
    parser.add_argument(
        "--marker",
        default="x",
        help="Marker char inside the checkbox (default: x)",
    )
    parser.add_argument(
        "--reason",
        default="",
        help="Why the task reached this state; required for --marker='!'",
    )

    args = parser.parse_args()

    if len(args.marker) != 1 or args.marker.isspace():
        print(
            "Error: --marker must be exactly one non-space character",
            file=sys.stderr,
        )
        sys.exit(1)

    reason = " ".join(args.reason.split())

    if args.marker == "!" and not reason:
        print(
            "Error: --reason is required with --marker='!' so the next attempt knows what failed",
            file=sys.stderr,
        )
        sys.exit(1)

    mark_first_task(args.filename, args.marker, reason)
