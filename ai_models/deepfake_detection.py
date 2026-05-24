from transformers import pipeline
from PIL import Image
import sys

print("Loading Deepfake Detection Model...")
pipe = pipeline("image-classification", model="umm-maybe/AI-image-detector")
print("Model Ready!\n")

def detect_real_or_fake(image_path):
    try:
        img = Image.open(image_path).convert("RGB")
    except FileNotFoundError:
        print(f"Image not found: {image_path}")
        return

    results = pipe(img)
    
    print(f"\nResult for '{image_path}':")
    for r in results:
        print(f"  {r['label']}: {r['score']*100:.2f}%")
    
    return results

if __name__ == "__main__":
    img = sys.argv[1] if len(sys.argv) > 1 else input("Enter image name: ")
    detect_real_or_fake(img)