# test_env_location.py
from pathlib import Path

# Try different possible locations
possible_locations = [
    Path(__file__).resolve().parent.parent,  # SBMS-Y3S1G4/
    Path(__file__).resolve().parent.parent.parent,  # GitHub/SBMS-Y3S1G4/
    Path.cwd(),  # Current working directory
    Path.home() / "Documents" / "GitHub" / "SBMS-Y3S1G4",
]

for location in possible_locations:
    env_file = location / ".env"
    print(f"Checking: {env_file}")
    if env_file.exists():
        print(f"✅ FOUND .env at: {env_file}")
        break
else:
    print("❌ No .env file found in any location")