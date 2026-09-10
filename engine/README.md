# Engine

The engine reads OpenCV frames on a background thread so detection and OCR can
run on the foreground pipeline without blocking camera capture.

Install its dependencies from the repository root:

```powershell
python -m pip install -r engine/requirements.txt
```

Preview a local camera or video file:

```powershell
python -m engine.tools.opencv_test 0
python -m engine.tools.opencv_test path/to/traffic.mp4 --width 1280
```

Press `Esc` to close the preview. The interactive example lives in
`engine/notebooks/multithreaded_tracker_demo.ipynb`.
