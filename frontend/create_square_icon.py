#!/usr/bin/env python3
"""
Script to create a square version of the logo for Android launcher icon.
This ensures the landscape logo (668x374) is properly centered in a square
with transparent padding, preventing vertical stretching.
"""

from PIL import Image
import os

def create_square_icon():
    # Original logo dimensions
    original_width = 668
    original_height = 374
    aspect_ratio = original_width / original_height  # 1.787:1
    
    # Read the original logo
    logo_path = 'images/logo.png'
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found!")
        return
    
    original_logo = Image.open(logo_path)
    
    # Create a square canvas - use the width as the square size
    # This ensures the logo fits horizontally with padding on top/bottom
    square_size = max(original_width, original_height)
    
    # For better results, use a larger square (1024x1024 is standard for icons)
    square_size = 1024
    
    # Calculate padding to center the logo
    # Logo will be scaled to fit within the square while maintaining aspect ratio
    if original_width > original_height:
        # Landscape: fit to width, add vertical padding
        scaled_width = square_size
        scaled_height = int(square_size / aspect_ratio)
        x_offset = 0
        y_offset = (square_size - scaled_height) // 2
    else:
        # Portrait: fit to height, add horizontal padding
        scaled_height = square_size
        scaled_width = int(square_size * aspect_ratio)
        x_offset = (square_size - scaled_width) // 2
        y_offset = 0
    
    # Create square image with transparent background
    square_icon = Image.new('RGBA', (square_size, square_size), (0, 0, 0, 0))
    
    # Resize logo maintaining aspect ratio
    resized_logo = original_logo.resize((scaled_width, scaled_height), Image.Resampling.LANCZOS)
    
    # Paste logo centered in square
    square_icon.paste(resized_logo, (x_offset, y_offset), resized_logo if resized_logo.mode == 'RGBA' else None)
    
    # Save square icon
    output_path = 'images/logo_square.png'
    square_icon.save(output_path, 'PNG')
    print(f"✓ Created square icon: {output_path}")
    print(f"  Size: {square_size}x{square_size}px")
    print(f"  Logo centered with transparent padding")
    print(f"\nNext steps:")
    print(f"1. Update pubspec.yaml to use 'images/logo_square.png' for adaptive_icon_foreground")
    print(f"2. Run: flutter pub run flutter_launcher_icons")

if __name__ == '__main__':
    try:
        create_square_icon()
    except ImportError:
        print("Error: PIL (Pillow) is required. Install it with: pip install Pillow")
    except Exception as e:
        print(f"Error: {e}")

