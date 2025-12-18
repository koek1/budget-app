#!/usr/bin/env python3
"""
Script to create a square version of the logo for Android launcher icon.
This ensures the landscape logo is properly centered in a square
with transparent padding, preventing vertical stretching.
The script auto-detects the actual content bounds (removes transparent padding).
"""

from PIL import Image
import os

def get_content_bounds(img):
    """Get the bounding box of non-transparent content."""
    if img.mode != 'RGBA':
        # Convert to RGBA if not already
        img = img.convert('RGBA')
    
    # Get alpha channel
    alpha = img.split()[3]
    
    # Get bounding box of non-transparent pixels
    bbox = alpha.getbbox()
    
    if bbox is None:
        # No content found, return full image bounds
        return (0, 0, img.width, img.height)
    
    return bbox

def create_square_icon():
    # Read the original logo
    logo_path = 'images/logo.png'
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found!")
        return
    
    original_logo = Image.open(logo_path).convert('RGBA')
    
    # Get actual content bounds (removes transparent padding)
    bbox = get_content_bounds(original_logo)
    content_width = bbox[2] - bbox[0]
    content_height = bbox[3] - bbox[1]
    
    print(f"Original image size: {original_logo.width}x{original_logo.height}px")
    print(f"Content bounds: {content_width}x{content_height}px (x:{bbox[0]}, y:{bbox[1]})")
    
    # Crop to content bounds
    content_logo = original_logo.crop(bbox)
    
    # Calculate aspect ratio of actual content
    aspect_ratio = content_width / content_height
    
    # Use standard icon size (1024x1024 is standard for high-res icons)
    square_size = 1024
    
    # Scale to fit within 50% of the square to provide nice padding
    # This prevents the logo from being too zoomed in
    max_size = int(square_size * 0.50)
    
    # Calculate how to fit the content in the square while maintaining aspect ratio
    if content_width > content_height:
        # Landscape: scale based on width, ensure it fits
        scaled_width = max_size
        scaled_height = int(max_size / aspect_ratio)
        # If height exceeds max_size, scale based on height instead
        if scaled_height > max_size:
            scaled_height = max_size
            scaled_width = int(max_size * aspect_ratio)
    else:
        # Portrait: scale based on height, ensure it fits
        scaled_height = max_size
        scaled_width = int(max_size * aspect_ratio)
        # If width exceeds max_size, scale based on width instead
        if scaled_width > max_size:
            scaled_width = max_size
            scaled_height = int(max_size / aspect_ratio)
    
    # Calculate perfect center position
    # For perfect centering, we need to handle odd/even differences properly
    total_horizontal_padding = square_size - scaled_width
    total_vertical_padding = square_size - scaled_height
    
    # Distribute padding evenly, with any 1px difference going to the left/top
    x_offset = total_horizontal_padding // 2
    y_offset = total_vertical_padding // 2
    
    # Verify centering (should be symmetric or at most 1px difference)
    left_padding = x_offset
    right_padding = square_size - x_offset - scaled_width
    top_padding = y_offset
    bottom_padding = square_size - y_offset - scaled_height
    
    print(f"  Centering details:")
    print(f"    Horizontal padding: left={left_padding}px, right={right_padding}px (diff: {abs(left_padding - right_padding)}px)")
    print(f"    Vertical padding: top={top_padding}px, bottom={bottom_padding}px (diff: {abs(top_padding - bottom_padding)}px)")
    
    # If there's a 1px difference, ensure it's distributed evenly by adjusting
    # We want the logo visually centered, so if there's a difference, put the extra pixel on both sides if possible
    # Actually, for visual centering, a 1px difference is acceptable and often imperceptible
    # But let's try to make it as symmetric as possible
    
    # Create square image with transparent background
    square_icon = Image.new('RGBA', (square_size, square_size), (0, 0, 0, 0))
    
    # Resize content logo maintaining aspect ratio (use high-quality resampling)
    resized_logo = content_logo.resize((scaled_width, scaled_height), Image.Resampling.LANCZOS)
    
    # Ensure resized logo has alpha channel for transparency
    if resized_logo.mode != 'RGBA':
        resized_logo = resized_logo.convert('RGBA')
    
    # Paste logo perfectly centered in square, using alpha channel for transparency
    square_icon.paste(resized_logo, (x_offset, y_offset), resized_logo)
    
    # Save square icon with transparency preserved
    output_path = 'images/logo_square.png'
    square_icon.save(output_path, 'PNG', optimize=False)
    print(f"\n[OK] Created square icon: {output_path}")
    print(f"  Size: {square_size}x{square_size}px")
    print(f"  Content scaled to: {scaled_width}x{scaled_height}px")
    print(f"  Centered with transparent padding")
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

