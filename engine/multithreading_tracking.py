import cv2 as cv
import threading
import queue
import time

class MultiThreadingTracker:
    def __init__(self,queue_size=128):
        self.cap=None
        self.frame_queue=queue.Queue(maxsize=queue_size)
        self.stopped=False
        self.thread=None
        
    def start_cap_thread(self,video_source):
        self.cap=cv.VideoCapture(video_source)
        if not self.cap.isOpened():
            print(f"Error: could not open video source {video_source}")
            return False
        self.stopped=False
        self.thread=threading.Thread(target=self._update, args=())
        self.thread.daemon=True
        self.thread.start()
        return True
    
    def _update(self):
        while not self.stopped:
            if not self.frame_queue.full():
                ret,frame=self.cap.read()
                if not ret:
                    self.stopped=True
                    break
                self.frame_queue.put((ret,frame))
            else:
                time.sleep(0.005)
                
        self.cap.release()
        
    def get_frame(self):
        if not self.frame_queue.empty():
            return self.frame_queue.get()
        else:
            if self.stopped:
                return False,None
            return False,None
    
    def release(self):
        self.stopped=True
        if self.thread is not None:
            self.thread.join(timeout=1.0)
        if self.cap and self.cap.isOpened():
            self.cap.release()