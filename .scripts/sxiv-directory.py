#!/usr/bin/python3
"""Open sibling images when sxiv is launched with one selected file."""
import mimetypes
import os
from pathlib import Path
import sys


def image_arguments(arguments):
    if not arguments:
        return ["."]
    if len(arguments) != 1 or arguments[0].startswith("-"):
        return arguments
    selected = Path(os.path.abspath(arguments[0]))
    if not selected.is_file():
        return arguments
    try:
        images = sorted(
            (entry for entry in selected.parent.iterdir()
             if entry.is_file() and (
                 entry == selected or
                 (mimetypes.guess_type(entry.name)[0] or "").startswith("image/")
             )),
            key=lambda entry: entry.name,
        )
    except OSError:
        return arguments
    return ["-n", str(images.index(selected) + 1), *map(str, images)]


if __name__ == "__main__":
    library, *arguments = sys.argv[1:]
    previous = os.environ.get("LD_PRELOAD")
    os.environ["LD_PRELOAD"] = library + (":" + previous if previous else "")
    os.execv("/usr/bin/sxiv", ["sxiv", *image_arguments(arguments)])
