import ctypes
# Make Python DPI-aware to get correct screen coordinates on Windows 10/11
# This must be called BEFORE importing pyautogui
ctypes.windll.shcore.SetProcessDpiAwareness(2)  # PROCESS_PER_MONITOR_DPI_AWARE

import pyautogui
import time
import json

# Disable fail-safe (triggered when mouse moves to screen corner)
pyautogui.FAILSAFE = False

# Configuration
REPEAT_COUNT = 1

# Load clicks from JSON file
with open("claim_z_points.json", "r") as f:
    data = json.load(f)

clicks = data["clicks"]

print(f"Loaded {len(clicks)} clicks from claim_z_points.json")
print(f"Will run {REPEAT_COUNT} time")
print("=" * 40)

# Run the sequence
for seq in range(1, REPEAT_COUNT + 1):
    print(f"\n>>> Sequence {seq}/{REPEAT_COUNT}")
    print("-" * 40)
    
    # Execute each click in the sequence
    for i, click in enumerate(clicks, 1):
        x, y = click["x"], click["y"]
        delay = click["delay"]
        
        # Wait before click (skip delay for first click)
        if delay > 0:
            print(f"Waiting {delay}s...")
            time.sleep(delay)
        
        # Perform click
        print(f"Click {i}: ({x}, {y})")
        pyautogui.click(x, y)

print("\n" + "=" * 40)
print("Sequence completed!")
