#!/usr/bin/env python3
import asyncio
import sys
import os

# Add the project root to Python path so we can import glab_mcp
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(project_root, 'src'))

from glab_mcp.server import main

if __name__ == "__main__":
    asyncio.run(main())