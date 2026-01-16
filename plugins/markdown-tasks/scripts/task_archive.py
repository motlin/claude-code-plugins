#!/usr/bin/env python3

import sys
import os
from datetime import datetime


def archive_task_file(filename):
    try:
        if not os.path.exists(filename):
            print(f"No file to archive (file doesn't exist): {filename}", file=sys.stderr)
            sys.exit(1)

        directory = os.path.dirname(filename)
        basename = os.path.basename(filename)
        name_without_ext, extension = os.path.splitext(basename)

        timestamp = datetime.now().strftime("%Y-%m-%d")
        archived_filename = os.path.join(directory, f"{timestamp}-{name_without_ext}{extension}")

        counter = 1
        while os.path.exists(archived_filename):
            archived_filename = os.path.join(
                directory, f"{timestamp}-{name_without_ext}-{counter}{extension}"
            )
            counter += 1

        os.rename(filename, archived_filename)
        print(f"Archived to: {archived_filename}")

    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: task_archive.py <filename>", file=sys.stderr)
        sys.exit(1)

    archive_task_file(sys.argv[1])
