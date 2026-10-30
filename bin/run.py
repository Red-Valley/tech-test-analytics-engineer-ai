#!/usr/bin/env python3
"""Build the warehouse and run its SQL assertions with one command."""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

for script in ("build.py", "test.py"):
    result = subprocess.run(
        [sys.executable, os.path.join(ROOT, "bin", script)],
        cwd=ROOT,
        check=False,
    )
    if result.returncode:
        sys.exit(result.returncode)
