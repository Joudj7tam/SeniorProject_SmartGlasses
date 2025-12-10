import sys
import os

# Path to project root
PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")
)

# Add backend/ folder to sys.path
BACKEND_PATH = os.path.join(PROJECT_ROOT, "backend")
sys.path.insert(0, BACKEND_PATH)
