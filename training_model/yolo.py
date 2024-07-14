from ultralytics import YOLO

model = YOLO("yolov8n.pt")

results = model.train(data="dataSET.yaml", epochs=50, imgsz=240, cache=True)