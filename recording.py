import ctypes
# Make Python DPI-aware to get correct screen coordinates on Windows 10/11
# This must be called BEFORE importing pyautogui
ctypes.windll.shcore.SetProcessDpiAwareness(2)  # PROCESS_PER_MONITOR_DPI_AWARE

from pynput import mouse, keyboard
import pyautogui
import time
import json

# Store recorded actions (clicks and scrolls)
clicks = []
last_event_time = None
running = True

def on_click(x, y, button, pressed):
    global last_event_time

    if not running:
        return False

    # Only record left clicks when pressed (not released)
    if button == mouse.Button.left and pressed:
        current_time = time.time()

        # Use pyautogui to get position (consistent with playback coordinates)
        pos_x, pos_y = pyautogui.position()

        # Calculate delay from last recorded event
        if last_event_time is None:
            delay = 0
        else:
            delay = round(current_time - last_event_time, 3)

        last_event_time = current_time

        event_data = {"type": "click", "x": pos_x, "y": pos_y, "delay": delay}
        clicks.append(event_data)
        print(f"Recorded click #{len(clicks)}: ({pos_x}, {pos_y}) - delay: {delay}s")

def on_scroll(x, y, dx, dy):
    global last_event_time

    if not running:
        return False

    current_time = time.time()

    # Use pyautogui to get position (consistent with playback coordinates)
    pos_x, pos_y = pyautogui.position()

    # Calculate delay from last recorded event
    if last_event_time is None:
        delay = 0
    else:
        delay = round(current_time - last_event_time, 3)

    last_event_time = current_time

    event_data = {"type": "scroll", "x": pos_x, "y": pos_y, "dx": dx, "dy": dy, "delay": delay}
    clicks.append(event_data)
    print(f"Recorded scroll #{len(clicks)}: ({pos_x}, {pos_y}) dx={dx} dy={dy} - delay: {delay}s")

def on_press(key):
    global running

    if key == keyboard.Key.esc:
        running = False
        print("\nEscape pressed. Stopping recording...")
        return False

def save_clicks():
    output = {"clicks": clicks}
    with open("recording.json", "w") as f:
        json.dump(output, f, indent=2)
    print(f"\nSaved {len(clicks)} actions to recording.json")

# Main
print("=" * 50)
print("Mouse Click & Scroll Recorder")
print("=" * 50)
print("Left-click anywhere to record positions and timing.")
print("Scroll the mouse wheel anywhere to record scroll events.")
print("Press ESCAPE to stop recording and save to recording.json")
print("=" * 50)
print()

# Start keyboard listener in a separate thread
keyboard_listener = keyboard.Listener(on_press=on_press)
keyboard_listener.start()

# Start mouse listener (blocking)
with mouse.Listener(on_click=on_click, on_scroll=on_scroll) as mouse_listener:
    while running:
        time.sleep(0.1)

# Save recorded actions
if clicks:
    save_clicks()
else:
    print("No actions recorded.")

print("Recording finished!")
