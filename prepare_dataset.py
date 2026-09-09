import os
import shutil
import random
from pathlib import Path

# ==============================
# PATHS
# ==============================

SOURCE = Path(
    r"D:\time_to_code\SIH\Dataset\dataset\licence plate.v1i.darknet"
)

DESTINATION = Path(
    r"D:\time_to_code\SIH\Dataset\yolo_plate_dataset"
)

SOURCE_TRAIN = SOURCE / "train"
SOURCE_TEST = SOURCE / "test"

# ==============================
# SETTINGS
# ==============================

VAL_RATIO = 0.20
RANDOM_SEED = 42

random.seed(RANDOM_SEED)

# ==============================
# CREATE FOLDERS
# ==============================

for split in ["train", "val", "test"]:
    (DESTINATION / "images" / split).mkdir(
        parents=True,
        exist_ok=True
    )

    (DESTINATION / "labels" / split).mkdir(
        parents=True,
        exist_ok=True
    )


# ==============================
# GET VALID TRAIN PAIRS
# ==============================

train_pairs = []

for image_path in SOURCE_TRAIN.glob("*.jpg"):

    label_path = image_path.with_suffix(".txt")

    if label_path.exists():
        train_pairs.append(
            (image_path, label_path)
        )
    else:
        print(
            f"Skipping image without label: "
            f"{image_path.name}"
        )


print(f"\nValid training pairs: {len(train_pairs)}")


# ==============================
# SHUFFLE
# ==============================

random.shuffle(train_pairs)

val_count = int(
    len(train_pairs) * VAL_RATIO
)

val_pairs = train_pairs[:val_count]
train_pairs_final = train_pairs[val_count:]


print(f"Training images: {len(train_pairs_final)}")
print(f"Validation images: {len(val_pairs)}")


# ==============================
# COPY FUNCTION
# ==============================

def copy_pairs(pairs, split):

    for image_path, label_path in pairs:

        shutil.copy2(
            image_path,
            DESTINATION / "images" / split / image_path.name
        )

        shutil.copy2(
            label_path,
            DESTINATION / "labels" / split / label_path.name
        )


# ==============================
# COPY TRAIN + VAL
# ==============================

copy_pairs(
    train_pairs_final,
    "train"
)

copy_pairs(
    val_pairs,
    "val"
)


# ==============================
# COPY TEST
# ==============================

test_pairs = []

for image_path in SOURCE_TEST.glob("*.jpg"):

    label_path = image_path.with_suffix(".txt")

    if label_path.exists():
        test_pairs.append(
            (image_path, label_path)
        )
    else:
        print(
            f"Skipping test image without label: "
            f"{image_path.name}"
        )


copy_pairs(
    test_pairs,
    "test"
)


print(f"Test images: {len(test_pairs)}")


# ==============================
# CREATE DATA.YAML
# ==============================

yaml_content = f"""path: {DESTINATION.as_posix()}
train: images/train
val: images/val
test: images/test

names:
  0: license_plate
"""

with open(
    DESTINATION / "data.yaml",
    "w"
) as file:
    file.write(yaml_content)


print("\nDataset preparation complete! 🔥")
print(f"Dataset location: {DESTINATION}")