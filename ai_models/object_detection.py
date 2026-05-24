from ultralytics import YOLO
from PIL import Image, ImageDraw
import json, sys

def detect_and_mark(image_path, conf=0.4):
    print(f"\nProcessing: {image_path}")
    
    model = YOLO('yolov8n.pt')
    results = model(image_path, conf=conf)
    result = results[0]
    
    if len(result.boxes) == 0:
        print("No object found!")
        return
    
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    output_data = []
    
    print(f"\nFound {len(result.boxes)} objects:\n")
    
    for i, box in enumerate(result.boxes, 1):
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        cls = int(box.cls[0])
        name = model.names[cls]
        conf = float(box.conf[0])
        label = f"{name} ({conf*100:.1f}%)"
        
        print(f"  {i}. {name.upper()} - {conf*100:.1f}%")
        
        draw.rectangle([x1, y1, x2, y2], outline="red", width=3)
        draw.text((x1, y1-15), label, fill="red")
        
        output_data.append({
            "object": name,
            "confidence": round(conf*100, 1),
            "bbox": {"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2)}
        })
    
    output_img = f"detected_{image_path}"
    img.save(output_img)
    print(f"\nImage saved: {output_img}")
    
    output_json = f"result_{image_path.split('.')[0]}.json"
    with open(output_json, "w") as f:
        json.dump(output_data, f, indent=2)
    print(f"JSON saved: {output_json}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        detect_and_mark(sys.argv[1])
    else:
        image = input("Enter image name: ")
        detect_and_mark(image)

        