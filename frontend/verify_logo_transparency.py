#!/usr/bin/env python3
"""
Script to verify that logo files have proper transparency.
"""

from PIL import Image
import os

def verify_transparency(image_path):
    """Verify that an image has transparency."""
    try:
        img = Image.open(image_path)
        print(f"\nChecking: {image_path}")
        print(f"  Mode: {img.mode}")
        print(f"  Size: {img.size}")
        
        has_alpha = img.mode in ['RGBA', 'LA', 'P']
        print(f"  Has alpha channel: {has_alpha}")
        
        if has_alpha:
            if img.mode == 'P':
                # Palette mode - check if transparency is in palette
                transparency = img.info.get('transparency')
                if transparency is not None:
                    print(f"  Transparency: Palette index {transparency}")
                else:
                    print(f"  Transparency: None (but has alpha mode)")
            else:
                # RGBA or LA mode - check for transparent pixels
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                
                # Count transparent pixels
                alpha_channel = img.split()[3]
                transparent_pixels = sum(1 for pixel in alpha_channel.getdata() if pixel < 255)
                total_pixels = img.width * img.height
                transparency_percent = (transparent_pixels / total_pixels) * 100
                
                print(f"  Transparent pixels: {transparent_pixels}/{total_pixels} ({transparency_percent:.1f}%)")
                
                if transparent_pixels > 0:
                    print(f"  [OK] Image has transparent areas")
                    return True
                else:
                    print(f"  [WARNING] Image has alpha channel but no transparent pixels")
                    return False
        else:
            print(f"  [ERROR] Image does not have alpha channel (no transparency)")
            return False
            
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def main():
    print("Verifying logo transparency...")
    print("=" * 60)
    
    files_to_check = [
        'images/logo.png',
        'images/logo_square.png',
        'android/app/src/main/res/drawable/splash_logo.png',
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
    ]
    
    all_ok = True
    for file_path in files_to_check:
        if os.path.exists(file_path):
            if not verify_transparency(file_path):
                all_ok = False
        else:
            print(f"\n[WARNING] File not found: {file_path}")
    
    print("\n" + "=" * 60)
    if all_ok:
        print("[OK] All logo files have proper transparency!")
    else:
        print("[WARNING] Some logo files may not have transparency")
    print("\nNote: The splash screen will display the logo with its transparent background")

if __name__ == '__main__':
    try:
        main()
    except ImportError:
        print("Error: PIL (Pillow) is required. Install it with: pip install Pillow")
    except Exception as e:
        print(f"Error: {e}")

