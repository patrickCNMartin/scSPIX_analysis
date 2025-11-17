#!/usr/bin/env python3
"""
Multiscale Workflow - bin3(~2um) Stereo-seq MOSTA data
"""

import argparse
import os
import gc
import tempfile
import shutil
import warnings
import itertools
import math
from typing import List
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing as mp

import numpy as np
import pandas as pd
import scanpy as sc
import squidpy as sq
import matplotlib
import matplotlib.pyplot as plt
from PIL import Image
from joblib import Parallel, delayed
from scipy.stats import rankdata

import SPIX
from SPIX.image_processing.image_cache import *
import anndata as ad

# Set matplotlib backend for non-interactive use
matplotlib.use("Agg")


def setup_environment(omp_threads=64, openblas_threads=64, mkl_threads=64, numexpr_threads=64):
    """Set environment variables for thread limiting."""
    os.environ["OMP_NUM_THREADS"] = str(omp_threads)
    os.environ["OPENBLAS_NUM_THREADS"] = str(openblas_threads)
    os.environ["MKL_NUM_THREADS"] = str(mkl_threads)
    os.environ["NUMEXPR_NUM_THREADS"] = str(numexpr_threads)


def transform_coordinates(adata):
    """Transform spatial coordinates."""
    y = adata.obsm['spatial'][:, 0].copy()
    x = adata.obsm['spatial'][:, 1].copy()
    adata.obsm['spatial'][:, 0] = x.copy()
    adata.obsm['spatial'][:, 1] = y.copy()
    
    coords = adata.obsm['spatial'].copy()
    coords[:, 1] = coords[:, 1].max() - coords[:, 1]
    adata.obsm['spatial'] = coords
    
    coords = adata.obsm['spatial'].copy()
    coords[:, 0] = coords[:, 0].max() - coords[:, 0]
    adata.obsm['spatial'] = coords
    return adata


def calc_scale(adata, scale_id, res, comp, adata_path=None, dims_use=None, 
               embedding_key=None, segment_method=None, use_cached_image=None,
               moran_thresh=0):
    """Single-scale calculation function."""
    if adata_path:
        ad = sc.read_h5ad(adata_path)
    else:
        ad = adata.copy()
    
    # segmentation
    SPIX.sp.segment_image(
        ad,
        dimensions=dims_use,
        embedding=embedding_key,
        method=segment_method,
        target_segment_um=res,
        compactness=comp,
        figsize=(30, 30),
        fig_dpi=300,
        enforce_connectivity=False,
        use_cached_image=use_cached_image,
        origin=True,
        verbose=False
    )
    
    # pseudo-bulk Moran
    _, moran = SPIX.an.perform_pseudo_bulk_analysis(
        ad,
        segment_key='Segment',
        normalize_total=True,
        log_transform=True,
        expr_agg='sum',
        moranI_threshold=moran_thresh,
        segment_graph_strategy='collapsed',
        collapse_row_normalize=True,
        perform_pca=False,
        highly_variable=False,
        mode='moran'
    )
    
    if moran.empty:
        warnings.warn(f"[{scale_id}] No MoranI result ")
        return pd.DataFrame()
    
    # rank
    moran['rank_' + scale_id] = rankdata(-moran['I'], method='min')
    return moran[['rank_' + scale_id]]


def categorize_with_threshold(row, threshold_ratio=0.93):
    """Categorize genes based on threshold ratio."""
    regions = {
        'early': row['mean_early'],
        'mid': row['mean_mid'],
        'late': row['mean_late']
    }
    sorted_regs = sorted(regions.items(), key=lambda x: x[1])
    (reg1, val1), (reg2, val2) = sorted_regs[0], sorted_regs[1]
    
    if (val2 - val1) / val2 >= threshold_ratio:
        return reg1
    else:
        return 'mixed'


def plot_traj(df, genes, xlabel, title):
    """Plot trajectory for genes."""
    plt.figure(figsize=(8, 4))
    x = np.arange(df.shape[1])
    for g in genes:
        plt.plot(x, df.loc[g], '-o', alpha=0.7, label=g)
    plt.gca().invert_yaxis()
    plt.xticks(x, df.columns, rotation=45)
    plt.xlabel(xlabel)
    plt.ylabel('Rank')
    plt.title(title)
    plt.legend(bbox_to_anchor=(1.02, 1), loc='upper left', fontsize=8)
    plt.tight_layout()
    plt.show()


def _render_gene_png_worker(gene: str, out_png: str, segment_key: str,
                            normalize_total: bool, log1p: bool,
                            title_prefix: str, tile_figsize: tuple,
                            tile_dpi: int, adata_global=None):
    """Worker function to render one gene PNG."""
    import SPIX
    import matplotlib.pyplot as plt
    
    if adata_global is None:
        raise ValueError("adata_global must be provided")
    
    adata = adata_global
    
    # Gracefully handle missing gene
    if str(gene) not in set(map(str, adata.var_names)):
        fig = plt.figure(figsize=tile_figsize)
        plt.text(0.5, 0.5, f"{title_prefix}{gene}\n(not in var_names)",
                ha='center', va='center')
        plt.axis('off')
        fig.savefig(out_png, dpi=tile_dpi, bbox_inches='tight')
        plt.close(fig)
        return out_png
    
    # Compute single-gene embedding
    SPIX.an.add_gene_expression_embedding(
        adata,
        genes=[gene],
        segment_key=segment_key,
        normalize_total=normalize_total,
        log1p=log1p
    )
    
    # Plot using the single dimension [0]
    SPIX.pl.image_plot(
        adata,
        dimensions=[0],
        embedding='X_gene_embedding',
        boundary_method='pixel',
        imshow_tile_size=10,
        imshow_scale_factor=1,
        figsize=tile_figsize,
        fixed_boundary_color='Black',
        cmap='viridis',
        boundary_linewidth=1,
        show_colorbar=True,
        prioritize_high_values=True,
        title=f"{title_prefix}{gene}",
        alpha=1,
        plot_boundaries=False,
        origin=True
    )
    plt.savefig(out_png, dpi=tile_dpi, bbox_inches='tight')
    plt.close()
    
    gc.collect()
    return out_png


def _assemble_grid(tile_paths: List[str], out_path: str, cols: int = 5,
                   suptitle: str = "", dpi: int = 150):
    """Assemble saved PNG tiles into a grid figure."""
    rows = math.ceil(len(tile_paths) / cols) if tile_paths else 1
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 4, rows * 4),
                            squeeze=False)
    if suptitle:
        fig.suptitle(suptitle, fontsize=16)
    i = 0
    for r in range(rows):
        for c in range(cols):
            ax = axes[r][c]
            ax.axis('off')
            if i < len(tile_paths):
                img = Image.open(tile_paths[i])
                ax.imshow(img)
            i += 1
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.savefig(out_path, dpi=dpi, bbox_inches='tight')
    plt.close(fig)


def build_grid_for_group_parallel(group_name: str, genes: List[str],
                                  adata_global, out_dir: str = "./spix_grids",
                                  cols: int = 5, tile_figsize=(10, 10),
                                  tile_dpi=150, segment_key='Segment',
                                  normalize_total=True, log1p=True,
                                  max_workers=6):
    """Run per-gene SPIX rendering in parallel, then assemble grid."""
    if not genes:
        warnings.warn(f"[{group_name}] No genes to render.")
        return None
    
    os.makedirs(out_dir, exist_ok=True)
    tmp_dir = os.path.join(out_dir, f"tiles_{group_name}")
    os.makedirs(tmp_dir, exist_ok=True)
    
    out_png = os.path.join(out_dir, f"grid_{group_name}.png")
    
    # Submit jobs
    ordered_tiles = [os.path.join(tmp_dir, f"{g}.png") for g in genes]
    with ProcessPoolExecutor(max_workers=max_workers) as ex:
        futures = []
        for g, png in zip(genes, ordered_tiles):
            futures.append(
                ex.submit(
                    _render_gene_png_worker,
                    g, png, segment_key, normalize_total, log1p,
                    f"{group_name} | ", tile_figsize, tile_dpi, adata_global
                )
            )
        # Ensure all complete
        for f in as_completed(futures):
            _ = f.result()
    
    # Assemble in original order
    existing_tiles = [p for p in ordered_tiles if os.path.exists(p)]
    _assemble_grid(existing_tiles, out_path=out_png, cols=cols,
                  suptitle=f"{group_name} (n={len(existing_tiles)})",
                  dpi=tile_dpi)
    
    print(f"[Saved] {out_png}")
    return out_png


def main():
    parser = argparse.ArgumentParser(
        description='Multiscale Workflow - bin3(~2um) Stereo-seq MOSTA data'
    )
    
    # File paths
    parser.add_argument(
        '--input_h5ad',
        type=str,
        required=True,
        help='Input h5ad file path'
    )
    
    # Environment settings
    parser.add_argument('--omp_threads', type=int, default=64)
    parser.add_argument('--openblas_threads', type=int, default=64)
    parser.add_argument('--mkl_threads', type=int, default=64)
    parser.add_argument('--numexpr_threads', type=int, default=64)
    
    # Embedding generation
    parser.add_argument('--n_jobs_embedding', type=int, default=32)
    parser.add_argument('--dimensions', type=int, default=30)
    parser.add_argument('--nfeatures', type=int, default=2000)
    parser.add_argument('--raster_stride', type=int, default=10)
    parser.add_argument('--filter_threshold', type=int, default=1)
    parser.add_argument('--raster_max_pixels_per_tile', type=int, default=400)
    parser.add_argument('--raster_random_seed', type=int, default=42)
    
    # Image smoothing
    parser.add_argument('--n_jobs_smooth', type=int, default=10)
    parser.add_argument('--graph_k', type=int, default=30)
    parser.add_argument('--graph_t', type=int, default=50)
    parser.add_argument('--gaussian_sigma', type=float, default=500)
    
    # Image equalization
    parser.add_argument('--sleft', type=int, default=5)
    parser.add_argument('--sright', type=int, default=5)
    
    # Segmentation
    parser.add_argument('--pitch_um', type=float, default=2.0)
    parser.add_argument('--target_segment_um', type=float, default=500.0)
    parser.add_argument('--compactness', type=float, default=0.5)
    
    # Multiscale analysis
    parser.add_argument('--resolutions', type=str, default='2,8,16,30,50,100,250,500',
                       help='Comma-separated list of resolutions')
    parser.add_argument('--compactnesses', type=str, default='0.5',
                       help='Comma-separated list of compactnesses')
    parser.add_argument('--n_jobs_multiscale', type=int, default=3)
    parser.add_argument('--moran_thresh', type=float, default=0)
    parser.add_argument('--use_memmap', action='store_true', default=False)
    
    # Categorization
    parser.add_argument('--threshold_ratio', type=float, default=0.93)
    
    # Grid generation
    parser.add_argument('--top_k', type=int, default=10)
    parser.add_argument('--group_cols', type=int, default=5)
    parser.add_argument('--tile_figsize', type=int, nargs=2, default=[10, 10])
    parser.add_argument('--tile_dpi', type=int, default=400)
    parser.add_argument('--max_workers', type=int, default=10)
    parser.add_argument('--out_dir', type=str, required=True,
                       help='Output directory for results')
    
    # Visualization
    parser.add_argument('--show_plots', action='store_true', default=False)
    
    args = parser.parse_args()
    
    # Setup environment
    setup_environment(
        args.omp_threads, args.openblas_threads,
        args.mkl_threads, args.numexpr_threads
    )
    
    # Parse resolutions and compactnesses
    resolutions = [float(x) for x in args.resolutions.split(',')]
    compactnesses = [float(x) for x in args.compactnesses.split(',')]
    dims_use = list(range(args.dimensions))
    segment_method = 'image_plot_slic'
    embedding_key = 'X_embedding_equalize'
    use_cached_image = True
    
    # Load data
    print(f"Loading h5ad file: {args.input_h5ad}")
    adata = sc.read_h5ad(args.input_h5ad)
    
    # Transform coordinates
    print("Transforming coordinates...")
    adata = transform_coordinates(adata)
    
    # Generate embeddings
    print("Generating embeddings...")
    adata = SPIX.tm.generate_embeddings(
        adata,
        dim_reduction='PCA',
        normalization='log_norm',
        n_jobs=args.n_jobs_embedding,
        dimensions=args.dimensions,
        nfeatures=args.nfeatures,
        force=True,
        use_hvg_only=True,
        use_coords_as_tiles=True,
        coords_max_gap_factor=None,
        raster_stride=args.raster_stride,
        filter_threshold=args.filter_threshold,
        raster_max_pixels_per_tile=args.raster_max_pixels_per_tile,
        raster_random_seed=args.raster_random_seed
    )
    
    # Smooth image
    print("Smoothing image...")
    adata = SPIX.ip.smooth_image(
        adata,
        methods=['graph', 'gaussian'],
        embedding='X_embedding',
        embedding_dims=list(range(args.dimensions)),
        graph_k=args.graph_k,
        graph_t=args.graph_t,
        gaussian_sigma=args.gaussian_sigma,
        n_jobs=args.n_jobs_smooth,
    )
    
    # Equalize image
    print("Equalizing image...")
    adata = SPIX.ip.equalize_image(
        adata,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_smooth',
        sleft=args.sleft,
        sright=args.sright
    )
    
    # Cache embedding image
    print("Caching embedding image...")
    cache_embedding_image(
        adata,
        embedding='X_embedding_equalize',
        dimensions=list(range(args.dimensions)),
        key='image_plot_slic',
        origin=True,
        figsize=(30, 30),
        fig_dpi=300,
        verbose=False,
        show=args.show_plots
    )
    
    if args.show_plots:
        show_cached_image(adata, key='image_plot_slic', channels=[0, 1, 2])
    
    # Segment image
    print("Segmenting image...")
    SPIX.sp.segment_image(
        adata,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_equalize',
        method='image_plot_slic',
        pitch_um=args.pitch_um,
        target_segment_um=args.target_segment_um,
        compactness=args.compactness,
        verbose=True,
        enforce_connectivity=False,
        use_cached_image=True,
        origin=True,
        show_image=args.show_plots
    )
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata,
            dimensions=[0, 1, 2],
            embedding='X_embedding_segment',
            boundary_method='pixel',
            figsize=(10, 10),
            fixed_boundary_color='black',
            boundary_linewidth=1,
            alpha=1,
            plot_boundaries=True,
            origin=True
        )
    
    # Spatial neighbors
    print("Computing spatial neighbors...")
    sq.gr.spatial_neighbors(adata, coord_type='generic')
    
    # Multiscale analysis
    print("Starting multiscale analysis...")
    param_grid = list(itertools.product(resolutions, compactnesses))
    print(f"▶ Total {len(param_grid)} scales")
    
    adata_path = None
    if args.use_memmap:
        td = tempfile.mkdtemp()
        adata_path = os.path.join(td, 'adata_tmp.h5ad')
        adata.write_h5ad(adata_path)
    
    results = Parallel(n_jobs=args.n_jobs_multiscale, backend='loky', verbose=10)(
        delayed(calc_scale)(
            adata, f"r{r}_c{c}", r, c, adata_path,
            dims_use=dims_use, embedding_key=embedding_key,
            segment_method=segment_method, use_cached_image=use_cached_image,
            moran_thresh=args.moran_thresh
        )
        for r, c in param_grid
    )
    
    if args.use_memmap:
        shutil.rmtree(td)
    
    # Concat rank table
    print("Concatenating rank tables...")
    rank_tables = [df for df in results if not df.empty]
    rank_mat = pd.concat(rank_tables, axis=1, join='outer')
    max_rank = int(rank_mat.max().max())
    rank_mat = rank_mat.fillna(max_rank + 1)
    rank_mat.sort_index(axis=1, inplace=True)
    
    # Resolution / compactness axis
    res_rank = pd.DataFrame(index=rank_mat.index)
    for r in resolutions:
        cols = [f"rank_r{r}_c{c}" for c in compactnesses]
        res_rank[f"res_{r}"] = rank_mat[cols].mean(axis=1)
    
    comp_rank = pd.DataFrame(index=rank_mat.index)
    for c in compactnesses:
        cols = [f"rank_r{r}_c{c}" for r in resolutions]
        comp_rank[f"comp_{c}"] = rank_mat[cols].mean(axis=1)
    
    df = res_rank.copy()
    
    # Categorize genes
    print("Categorizing genes...")
    early_cols = ['res_2', 'res_8', 'res_16']
    mid_cols = ['res_30', 'res_50', 'res_100']
    late_cols = ['res_250', 'res_500']
    
    df['mean_early'] = df[early_cols].mean(axis=1)
    df['mean_mid'] = df[mid_cols].mean(axis=1)
    df['mean_late'] = df[late_cols].mean(axis=1)
    
    df['category'] = df.apply(
        lambda row: categorize_with_threshold(row, args.threshold_ratio),
        axis=1
    )
    
    print(df['category'].value_counts())
    print(df[['mean_early', 'mean_mid', 'mean_late', 'category']].head())
    
    df['late_m_mid'] = df['mean_late'] - df['mean_mid']
    
    # Plot trajectories if requested
    if args.show_plots:
        plot_traj(
            res_rank,
            df[df['category'] == 'early'].sort_values('mean_early').head(10).index.tolist(),
            'Resolution',
            'Unique in high resolution'
        )
        plot_traj(
            res_rank,
            df[df['category'] == 'late'].sort_values('mean_late').head(10).index.tolist(),
            'Resolution',
            'Unique in low resolution'
        )
        plot_traj(
            res_rank,
            df[df['category'] == 'late'].sort_values('mean_mid', ascending=False).head(10).index.tolist(),
            'Resolution',
            'Unique in low resolution'
        )
        plot_traj(
            res_rank,
            df[df['category'] == 'mid'].sort_values('mean_early', ascending=False).head(10).index.tolist(),
            'Resolution',
            'Unique in middle resolution'
        )
    
    # Build grids
    print("Building gene grids...")
    tile_figsize_tuple = tuple(args.tile_figsize)
    
    # Try to set fork start method for multiprocessing
    try:
        mp.set_start_method("fork", force=True)
    except RuntimeError:
        pass
    
    build_grid_for_group_parallel(
        group_name=f"moran_late_500_top{args.top_k}",
        genes=df[df['category'] == 'late'].sort_values('mean_late').head(args.top_k).index.tolist(),
        adata_global=adata,
        out_dir=args.out_dir,
        cols=args.group_cols,
        tile_figsize=tile_figsize_tuple,
        tile_dpi=args.tile_dpi,
        segment_key="Segment",
        normalize_total=True,
        log1p=True,
        max_workers=args.max_workers
    )
    
    build_grid_for_group_parallel(
        group_name=f"moran_late_m_mid_500_top{args.top_k}",
        genes=df[df['category'] == 'late'].sort_values('late_m_mid', ascending=True).head(args.top_k).index.tolist(),
        adata_global=adata,
        out_dir=args.out_dir,
        cols=args.group_cols,
        tile_figsize=tile_figsize_tuple,
        tile_dpi=args.tile_dpi,
        segment_key="Segment",
        normalize_total=True,
        log1p=True,
        max_workers=args.max_workers
    )
    
    print("Pipeline completed successfully!")


if __name__ == '__main__':
    main()

