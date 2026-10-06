#!/usr/bin/env python3
"""List local changes to repository-managed files without deploying anything."""
from pathlib import Path
import sys
from deploy import report_drift

if __name__ == '__main__':
    source = Path(__file__).resolve().parent.parent
    home = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path.home()
    raise SystemExit(1 if report_drift(source, home) else 0)
