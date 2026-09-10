import importlib.util
import sys
from pathlib import Path
from types import SimpleNamespace
import unittest


class FakeCapture:
    def __init__(self, frames, opened=True):
        self.frames = list(frames)
        self.opened = opened
        self.released = False

    def isOpened(self):
        return self.opened

    def read(self):
        if self.frames:
            return True, self.frames.pop(0)
        return False, None

    def release(self):
        self.released = True
        self.opened = False


class MultiThreadingTrackerTests(unittest.TestCase):
    @staticmethod
    def load_tracker(capture):
        fake_cv = SimpleNamespace(VideoCapture=lambda source: capture)
        original_cv = sys.modules.get("cv2")
        sys.modules["cv2"] = fake_cv
        try:
            path = Path(__file__).resolve().parents[1] / "core" / "tracker.py"
            spec = importlib.util.spec_from_file_location("tracker_under_test", path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.MultiThreadingTracker
        finally:
            if original_cv is None:
                del sys.modules["cv2"]
            else:
                sys.modules["cv2"] = original_cv

    def test_reads_all_frames_and_releases_capture(self):
        capture = FakeCapture(["first", "second"])
        tracker = self.load_tracker(capture)(queue_size=2).start("sample.mp4")

        self.assertEqual(tracker.read(timeout=1), (True, "first"))
        self.assertEqual(tracker.get_frame(timeout=1), (True, "second"))
        tracker.thread.join(timeout=1)

        self.assertTrue(tracker.stopped)
        self.assertTrue(capture.released)
        self.assertEqual(tracker.frames_read, 2)

    def test_rejects_unavailable_video_source(self):
        capture = FakeCapture([], opened=False)
        tracker_type = self.load_tracker(capture)

        with self.assertRaisesRegex(RuntimeError, "Could not open video source"):
            tracker_type().start("missing.mp4")
        self.assertTrue(capture.released)


if __name__ == "__main__":
    unittest.main()
