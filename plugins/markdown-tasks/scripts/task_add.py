#!/usr/bin/env python3

import sys
import os
import subprocess
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
        return bool(result.stdout.strip())
    except subprocess.CalledProcessError:
        return False


def add_to_git_exclude(filename):
    directory = os.path.dirname(filename)
    if not directory:
        return False

    git_root = find_git_root(directory)
    if not git_root:
        return False

    exclude_file = os.path.join(git_root, ".git", "info", "exclude")
    exclude_dir = os.path.dirname(exclude_file)

    if not os.path.exists(exclude_dir):
        return False

    llm_relative = "/.llm"

    if os.path.exists(exclude_file):
        with open(exclude_file, "r") as file:
            content = file.read()
            if llm_relative in content.splitlines():
                return True

    with open(exclude_file, "a") as file:
        if os.path.getsize(exclude_file) > 0:
            content = open(exclude_file, "r").read()
            if not content.endswith("\n"):
                file.write("\n")
        file.write(f"{llm_relative}\n")

    return True


def ensure_gitignored(filename):
    if not is_file_in_git_status(filename):
        return

    if not add_to_git_exclude(filename):
        return

    if is_file_in_git_status(filename):
        print(
            f"Warning: {filename} is tracked by git and cannot be excluded. Run: git rm --cached {filename}",
            file=sys.stderr,
        )


def add_task(filename, description):
    try:
        directory = os.path.dirname(filename)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)

        file_exists = os.path.exists(filename)

        with open(filename, "a") as file:
            if file_exists and os.path.getsize(filename) > 0:
                file.write("\n")

            file.write(f"- [ ] {description}\n")

        ensure_gitignored(filename)

        print(f"- [ ] {description}")

    except Exception as exception:
        print(f"Error: {exception}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add a task to the task list")
    parser.add_argument("filename", help="File containing tasks")
    parser.add_argument("description", help="Task description")

    args = parser.parse_args()

    add_task(args.filename, args.description)
