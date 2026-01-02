from PIL import Image
import os

image_path = "assets/screenshots/ostim_belge_crop.png"

if os.path.exists(image_path):
    img = Image.open(image_path)
    current_w, current_h = img.size
    print(f"Original size: {current_w}x{current_h}")
    
    target_w = 1080
    if current_w != target_w:
        ratio = target_w / float(current_w)
        target_h = int(current_h * ratio)
        img_resized = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        img_resized.save(image_path)
        print(f"Resized to: {target_w}x{target_h}")
    else:
        print("Image is already 1080px wide.")
else:
    print("Image not found.")
