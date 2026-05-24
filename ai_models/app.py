from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image, ImageDraw
import io, os, json, base64
import torch
from ultralytics import YOLO
from transformers import VisionEncoderDecoderModel, ViTImageProcessor, AutoTokenizer, pipeline

app = Flask(__name__)
CORS(app)

import logging
# Flask Werkzeug requests logs (Enabled)
log = logging.getLogger('werkzeug')
log.setLevel(logging.INFO)

@app.before_request
def log_request_info():
    print(f"\\n=========================================")
    print(f"[HTTP REQUEST] ---> Received {request.method} request to {request.path}")
    if request.files:
        print(f"Files attached: {list(request.files.keys())}")

@app.after_request
def log_response_info(response):
    print(f"[HTTP RESPONSE] <--- Sent {response.status_code} response for {request.path}")
    print(f"=========================================\\n")
    return response

# Suppress Transformers warning logs
logging.getLogger("transformers").setLevel(logging.ERROR)

# API Key
API_KEY = "social_media_app_2024_secure_key"

print("Loading AI Models...")

# Model 1: Object Detection
obj_model = YOLO('yolov8n.pt')

# Model 2: Image Captioning
cap_model = VisionEncoderDecoderModel.from_pretrained("nlpconnect/vit-gpt2-image-captioning")
cap_processor = ViTImageProcessor.from_pretrained("nlpconnect/vit-gpt2-image-captioning")
cap_tokenizer = AutoTokenizer.from_pretrained("nlpconnect/vit-gpt2-image-captioning")

# Model 3: Deepfake Detection
fake_pipe = pipeline("image-classification", model="umm-maybe/AI-image-detector")

print("All Models Ready!\n")

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def check_api_key():
    key = request.headers.get('X-API-Key')
    if key != API_KEY:
        return False
    return True

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'message': 'AI Server Running'})

@app.route('/detect_objects', methods=['POST'])
def detect_objects():
    print("\n--- NEW OBJECT DETECTION REQUEST ---")
    if not check_api_key():
        print("Error: Invalid API Key")
        return jsonify({'error': 'Invalid API Key'}), 401
    
    if 'image' not in request.files:
        print("Error: No image provided")
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    print(f"Processing image: {file.filename}")
    img = Image.open(file).convert('RGB')
    draw = ImageDraw.Draw(img)
    
    print("--- Analyze Image ---")
    print("--- Detect Objects ---")
    print("Running YOLOv8 model...")
    results = obj_model(img, verbose=False)
    result = results[0]
    
    detections = []
    for box in result.boxes:
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        name = obj_model.names[int(box.cls[0])]
        conf = float(box.conf[0])
        
        draw.rectangle([x1, y1, x2, y2], outline="red", width=3)
        draw.text((x1, y1-15), f"{name} ({conf*100:.1f}%)", fill="red")
        
        detections.append({
            "object": name,
            "label": name,
            "confidence": round(conf*100, 1),
            "bbox": {"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2)}
        })
    
    print("\n--- RESULTS ---")
    print(f"Objects Detected: {[d['object'] for d in detections]}")
    print("--------------------\n")
    
    buffered = io.BytesIO()
    img.save(buffered, format="JPEG")
    encoded = base64.b64encode(buffered.getvalue()).decode()
    
    return jsonify({
        'total_objects': len(detections),
        'detections': detections,
        'objects': [d['object'] for d in detections],
        'marked_image': encoded
    })

@app.route('/generate_caption', methods=['POST'])
def generate_caption():
    print("\n--- NEW IMAGE CAPTION REQUEST ---")
    if not check_api_key():
        print("Error: Invalid API Key")
        return jsonify({'error': 'Invalid API Key'}), 401
    
    if 'image' not in request.files:
        print("Error: No image provided")
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    print(f"Processing image: {file.filename}")
    img = Image.open(file).convert('RGB')
    
    print("--- Captions ---")
    print("Running ViT-GPT2 Image Captioning...")
    pixel_values = cap_processor(images=img, return_tensors="pt").pixel_values
    
    with torch.no_grad():
        output_ids = cap_model.generate(pixel_values, max_length=16, num_beams=4)
    
    caption = cap_tokenizer.decode(output_ids[0], skip_special_tokens=True)
    print("\n--- RESULTS ---")
    print(f"Generated Caption: '{caption}'")
    print("--------------------\n")
    
    return jsonify({'caption': caption})

@app.route('/detect_deepfake', methods=['POST'])
def detect_deepfake():
    print("\n--- NEW DEEPFAKE DETECTION REQUEST ---")
    if not check_api_key():
        print("Error: Invalid API Key")
        return jsonify({'error': 'Invalid API Key'}), 401
    
    if 'image' not in request.files:
        print("Error: No image provided")
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    print(f"Processing image: {file.filename}")
    img = Image.open(file).convert('RGB')
    
    print("Running Deepfake classifier...")
    results = fake_pipe(img)
    highest_class = max(results, key=lambda x: x['score'])
    is_real = 'human' in highest_class['label'].lower() or 'real' in highest_class['label'].lower()
    confidence = float(highest_class['score'])
    
    # Calculate Real vs AI percentages
    real_percent = 0.0
    ai_percent = 0.0
    for r in results:
        label_lower = r['label'].lower()
        if 'human' in label_lower or 'real' in label_lower:
            real_percent = float(r['score']) * 100
        elif 'artificial' in label_lower or 'ai' in label_lower or 'fake' in label_lower:
            ai_percent = float(r['score']) * 100
            
    # Fallback/validation to ensure they sum to ~100
    if real_percent == 0.0 and ai_percent == 0.0:
        if is_real:
            real_percent = confidence * 100
            ai_percent = 100.0 - real_percent
        else:
            ai_percent = confidence * 100
            real_percent = 100.0 - ai_percent
    elif real_percent == 0.0:
        real_percent = max(0.0, 100.0 - ai_percent)
    elif ai_percent == 0.0:
        ai_percent = max(0.0, 100.0 - real_percent)
        
    print("\n--- RESULTS ---")
    print(f"Deepfake Verdict: {'Real' if is_real else 'AI-Generated'} (Real: {real_percent:.1f}%, AI: {ai_percent:.1f}%)")
    print("--------------------\n")
    
    return jsonify({
        'is_real': is_real,
        'confidence': confidence,
        'real_percent': round(real_percent, 1),
        'ai_percent': round(ai_percent, 1),
        'results': [{'label': r['label'], 'score': round(r['score']*100, 1)} for r in results]
    })

@app.route('/process_all', methods=['POST'])
def process_all():
    """Ek hi call mein teeno models ka result"""
    print("\n--- NEW BATCH PROCESS ALL REQUEST ---")
    if not check_api_key():
        print("Error: Invalid API Key")
        return jsonify({'error': 'Invalid API Key'}), 401
    
    if 'image' not in request.files:
        print("Error: No image provided")
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    print(f"Processing image: {file.filename}")
    img = Image.open(file).convert('RGB')
    
    # Object Detection
    print("--- Analyze Image ---")
    print("--- Detect Objects ---")
    print("1. Running YOLOv8 Object Detection...")
    draw = ImageDraw.Draw(img)
    obj_results = obj_model(img, verbose=False)
    detections = []
    for box in obj_results[0].boxes:
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        name = obj_model.names[int(box.cls[0])]
        conf = float(box.conf[0])
        draw.rectangle([x1, y1, x2, y2], outline="red", width=3)
        draw.text((x1, y1-15), f"{name} ({conf*100:.1f}%)", fill="red")
        detections.append({
            "object": name,
            "label": name,
            "confidence": round(conf*100, 1)
        })
    print("\n--- BATCH RESULTS ---")
    print(f"Objects Detected: {[d['object'] for d in detections]}")
    
    buffered = io.BytesIO()
    img.save(buffered, format="JPEG")
    marked_image = base64.b64encode(buffered.getvalue()).decode()
    
    # Caption
    print("--- Captions ---")
    print("2. Running ViT-GPT2 Image Captioning...")
    pixel_values = cap_processor(images=img, return_tensors="pt").pixel_values
    with torch.no_grad():
        output_ids = cap_model.generate(pixel_values, max_length=16, num_beams=4)
    caption = cap_tokenizer.decode(output_ids[0], skip_special_tokens=True)
    print(f"Generated Caption: '{caption}'")
    
    # Deepfake
    print("3. Running Deepfake Detection...")
    fake_results = fake_pipe(img)
    highest_class = max(fake_results, key=lambda x: x['score'])
    is_real = 'human' in highest_class['label'].lower() or 'real' in highest_class['label'].lower()
    confidence = float(highest_class['score'])
    
    # Calculate Real vs AI percentages
    real_percent = 0.0
    ai_percent = 0.0
    for r in fake_results:
        label_lower = r['label'].lower()
        if 'human' in label_lower or 'real' in label_lower:
            real_percent = float(r['score']) * 100
        elif 'artificial' in label_lower or 'ai' in label_lower or 'fake' in label_lower:
            ai_percent = float(r['score']) * 100
            
    if real_percent == 0.0 and ai_percent == 0.0:
        if is_real:
            real_percent = confidence * 100
            ai_percent = 100.0 - real_percent
        else:
            ai_percent = confidence * 100
            real_percent = 100.0 - ai_percent
    elif real_percent == 0.0:
        real_percent = max(0.0, 100.0 - ai_percent)
    elif ai_percent == 0.0:
        ai_percent = max(0.0, 100.0 - real_percent)
        
    print(f"Deepfake Verdict: {'Real' if is_real else 'AI-Generated'} (Real: {real_percent:.1f}%, AI: {ai_percent:.1f}%)")
    print("--------------------\n")
    
    return jsonify({
        'objects': detections,
        'marked_image': marked_image,
        'caption': caption,
        'deepfake': {
            'is_real': is_real,
            'confidence': confidence,
            'real_percent': round(real_percent, 1),
            'ai_percent': round(ai_percent, 1),
            'results': [{'label': r['label'], 'score': round(r['score']*100, 1)} for r in fake_results]
        }
    })

if __name__ == '__main__':
    print("\n🚀 Server: http://0.0.0.0:5000")
    print(f"🔑 API Key: {API_KEY}")
    app.run(host='0.0.0.0', port=5000, debug=False)