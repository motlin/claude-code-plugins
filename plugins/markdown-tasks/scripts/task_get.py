#!/usr/bin/env python3

import argparse
import os
import re
import sys

from task_blocks import (
    TaskArgumentParser,
    block_text,
    collect_context,
    describe_incomplete,
    fail,
    incomplete_task_starts,
    join_sections,
    positive_int,
    trim_trailing_blanks,
)


def task_range(value):
    match = re.fullmatch(r"(\d+)-(\d+)", value)
    if not match:
        raise argparse.ArgumentTypeError(f"'{value}' is not START-END")

    start, end = int(match.group(1)), int(match.group(2))
    if start < 1 or end < start:
        raise argparse.ArgumentTypeError(
            f"'{value}' needs 1 <= START <= END"
        )

    return start, end


def select(starts, args):
    """Return the selected task start lines, or exit when the selection is out of range."""
    count = len(starts)

    if args.index is not None:
        if args.index > count:
            fail(f"--index {args.index} is out of range; {describe_incomplete(count)}")
        return [starts[args.index - 1]]

    if args.range is not None:
        start, end = args.range
        if start > count:
            fail(f"--range {start}-{end} is out of range; {describe_incomplete(count)}")
        return starts[start - 1 : end]

    if args.limit is not None:
        return starts[: args.limit]

    return starts[:1]


def print_tasks(filename, args):
    if not os.path.exists(filename):
        print("No tasks found (file doesn't exist)", file=sys.stderr)
        sys.exit(1)

    with open(filename, "r") as file:
        lines = file.readlines()

    blocks = [
        trim_trailing_blanks([lines[start]] + collect_context(lines, start))
        for start in select(incomplete_task_starts(lines), args)
    ]

    if blocks:
        print(join_sections([block_text(block) for block in blocks]), end="")


if __name__ == "__main__":
    parser = TaskArgumentParser(
        description="Print incomplete [ ] tasks; the first one by default"
    )
    parser.add_argument("filename", help="File containing tasks")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument(
        "--index",
        type=positive_int,
        help="Print only the Nth incomplete task (1-based)",
    )
    selection.add_argument(
        "--range",
        type=task_range,
        metavar="START-END",
        help="Print incomplete tasks START through END (1-based, inclusive)",
    )
    selection.add_argument(
        "--limit",
        type=positive_int,
        help="Print the first N incomplete tasks",
    )

    args = parser.parse_args()

    try:
        print_tasks(args.filename, args)
    except Exception as e:
        fail(e)
