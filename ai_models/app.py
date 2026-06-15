from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image, ImageDraw, ImageOps
import io, base64, torch, os, logging
from ultralytics import YOLO
from transformers import BlipProcessor, BlipForConditionalGeneration, pipeline

app = Flask(__name__)
CORS(app)

log = logging.getLogger('werkzeug')
log.setLevel(logging.INFO)

API_KEY = "social_media_app_2024_secure_key"
device = "cuda" if torch.cuda.is_available() else "cpu"

print("Loading Default AI Models...")
obj_model = YOLO('yolov8n.pt')
cap_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
cap_model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base").to(device)
fake_pipe = pipeline("image-classification", model="umm-maybe/AI-image-detector", device=0 if device=="cuda" else -1)
print("Models Loaded Successfully!")

def get_processed_img(req):
    if 'image' not in req.files: return None
    file = req.files['image']
    img = Image.open(file).convert('RGB')
    return ImageOps.exif_transpose(img)

@app.route('/detect_objects', methods=['POST'])
def detect_objects():
    if request.headers.get('X-API-Key') != API_KEY: return jsonify({'error': 'Unauthorized'}), 401
    img = get_processed_img(request)
    if img is None: return jsonify({'error': 'No image'}), 400
    
    results = obj_model(img, conf=0.25, verbose=False)
    draw = ImageDraw.Draw(img)
    detections = []
    for box in results[0].boxes:
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        name = obj_model.names[int(box.cls[0])]
        conf = float(box.conf[0])
        draw.rectangle([x1, y1, x2, y2], outline="red", width=3)
        draw.text((x1, y1), name, fill="red")
        detections.append({'label': name.capitalize(), 'confidence': round(conf * 100, 2)})
    
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return jsonify({'objects': detections, 'marked_image': base64.b64encode(buf.getvalue()).decode()})

@app.route('/generate_caption', methods=['POST'])
def generate_caption():
    if request.headers.get('X-API-Key') != API_KEY: return jsonify({'error': 'Unauthorized'}), 401
    img = get_processed_img(request)
    if img is None: return jsonify({'error': 'No image'}), 400
    
    inputs = cap_processor(img, return_tensors="pt").to(device)
    with torch.no_grad():
        out = cap_model.generate(**inputs, max_new_tokens=40)
    caption = cap_processor.decode(out[0], skip_special_tokens=True)
    return jsonify({'caption': caption.capitalize()})

@app.route('/detect_deepfake', methods=['POST'])
def detect_deepfake():
    if request.headers.get('X-API-Key') != API_KEY: return jsonify({'error': 'Unauthorized'}), 401
    img = get_processed_img(request)
    if img is None: return jsonify({'error': 'No image'}), 400
    
    res = fake_pipe(img)
    highest = max(res, key=lambda x: x['score'])
    is_real = 'real' in highest['label'].lower() or 'human' in highest['label'].lower()
    return jsonify({
        'is_real': is_real, 
        'confidence': highest['score'], 
        'verdict': 'Verdict: Real' if is_real else 'Verdict: AI Generated'
    })

@app.route('/process_all', methods=['POST'])
def process_all():
    if request.headers.get('X-API-Key') != API_KEY: return jsonify({'error': 'Unauthorized'}), 401
    img = get_processed_img(request)
    if img is None: return jsonify({'error': 'No image'}), 400
    
    res_obj = obj_model(img, conf=0.25, verbose=False)
    detections = [{'label': obj_model.names[int(box.cls[0])].capitalize()} for box in res_obj[0].boxes]
    
    inputs = cap_processor(img, return_tensors="pt").to(device)
    with torch.no_grad():
        out_cap = cap_model.generate(**inputs, max_new_tokens=40)
    caption = cap_processor.decode(out_cap[0], skip_special_tokens=True)
    
    res_fake = fake_pipe(img)
    high = max(res_fake, key=lambda x: x['score'])
    is_real = 'real' in high['label'].lower() or 'human' in high['label'].lower()
    
    return jsonify({
        'objects': detections,
        'caption': caption.capitalize(),
        'deepfake': {'is_real': is_real, 'confidence': high['score'], 'verdict': 'Verdict: Real' if is_real else 'Verdict: AI Generated'}
    })

if __name__ == '__main__':
    print(f"\nServer Running: http://0.0.0.0:5000\nAPI KEY: {API_KEY}")
    app.run(host='0.0.0.0', port=5000, debug=False)
