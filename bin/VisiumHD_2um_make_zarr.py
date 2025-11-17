#!/usr/bin/env python3
"""
Convert VisiumHD data to zarr format.
"""

import argparse
import spatialdata_io


def main():
    parser = argparse.ArgumentParser(
        description='Convert VisiumHD data to zarr format'
    )
    parser.add_argument(
        '--input_dir',
        type=str,
        required=True,
        help='Path to input VisiumHD directory'
    )
    parser.add_argument(
        '--bin_size',
        type=int,
        default=2,
        help='Bin size in microns (default: 2)'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output zarr path'
    )
    
    args = parser.parse_args()
    
    # Read VisiumHD data
    print(f"Reading VisiumHD data from: {args.input_dir}")
    print(f"Using bin size: {args.bin_size}um")
    sdata = spatialdata_io.visium_hd(
        args.input_dir,
        bin_size=args.bin_size
    )
    
    # Extract AnnData table
    table_key = f'square_{args.bin_size:03d}um'
    print(f"Extracting table: {table_key}")
    adata = sdata.tables[table_key].copy()
    
    # Write to zarr
    print(f"Writing to zarr: {args.output}")
    adata.write_zarr(args.output)
    print(f"Successfully saved to: {args.output}")


if __name__ == '__main__':
    main()

