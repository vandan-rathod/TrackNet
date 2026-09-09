from ultralytics import YOLO
import cv2 as cv
import os

# Load trained model
model = YOLO(
    r"D:\time_to_code\SIH\runs\detect\number_plate_v2-6\weights\best.pt"
)

# ONLY this image will be tested
image_path = r"D:\time_to_code\SIH\test_image.jpg"

# Check if image exists
print("Image exists:", os.path.exists(image_path))

# Read image
img = cv.imread(image_path)

if img is None:
    print(f"ERROR: Could not load image: {image_path}")
    exit()

# Get original dimensions
h, w = img.shape[:2]

# Your resize logic
max_height = 600

if h > max_height:
    scaleRatio = max_height / float(h)

    targetDimen = (
        int(w * scaleRatio),
        max_height
    )

    resized_frame = cv.resize(
        img,
        targetDimen,
        interpolation=cv.INTER_AREA
    )
else:
    resized_frame = img


# Run YOLO ONLY on this image
results = model(
    resized_frame,
    conf=0.5,
    imgsz=1280
)

print("Number of detections:", len(results[0].boxes))


# Draw results
annotated_frame = results[0].plot()


# Print detections
for box in results[0].boxes:
    x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
    confidence = float(box.conf[0])

    print("\nPlate detected!")
    print("Confidence:", confidence)
    print("Bounding box:", x1, y1, x2, y2)


# Show result
cv.imshow("Number Plate Detection", annotated_frame)

cv.waitKey(0)
cv.destroyAllWindows()