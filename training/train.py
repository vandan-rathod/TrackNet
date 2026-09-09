from ultralytics import YOLO
import torch

# Check GPU
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))

def main():
    model = YOLO("yolo11n.pt")

    results = model.train(
        data=r"D:\time_to_code\SIH\Dataset\yolo_plate_dataset\data.yaml",
        epochs=100,
        imgsz=640,
        batch=16,
        device=0,
        workers=2,         # 2 workers is ideal on Windows with 16GB RAM
        cache=False,       # Disabled to prevent memory crashes (dataset is 6,000+ images)
        amp=True,          # FP16 Tensor Core acceleration
        rect=True,         # Rectangular batching
        project=r"D:\time_to_code\SIH\runs\detect",
        name="number_plate_v2",
        pretrained=True,
        patience=10
    )

if __name__ == "__main__":
    main()