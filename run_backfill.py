"""Entry point for the one-time historical backfill.

Run from the project root with the virtualenv active:
    python run_backfill.py
"""

import logging

from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)

from ingestion.pancake.resources.backfill import run_backfill

if __name__ == "__main__":
    run_backfill()
