#!/usr/bin/env python3

import argparse
import glob
import os
import sys
from datetime import date

from task_blocks import block_text, describe_blocked, join_sections, split_blocked_tasks


def recovery_stamp():
    today = date.today().strftime("%Y-%m-%d")
    session = os.environ.get("CLAUDE_CODE_SESSION_ID", "").strip()

    if session:
        return f"  Recovered {today} session {session}"

    return f"  Recovered {today}"


def reinstate(block, stamp):
    body = block_text(block)
    body = "- [ ]" + body[len("- [!]") :]
    return f"{body}\n{stamp}"


def report(scanned):
    for path, blocks, _ in scanned:
        if not blocks:
            continue
        print(f"{path}: {describe_blocked(len(blocks))}")
        for block in blocks:
            print(f"  {block[0].rstrip()}")


def append_tasks(todo_path, remaining, blocks, stamp):
    chunks = []

    existing = "".join(remaining).strip("\n")
    if existing:
        chunks.append(existing)

    for block in blocks:
        chunks.append(reinstate(block, stamp))

    with open(todo_path, "w") as file:
        file.write(join_sections(chunks))


def unblock_tasks(llm_dir, dry_run):
    if not os.path.isdir(llm_dir):
        print(f"Error: Directory '{llm_dir}' not found", file=sys.stderr)
        sys.exit(1)

    todo_path = os.path.join(llm_dir, "todo.md")
    paths = sorted(glob.glob(os.path.join(llm_dir, "*todo*.md")))

    scanned = []
    for path in paths:
        with open(path, "r") as file:
            remaining, blocks = split_blocked_tasks(file.readlines())
        scanned.append((path, blocks, remaining))

    total = sum(len(blocks) for _, blocks, _ in scanned)

    if dry_run:
        print("DRY RUN: no files were modified")
        report(scanned)
        print(f"Total: {describe_blocked(total)} would move to {todo_path}")
        return

    if total == 0:
        print("No blocked tasks found")
        return

    recovered = [block for _, blocks, _ in scanned for block in blocks]
    todo_remaining = next(
        (remaining for path, _, remaining in scanned if path == todo_path), []
    )

    for path, blocks, remaining in scanned:
        if path == todo_path or not blocks:
            continue
        with open(path, "w") as file:
            file.writelines(remaining)

    append_tasks(todo_path, todo_remaining, recovered, recovery_stamp())

    report(scanned)
    print(f"Total: {describe_blocked(total)} recovered into {todo_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Move blocked [!] tasks out of archived task lists and back into todo.md"
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default=".llm",
        help="Directory holding the task lists (default: .llm)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would move without rewriting any file",
    )

    args = parser.parse_args()

    try:
        unblock_tasks(args.directory, args.dry_run)
    except Exception as exception:
        print(f"Error: {exception}", file=sys.stderr)
        sys.exit(1)
