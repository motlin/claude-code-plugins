#!/usr/bin/env python3

import sys
import os
import argparse


def add_todo(filename, description):
    try:
        directory = os.path.dirname(filename)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)

        file_exists = os.path.exists(filename)

        with open(filename, "a") as file:
            if file_exists and os.path.getsize(filename) > 0:
                file.write("\n")

            file.write(f"- [ ] {description}\n")

        print(f"- [ ] {description}")

    except Exception as exception:
        print(f"Error: {exception}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add a todo to the task list")
    parser.add_argument("filename", help="File containing todos")
    parser.add_argument("description", help="Todo description")

    args = parser.parse_args()

    add_todo(args.filename, args.description)
