#!/usr/bin/env python3
"""
Script to fix transparency in generated launcher icon foreground files.
Removes black backgrounds and restores transparency.
"""

from PIL import Image
import os
import glob

def remove_black_background(image_path):
    """Remove black background and restore transparency."""
    try:
        img = Image.open(image_path)
        
        # Convert to RGBA if not already
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Get image data
        data = img.getdata()
        
        # Create new image data with transparency
        new_data = []
        for item in data:
            # Only remove pure black pixels (0,0,0) with full opacity
            # These are the background pixels added by flutter_launcher_icons
            # We preserve dark colors that are part of the logo
            if item[0] == 0 and item[1] == 0 and item[2] == 0 and item[3] == 255:
                # Make transparent - this is the black background
                new_data.append((0, 0, 0, 0))
            else:
                # Keep original pixel (including any existing transparency)
                new_data.append(item)
        
        # Update image with new data
        img.putdata(new_data)
        
        # Save the image
        img.save(image_path, 'PNG', optimize=False)
        print(f"  Fixed: {image_path}")
        return True
    except Exception as e:
        print(f"  Error processing {image_path}: {e}")
        return False

def fix_all_foreground_icons():
    """Fix all foreground icon files in the Android res directory."""
    base_path = 'android/app/src/main/res'
    
    # Find all foreground icon files and mipmap icons
    foreground_patterns = [
        f'{base_path}/drawable-*/ic_launcher_foreground.png',
        f'{base_path}/drawable/ic_launcher_foreground.png',
        f'{base_path}/mipmap-*/ic_launcher.png',
    ]
    
    fixed_count = 0
    total_count = 0
    
    print("Fixing launcher icon transparency...")
    print("=" * 50)
    
    for pattern in foreground_patterns:
        files = glob.glob(pattern)
        for file_path in files:
            total_count += 1
            if remove_black_background(file_path):
                fixed_count += 1
    
    print("=" * 50)
    print(f"Fixed {fixed_count} out of {total_count} icon files")
    
    if fixed_count > 0:
        print("\n[OK] Icon transparency fixed!")
        print("Rebuild the app to see the changes.")
    else:
        print("\nNo icon files found or fixed.")

if __name__ == '__main__':
    try:
        fix_all_foreground_icons()
    except ImportError:
        print("Error: PIL (Pillow) is required. Install it with: pip install Pillow")
    except Exception as e:
        print(f"Error: {e}")

