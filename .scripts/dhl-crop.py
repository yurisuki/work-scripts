#!/usr/bin/env python3
"""
DHL 4x6" Label Cropper

Crops DHL shipping labels from standard page size to 4x6 inch format.
The crop box is set to 288 x 432 points (4" x 6" at 72 DPI).

Usage:
    python dhl_label_cropper.py input.pdf [output.pdf]
    python dhl_label_cropper.py label1.pdf label2.pdf -o combined.pdf
"""

import argparse
import sys
from pathlib import Path
from typing import List

try:
    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import RectangleObject
except ImportError:
    print("Error: pypdf is required. Install with: pip install pypdf")
    sys.exit(1)


# 4x6 inches in points (72 points per inch)
TARGET_WIDTH = 4 * 72   # 288 points
TARGET_HEIGHT = 6 * 72  # 432 points

# Crop box offsets (in points) - fine-tuned for DHL labels
CROP_X = 48
CROP_Y = 45

# Scale factor to fit label content
SCALE_FACTOR = 0.85


def crop_dhl_label(input_path: Path, output_path: Path) -> bool:
    """
    Crop a single DHL label PDF to 4x6 inches.
    
    Args:
        input_path: Path to input PDF file
        output_path: Path to output PDF file
        
    Returns:
        True if successful, False otherwise
    """
    try:
        reader = PdfReader(str(input_path))
        writer = PdfWriter()
        
        if len(reader.pages) == 0:
            print(f"Error: {input_path} has no pages")
            return False
        
        # Process first page only (shipping labels are typically single page)
        page = reader.pages[0]
        
        # Scale the page content to fit the crop area
        page.scale_by(SCALE_FACTOR)
        
        # Set crop box to 4x6 inches at the specified offset
        # RectangleObject takes an array: [lower_left_x, lower_left_y, upper_right_x, upper_right_y]
        crop_box = RectangleObject([
            CROP_X,
            CROP_Y,
            CROP_X + TARGET_WIDTH,
            CROP_Y + TARGET_HEIGHT
        ])
        page.cropbox = crop_box
        
        # Add the cropped page to the writer
        writer.add_page(page)
        
        # Write output
        with open(output_path, 'wb') as output_file:
            writer.write(output_file)
        
        return True
        
    except Exception as e:
        print(f"Error processing {input_path}: {e}")
        return False


def merge_dhl_labels(input_paths: List[Path], output_path: Path) -> bool:
    """
    Crop multiple DHL labels and merge into a single PDF.
    
    Args:
        input_paths: List of input PDF file paths
        output_path: Path to merged output PDF file
        
    Returns:
        True if successful, False otherwise
    """
    try:
        writer = PdfWriter()
        
        for input_path in input_paths:
            if not input_path.exists():
                print(f"Warning: {input_path} not found, skipping")
                continue
                
            reader = PdfReader(str(input_path))
            
            if len(reader.pages) == 0:
                print(f"Warning: {input_path} has no pages, skipping")
                continue
            
            # Process first page only
            page = reader.pages[0]
            
            # Scale the page content
            page.scale_by(SCALE_FACTOR)
            
            # Set crop box to 4x6 inches
            crop_box = RectangleObject([
                CROP_X,
                CROP_Y,
                CROP_X + TARGET_WIDTH,
                CROP_Y + TARGET_HEIGHT
            ])
            page.cropbox = crop_box
            
            # Add to merged output
            writer.add_page(page)
        
        if len(writer.pages) == 0:
            print("Error: No valid pages to write")
            return False
        
        # Write output
        with open(output_path, 'wb') as output_file:
            writer.write(output_file)
        
        return True
        
    except Exception as e:
        print(f"Error merging labels: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Crop DHL shipping labels to 4x6 inch format'
    )
    parser.add_argument(
        'input',
        nargs='+',
        help='Input PDF file(s)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output PDF file (default: input_cropped.pdf or DHL-labels-YYYY-MM-DD.pdf for multiple)'
    )
    parser.add_argument(
        '--no-merge',
        action='store_true',
        help='Process each file separately (default merges into single PDF)'
    )
    
    args = parser.parse_args()
    
    # Convert input paths
    input_paths = [Path(p) for p in args.input]
    
    # Validate inputs
    for p in input_paths:
        if not p.exists():
            print(f"Error: File not found: {p}")
            sys.exit(1)
        if not p.suffix.lower() == '.pdf':
            print(f"Error: Not a PDF file: {p}")
            sys.exit(1)
    
    # Determine output path
    if args.output:
        output_path = Path(args.output)
    elif len(input_paths) == 1 and not args.no_merge:
        stem = input_paths[0].stem.replace('.pdf', '')
        output_path = Path(f"{stem}-cropped.pdf")
    else:
        from datetime import date
        output_path = Path(f"DHL-labels-{date.today().isoformat()}.pdf")
    
    # Process files
    if args.no_merge or len(input_paths) == 1:
        # Process each file separately
        success_count = 0
        for input_path in input_paths:
            if args.no_merge:
                stem = input_path.stem
                out = Path(f"{stem}-cropped.pdf")
            else:
                out = output_path
            
            if crop_dhl_label(input_path, out):
                print(f"Cropped: {input_path} -> {out}")
                success_count += 1
            else:
                print(f"Failed: {input_path}")
        
        print(f"\nProcessed {success_count}/{len(input_paths)} files")
    else:
        # Merge into single PDF
        if merge_dhl_labels(input_paths, output_path):
            print(f"Merged {len(input_paths)} labels -> {output_path}")
        else:
            print("Failed to create merged output")
            sys.exit(1)


if __name__ == '__main__':
    main()
