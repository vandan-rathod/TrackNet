"""Threaded OpenCV frame capture for responsive tracking pipelines."""

from __future__ import annotations

from queue import Empty, Full, Queue
from threading import Event, Lock, Thread, current_thread
from typing import Any

import cv2 as cv


class MultiThreadingTracker:
    """Read frames on a background thread and expose them through a queue."""

    def __init__(self, queue_size: int = 128):
        if queue_size < 1:
            raise ValueError("queue_size must be at least 1")

        self.frame_queue: Queue[Any] = Queue(maxsize=queue_size)
        self.cap: Any | None = None
        self.thread: Thread | None = None
        self.last_error: Exception | None = None
        self.frames_read = 0

        self._stop_event = Event()
        self._finished_event = Event()
        self._capture_lock = Lock()

    @property
    def stopped(self) -> bool:
        """Whether capture has completed, failed, or been released."""
        return self._finished_event.is_set()

    @property
    def is_running(self) -> bool:
        return self.thread is not None and self.thread.is_alive()

    def start(self, video_source: str | int) -> "MultiThreadingTracker":
        """Open ``video_source`` and begin reading frames in the background."""
        if self.is_running:
            raise RuntimeError("Capture thread is already running")

        self._reset_for_start()
        capture = cv.VideoCapture(video_source)
        if not capture.isOpened():
            capture.release()
            raise RuntimeError(f"Could not open video source: {video_source!r}")

        with self._capture_lock:
            self.cap = capture
        self.thread = Thread(target=self._capture_frames, name="frame-capture", daemon=True)
        self.thread.start()
        return self

    def start_cap_thread(self, video_source: str | int) -> bool:
        """Backward-compatible wrapper for the original tracker API."""
        self.start(video_source)
        return True

    def read(self, timeout: float | None = 0.0) -> tuple[bool, Any | None]:
        """Return the next frame, waiting up to ``timeout`` seconds if requested."""
        try:
            if timeout is None:
                return True, self.frame_queue.get()
            if timeout < 0:
                raise ValueError("timeout must be non-negative or None")
            if timeout == 0:
                return True, self.frame_queue.get_nowait()
            return True, self.frame_queue.get(timeout=timeout)
        except Empty:
            return False, None

    def get_frame(self, timeout: float | None = 0.0) -> tuple[bool, Any | None]:
        """Backward-compatible alias for :meth:`read`."""
        return self.read(timeout)

    def release(self, timeout: float = 2.0) -> None:
        """Stop capture, release OpenCV resources, and wait for the worker."""
        self._stop_event.set()
        capture = self._detach_capture()
        if capture is not None:
            capture.release()
        if self.thread is not None and self.thread is not current_thread():
            self.thread.join(timeout=timeout)
        self._finished_event.set()

    def __enter__(self) -> "MultiThreadingTracker":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.release()

    def _reset_for_start(self) -> None:
        self.frame_queue = Queue(maxsize=self.frame_queue.maxsize)
        self.last_error = None
        self.frames_read = 0
        self._stop_event.clear()
        self._finished_event.clear()

    def _capture_frames(self) -> None:
        try:
            while not self._stop_event.is_set():
                capture = self.cap
                if capture is None:
                    break
                ok, frame = capture.read()
                if not ok:
                    break
                self.frames_read += 1
                self._enqueue(frame)
        except Exception as error:
            self.last_error = error
        finally:
            capture = self._detach_capture()
            if capture is not None:
                capture.release()
            self._finished_event.set()

    def _enqueue(self, frame: Any) -> None:
        while not self._stop_event.is_set():
            try:
                self.frame_queue.put(frame, timeout=0.1)
                return
            except Full:
                continue

    def _detach_capture(self) -> Any | None:
        with self._capture_lock:
            capture = self.cap
            self.cap = None
            return capture
