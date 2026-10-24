#!/usr/bin/env python3

import sys
import os
import subprocess

from task_blocks import (
    OPEN_PATTERN,
    TaskArgumentParser,
    collect_context,
    describe_incomplete,
    fail,
    incomplete_task_starts,
    positive_int,
    stamp,
    task_title,
    trim_trailing_blanks,
)


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


REASON_LABELS = {"!": "Blocked", "x": "Completed", ">": "Claimed"}


def insert_reason(lines, start, context, marker, reason):
    """Insert the reason below the task body, above any trailing blank lines."""
    body_length = len(trim_trailing_blanks(list(context)))
    position = start + 1 + body_length

    if not lines[position - 1].endswith("\n"):
        lines[position - 1] += "\n"

    label = REASON_LABELS.get(marker, f"Marked [{marker}]")
    lines.insert(position, stamp(label, reason) + "\n")


def find_task(lines, index, title):
    """Return the line index of the task to mark, or exit when there is none."""
    if title is not None:
        for position, line in enumerate(lines):
            if OPEN_PATTERN.match(line) and task_title(line) == title:
                return position
        fail(f"no [ ] or [>] task titled '{title}'")

    starts = incomplete_task_starts(lines)

    if index is None:
        if not starts:
            print("No incomplete tasks found", file=sys.stderr)
            sys.exit(1)
        return starts[0]

    if index > len(starts):
        fail(f"--index {index} is out of range; {describe_incomplete(len(starts))}")

    return starts[index - 1]


def mark_task(filename, marker, reason, index, title):
    if not os.path.exists(filename):
        print("No tasks found (file doesn't exist)", file=sys.stderr)
        sys.exit(1)

    with open(filename, "r") as file:
        lines = file.readlines()

    position = find_task(lines, index, title)

    lines[position] = f"- [{marker}]" + lines[position][len("- [ ]") :]
    context = collect_context(lines, position)

    if reason:
        insert_reason(lines, position, context, marker, reason)
        context = collect_context(lines, position)

    with open(filename, "w") as file:
        file.writelines(lines)

    verify_gitignored(filename)

    print("".join(trim_trailing_blanks([lines[position]] + context)), end="")


if __name__ == "__main__":
    parser = TaskArgumentParser(
        description="Mark the first incomplete task, or a chosen one, with a marker character"
    )
    parser.add_argument("filename", help="File containing tasks")
    target = parser.add_mutually_exclusive_group()
    target.add_argument(
        "--index",
        type=positive_int,
        help="Mark the Nth incomplete [ ] task (1-based)",
    )
    target.add_argument(
        "--title",
        help="Mark the first [ ] or [>] task whose text after the checkbox equals TITLE",
    )
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

    try:
        mark_task(args.filename, args.marker, reason, args.index, args.title)
    except Exception as e:
        fail(e)
