"""Entry point for the glab-mcp package."""

import asyncio
from .server import main

if __name__ == "__main__":
    asyncio.run(main())