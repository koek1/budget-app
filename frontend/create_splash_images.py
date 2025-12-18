#!/usr/bin/env python3
"""
Script to create splash screen images from the logo with transparent background.
Generates properly sized images for iOS LaunchImage assets.
"""

from PIL import Image
import os

def create_splash_images():
    """Create splash screen images from logo with transparent background."""
    logo_path = 'images/logo.png'
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found!")
        return
    
    # Read the original logo
    logo = Image.open(logo_path).convert('RGBA')
    
    # iOS LaunchImage sizes (approximate, will be scaled by iOS)
    # Standard sizes: 1x, 2x, 3x
    # We'll create a high-res version that iOS can scale down
    base_size = 1024  # High resolution base
    
    # Calculate size maintaining aspect ratio
    aspect_ratio = logo.width / logo.height
    if logo.width > logo.height:
        # Landscape: fit width
        new_width = base_size
        new_height = int(base_size / aspect_ratio)
    else:
        # Portrait: fit height
        new_height = base_size
        new_width = int(base_size * aspect_ratio)
    
    # Resize logo maintaining aspect ratio and transparency
    resized_logo = logo.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Output directory
    output_dir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    os.makedirs(output_dir, exist_ok=True)
    
    # Create 1x, 2x, and 3x versions
    # For simplicity, we'll use the same high-res image for all scales
    # iOS will scale appropriately
    sizes = [
        ('LaunchImage.png', 1),
        ('LaunchImage@2x.png', 2),
        ('LaunchImage@3x.png', 3),
    ]
    
    print("Creating iOS splash screen images...")
    print(f"Original logo: {logo.width}x{logo.height}px")
    print(f"Resized logo: {new_width}x{new_height}px")
    
    for filename, scale in sizes:
        # For each scale, we could create different sizes, but using high-res for all
        # iOS will scale down as needed
        output_path = os.path.join(output_dir, filename)
        resized_logo.save(output_path, 'PNG', optimize=False)
        print(f"  Created: {filename} ({new_width}x{new_height}px)")
    
    print(f"\n[OK] Splash screen images created in {output_dir}")
    print("Images have transparent backgrounds preserved.")

if __name__ == '__main__':
    try:
        create_splash_images()
    except ImportError:
        print("Error: PIL (Pillow) is required. Install it with: pip install Pillow")
    except Exception as e:
        print(f"Error: {e}")

