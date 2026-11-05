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
REPEAT_COUNT = 2000
SEQUENCE_DELAY = 5  # seconds between sequences

# Load clicks from JSON file
with open("heal.json", "r") as f:
    data = json.load(f)

clicks = data["clicks"]

print(f"Loaded {len(clicks)} clicks from heal.json")
print(f"Will repeat {REPEAT_COUNT} times with {SEQUENCE_DELAY}s delay between sequences")
print("=" * 40)

# Repeat the sequence
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
    
    # Wait between sequences (skip after last sequence)
    if seq < REPEAT_COUNT:
        print(f"\nWaiting {SEQUENCE_DELAY}s before next sequence...")
        time.sleep(SEQUENCE_DELAY)

print("\n" + "=" * 40)
print("All sequences completed!")

