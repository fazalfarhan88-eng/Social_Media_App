from transformers import VisionEncoderDecoderModel, ViTImageProcessor, AutoTokenizer
from PIL import Image
import torch
import sys

print("Model load ho raha hai...")
model = VisionEncoderDecoderModel.from_pretrained("nlpconnect/vit-gpt2-image-captioning")
feature_extractor = ViTImageProcessor.from_pretrained("nlpconnect/vit-gpt2-image-captioning")
tokenizer = AutoTokenizer.from_pretrained("nlpconnect/vit-gpt2-image-captioning")
print("Model ready!\n")

def caption_image(image_path):
    img = Image.open(image_path)
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    pixel_values = feature_extractor(images=img, return_tensors="pt").pixel_values
    
    with torch.no_grad():
        output_ids = model.generate(pixel_values, max_length=16, num_beams=4)
    
    caption = tokenizer.decode(output_ids[0], skip_special_tokens=True)
    return caption

if __name__ == "__main__":
    if len(sys.argv) > 1:
        img = sys.argv[1]
    else:
        img = input("Enter image name: ")
    
    caption = caption_image(img)
    print(f"Caption: {caption}")
    