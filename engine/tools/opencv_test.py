"""Preview frames read by ``MultiThreadingTracker`` from a camera or video."""

import argparse

import cv2 as cv

from engine.core.tracker import MultiThreadingTracker


def video_source(value):
    try:
        return int(value)
    except ValueError:
        return value


def positive_int(value):
    integer = int(value)
    if integer < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return integer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=video_source, help="Video path, stream URL, or camera index")
    parser.add_argument("--width", type=positive_int, default=1000)
    args = parser.parse_args()

    window_name = "Multi-Threading Tracking Pipeline"
    cv.namedWindow(window_name, cv.WINDOW_NORMAL)
    with MultiThreadingTracker().start(args.source) as tracker:
        while True:
            ok, frame = tracker.read(timeout=0.1)
            if not ok:
                if tracker.stopped:
                    break
                continue
            height, width = frame.shape[:2]
            scale = min(1.0, args.width / width)
            preview = cv.resize(frame, (int(width * scale), int(height * scale)))
            cv.imshow(window_name, preview)
            if cv.waitKey(1) == 27:
                break
    cv.destroyAllWindows()


if __name__ == "__main__":
    main()
