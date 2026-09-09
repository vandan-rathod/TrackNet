from engine.multithreading_tracking import MultiThreadingTracker  # pyright: ignore[reportMissingImports]
import cv2 as cv
import time

mtt = MultiThreadingTracker()

print("Initializing video capture thread...") 
mtt.start_cap_thread(r"D:\time_to_code\SIH\Dataset\vecteezy_new-york-us-03-02-2025-brooklyn-bridge-traffic-with-cars_57852135.mp4")

# --- FIX 1: Create a normal, resizable window BEFORE the loop ---
window_name = "Multi-Threading Tracking Pipeline"
cv.namedWindow(window_name, cv.WINDOW_NORMAL) 

# Optional: Set a starting default window size on your screen
cv.resizeWindow(window_name, 960, 540) 

while True:
    ret, frame = mtt.get_frame()
    
    if not ret:
        if mtt.stopped: 
            print("Video ended or thread stopped.")
            break
        time.sleep(0.001) 
        continue
    
    # --- FIX 2: Compute scaling factor to preserve natural aspect ratio ---
    # Choose a maximum target width you want on your screen (e.g., 1000 pixels)
    target_width = 1000 
    
    # Get original image height and width
    h, w = frame.shape[:2]
    
    # Calculate aspect ratio factor
    scale_factor = target_width / float(w)
    target_height = int(h * scale_factor)
    
    # Resize cleanly without any stretching or distortion
    resized_frame = cv.resize(frame, (target_width, target_height), interpolation=cv.INTER_AREA)
    
    # --- Show the resized frame inside the named window ---
    cv.imshow(window_name, resized_frame)
    
    key = cv.waitKey(1) # Restricts playback to ~30 FPS speed
    if key == 27: # ESC key
        break

mtt.release()
cv.destroyAllWindows()
print("Cleaned up and exited successfully.")
