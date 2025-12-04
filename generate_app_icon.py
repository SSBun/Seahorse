import os
import subprocess
import json
import shutil

def generate_app_icon(source_image_path, output_dir):
    if not os.path.exists(source_image_path):
        print(f"Error: Source image not found at {source_image_path}")
        return

    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    images = []
    
    # Define sizes and scales
    # (size, scale, idiom)
    configs = [
        (16, 1, "mac"), (16, 2, "mac"),
        (32, 1, "mac"), (32, 2, "mac"),
        (128, 1, "mac"), (128, 2, "mac"),
        (256, 1, "mac"), (256, 2, "mac"),
        (512, 1, "mac"), (512, 2, "mac")
    ]

    for size, scale, idiom in configs:
        pixel_size = size * scale
        filename = f"icon_{size}x{size}@{scale}x.png"
        output_path = os.path.join(output_dir, filename)
        
        # Resize using sips
        try:
            subprocess.run([
                "sips", 
                "-z", str(pixel_size), str(pixel_size), 
                source_image_path, 
                "--out", output_path
            ], check=True, stdout=subprocess.DEVNULL)
            
            images.append({
                "size": f"{size}x{size}",
                "idiom": idiom,
                "filename": filename,
                "scale": f"{scale}x"
            })
            print(f"Generated {filename}")
        except subprocess.CalledProcessError as e:
            print(f"Error generating {filename}: {e}")

    # Create Contents.json
    contents = {
        "images": images,
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }

    with open(os.path.join(output_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    
    print(f"Successfully generated AppIcon.appiconset at {output_dir}")

if __name__ == "__main__":
    source = "Seahorse/Assets.xcassets/seahorseIcon.imageset/seahorseIcon.png"
    output = "Seahorse/Assets.xcassets/AppIcon.appiconset"
    generate_app_icon(source, output)
