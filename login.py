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
with open("login.json", "r") as f:
    data = json.load(f)

clicks = data["clicks"]

print(f"Loaded {len(clicks)} clicks from login.json")
print(f"Will run {REPEAT_COUNT} time")
print("=" * 40)

# Run the sequence
for seq in range(1, REPEAT_COUNT + 1):
    print(f"\n>>> Sequence {seq}/{REPEAT_COUNT}")
    print("-" * 40)
    
    # Execute each action in the sequence
    for i, action in enumerate(clicks, 1):
        x, y = action["x"], action["y"]
        delay = action["delay"]
        action_type = action.get("type", "click")  # default to "click" for old recordings

        # Wait before action (skip delay for first action)
        if delay > 0:
            print(f"Waiting {delay}s...")
            time.sleep(delay)

        if action_type == "scroll":
            dx, dy = action.get("dx", 0), action.get("dy", 0)
            print(f"Scroll {i}: ({x}, {y}) dx={dx} dy={dy}")
            if dx:
                pyautogui.hscroll(dx, x=x, y=y)
            if dy:
                pyautogui.scroll(dy, x=x, y=y)
        else:
            print(f"Click {i}: ({x}, {y})")
            pyautogui.click(x, y)

print("\n" + "=" * 40)
print("Sequence completed!")
