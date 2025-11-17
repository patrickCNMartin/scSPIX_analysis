#!/usr/bin/env python3
"""
Convert Stereo-seq GEM file to h5ad format with binning.
"""

import argparse
import stereo as st
import stereo.io


def main():
    parser = argparse.ArgumentParser(
        description='Convert Stereo-seq GEM file to h5ad format with binning'
    )
    parser.add_argument(
        '--data_path',
        type=str,
        required=True,
        help='Path to input GEM file'
    )
    parser.add_argument(
        '--bin_size',
        type=int,
        default=3,
        help='Bin size for binning (default: 3)'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output h5ad file path'
    )
    parser.add_argument(
        '--sep',
        type=str,
        default='\t',
        help='Separator for GEM file (default: tab)'
    )
    parser.add_argument(
        '--bin_type',
        type=str,
        default='bins',
        help='Bin type (default: bins)'
    )
    parser.add_argument(
        '--is_sparse',
        action='store_true',
        default=True,
        help='Use sparse matrix format (default: True)'
    )
    parser.add_argument(
        '--flavor',
        type=str,
        default='scanpy',
        help='Output flavor (default: scanpy)'
    )
    
    args = parser.parse_args()
    
    # Read GEM file
    print(f"Reading GEM file from: {args.data_path}")
    data = stereo.io.read_gem(
        file_path=args.data_path,
        sep=args.sep,
        bin_type=args.bin_type,
        bin_size=args.bin_size,
        is_sparse=args.is_sparse,
    )
    
    # Convert to AnnData and save
    print(f"Converting to AnnData format (flavor: {args.flavor})")
    adata = st.io.stereo_to_anndata(
        data,
        flavor=args.flavor,
        output=args.output
    )
    
    print(f"Saved output to: {args.output}")


if __name__ == '__main__':
    main()

