#!/usr/bin/env python3
"""
Multiscale Workflow - 2um VisiumHD CRC data
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
import celltypist
from celltypist import models

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


def get_cell_type_maps():
    """Get cell type mapping dictionaries."""
    big_group_map = {
        # Immune
        "CD4+ T cells": "Immune",
        "CD8+ T cells": "Immune",
        "Regulatory T cells": "Immune",
        "T follicular helper cells": "Immune",
        "T helper 17 cells": "Immune",
        "gamma delta T cells": "Immune",
        "CD19+CD20+ B": "Immune",
        "IgA+ Plasma": "Immune",
        "IgG+ Plasma": "Immune",
        "NK cells": "Immune",
        "cDC": "Immune",
        "Mast cells": "Immune",
        
        # Epithelial
        "Mature Enterocytes type 1": "Epithelial",
        "Mature Enterocytes type 2": "Epithelial",
        "Goblet cells": "Epithelial",
        "Enteric glial cells": "Epithelial",
        "Stem-like/TA": "Epithelial",
        "Intermediate": "Epithelial",
        "Proliferative ECs": "Epithelial",
        "Stalk-like ECs": "Epithelial",
        "Tip-like ECs": "Epithelial",
        # CMS groups
        "CMS1": "CMS subtype",
        "CMS2": "CMS subtype",
        "CMS3": "CMS subtype",
        "CMS4": "CMS subtype",
        
        # Stromal
        "Myofibroblasts": "Stromal",
        "Smooth muscle cells": "Stromal",
        "Pericytes": "Stromal",
        "Stromal 1": "Stromal",
        "Stromal 2": "Stromal",
        "Stromal 3": "Stromal",
        
        # Endothelial / vascular
        "Lymphatic ECs": "Endothelial/Vascular",
        "Proliferating": "Endothelial/Vascular",
        
        # Special / functional
        "SPP1+": "SPP1+",
        "Pro-inflammatory": "Pro-inflammatory",
        
        "Unknown": "Unknown"
    }
    
    small_group_map = {
        # T cells
        "CD4+ T cells": "T cell subset",
        "CD8+ T cells": "T cell subset",
        "Regulatory T cells": "T cell subset",
        "T follicular helper cells": "T cell subset",
        "T helper 17 cells": "T cell subset",
        "gamma delta T cells": "T cell subset",
        
        # B lineage
        "CD19+CD20+ B": "B cell",
        "IgA+ Plasma": "Plasma cell",
        "IgG+ Plasma": "Plasma cell",
        
        # Innate immune
        "NK cells": "Innate immune",
        "cDC": "Innate immune",
        "Mast cells": "Innate immune",
        
        # Epithelial – differentiated
        "Mature Enterocytes type 1": "Mature epithelial",
        "Mature Enterocytes type 2": "Mature epithelial",
        "Goblet cells": "Mature epithelial",
        "Enteric glial cells": "Mature epithelial",
        
        # Epithelial – progenitor
        "Stem-like/TA": "Progenitor epithelial",
        "Intermediate": "Progenitor epithelial",
        
        # Epithelial – proliferative
        "Proliferative ECs": "Proliferative epithelial",
        "Stalk-like ECs": "Proliferative epithelial",
        "Tip-like ECs": "Proliferative epithelial",
        
        # CMS groups
        "CMS1": "CMS subtype",
        "CMS2": "CMS subtype",
        "CMS3": "CMS subtype",
        "CMS4": "CMS subtype",
        
        # Stromal
        "Myofibroblasts": "Fibroblast-like",
        "Smooth muscle cells": "Smooth muscle",
        "Pericytes": "Perivascular cell",
        "Stromal 1": "Stromal subtype",
        "Stromal 2": "Stromal subtype",
        "Stromal 3": "Stromal subtype",
        
        # Endothelial / vascular
        "Lymphatic ECs": "Endothelial cell",
        "Proliferating": "Proliferating cell",
        # Special / functional
        "SPP1+": "SPP1+",
        "Pro-inflammatory": "Pro-inflammatory",
        "Unknown": "Unknown"
    }
    
    return big_group_map, small_group_map


def main():
    parser = argparse.ArgumentParser(
        description='Multiscale Workflow - 2um VisiumHD CRC data'
    )
    
    # File paths
    parser.add_argument(
        '--input_zarr',
        type=str,
        required=True,
        help='Input zarr file path'
    )
    parser.add_argument(
        '--input_8um_h5ad',
        type=str,
        required=True,
        help='Input 8um h5ad file path'
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
    
    # Image smoothing (2um)
    parser.add_argument('--n_jobs_smooth', type=int, default=10)
    parser.add_argument('--graph_k', type=int, default=30)
    parser.add_argument('--graph_t_2um', type=int, default=20)
    parser.add_argument('--gaussian_sigma_2um', type=float, default=300)
    
    # Image smoothing (8um)
    parser.add_argument('--graph_t_8um', type=int, default=3)
    parser.add_argument('--gaussian_sigma_8um', type=float, default=50)
    
    # Image equalization
    parser.add_argument('--sleft', type=int, default=5)
    parser.add_argument('--sright', type=int, default=5)
    
    # Segmentation (2um)
    parser.add_argument('--pitch_um_2um', type=float, default=2.0)
    parser.add_argument('--target_segment_um_2um', type=float, default=500.0)
    parser.add_argument('--compactness_2um', type=float, default=0.5)
    
    # Segmentation (8um)
    parser.add_argument('--pitch_um_8um', type=float, default=8.0)
    parser.add_argument('--target_segment_um_8um', type=float, default=500.0)
    parser.add_argument('--compactness_8um', type=float, default=1.0)
    
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
    
    # Gene visualization
    parser.add_argument('--gene', type=str, default='LYVE1',
                       help='Gene to visualize (default: LYVE1)')
    parser.add_argument('--gene_8um', type=str, default='SLC4A4',
                       help='Gene to visualize for 8um data (default: SLC4A4)')
    
    # Cell type annotation
    parser.add_argument('--celltypist_model', type=str,
                       default='Human_Colorectal_Cancer.pkl',
                       help='CellTypist model name (default: Human_Colorectal_Cancer.pkl)')
    parser.add_argument('--use_gpu', action='store_true', default=True,
                       help='Use GPU for cell type annotation (default: True)')
    
    # Cache image settings
    parser.add_argument('--cache_figsize', type=int, nargs=2, default=[30, 30])
    parser.add_argument('--cache_fig_dpi', type=int, default=100)
    
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
    
    # ========== 2um Workflow ==========
    print("=" * 50)
    print("Starting 2um VisiumHD CRC workflow")
    print("=" * 50)
    
    # Load 2um data
    print(f"Loading zarr file: {args.input_zarr}")
    adata = ad.read_zarr(args.input_zarr)
    
    # Generate embeddings
    print("Generating embeddings for 2um data...")
    adata = SPIX.tm.generate_embeddings(
        adata,
        dim_reduction='PCA',
        normalization='log_norm',
        n_jobs=args.n_jobs_embedding,
        dimensions=args.dimensions,
        nfeatures=args.nfeatures,
        use_coords_as_tiles=True,
        coords_max_gap_factor=None,
        force=True,
        use_hvg_only=True,
        raster_stride=args.raster_stride,
        filter_threshold=args.filter_threshold,
        raster_max_pixels_per_tile=args.raster_max_pixels_per_tile,
        raster_random_seed=args.raster_random_seed
    )
    
    # Smooth image
    print("Smoothing image for 2um data...")
    adata = SPIX.ip.smooth_image(
        adata,
        methods=['graph', 'gaussian'],
        embedding='X_embedding',
        embedding_dims=list(range(args.dimensions)),
        graph_k=args.graph_k,
        graph_t=args.graph_t_2um,
        gaussian_sigma=args.gaussian_sigma_2um,
        n_jobs=args.n_jobs_smooth,
        rescale_mode='final',
    )
    
    # Equalize image
    print("Equalizing image for 2um data...")
    adata = SPIX.ip.equalize_image(
        adata,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_smooth',
        sleft=args.sleft,
        sright=args.sright
    )
    
    # Cache embedding image
    print("Caching embedding image for 2um data...")
    cache_embedding_image(
        adata,
        embedding='X_embedding_equalize',
        dimensions=list(range(args.dimensions)),
        key='image_plot_slic',
        origin=True,
        figsize=tuple(args.cache_figsize),
        fig_dpi=args.cache_fig_dpi,
        verbose=False,
        show=args.show_plots
    )
    
    # Segment image
    print("Segmenting image for 2um data...")
    SPIX.sp.segment_image(
        adata,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_equalize',
        method='image_plot_slic',
        pitch_um=args.pitch_um_2um,
        target_segment_um=args.target_segment_um_2um,
        compactness=args.compactness_2um,
        verbose=True,
        figsize=tuple(args.cache_figsize),
        use_cached_image=True,
        enforce_connectivity=False,
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
    print("Computing spatial neighbors for 2um data...")
    sq.gr.spatial_neighbors(adata, coord_type='generic')
    
    # Multiscale analysis
    print("Starting multiscale analysis for 2um data...")
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
            df[df['category'] == 'early'].sort_values('mean_mid', ascending=False).head(10).index.tolist(),
            'Resolution',
            'Unique in middle resolution'
        )
    
    # Gene visualization (without segment key)
    print(f"Visualizing gene {args.gene} without segment key...")
    SPIX.an.add_gene_expression_embedding(
        adata, genes=[args.gene], segment_key=None,
        normalize_total=True, log1p=True
    )
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata,
            dimensions=[0],
            embedding='X_gene_embedding',
            boundary_method='pixel',
            figsize=(10, 10),
            fixed_boundary_color='Black',
            cmap='viridis',
            boundary_linewidth=1,
            show_colorbar=True,
            prioritize_high_values=True,
            title=args.gene,
            alpha=1,
            plot_boundaries=False,
            origin=True
        )
    
    # Gene visualization (with segment key)
    print(f"Visualizing gene {args.gene} with segment key...")
    SPIX.an.add_gene_expression_embedding(
        adata, genes=[args.gene], segment_key='Segment',
        normalize_total=True, log1p=True
    )
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata,
            dimensions=[0],
            embedding='X_gene_embedding',
            boundary_method='pixel',
            figsize=(10, 10),
            fixed_boundary_color='Black',
            cmap='viridis',
            boundary_linewidth=1,
            show_colorbar=True,
            prioritize_high_values=True,
            title=args.gene,
            alpha=1,
            plot_boundaries=False,
            origin=True
        )
    
    # Build grids
    print("Building gene grids for 2um data...")
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
    
    # ========== 8um Workflow ==========
    print("=" * 50)
    print("Starting 8um VisiumHD CRC workflow")
    print("=" * 50)
    
    # Load 8um data
    print(f"Loading 8um h5ad file: {args.input_8um_h5ad}")
    adata_8um = sc.read_h5ad(args.input_8um_h5ad)
    adata_8um.obsm['spatial'] = adata_8um.obsm['spatial'].astype('float')
    
    # Generate embeddings
    print("Generating embeddings for 8um data...")
    adata_8um = SPIX.tm.generate_embeddings(
        adata_8um,
        dim_reduction='PCA',
        normalization='log_norm',
        n_jobs=args.n_jobs_embedding,
        dimensions=args.dimensions,
        nfeatures=args.nfeatures,
        use_coords_as_tiles=True,
        coords_max_gap_factor=None,
        force=True,
        use_hvg_only=True,
        raster_stride=args.raster_stride,
        filter_threshold=args.filter_threshold,
        raster_max_pixels_per_tile=args.raster_max_pixels_per_tile,
        raster_random_seed=args.raster_random_seed
    )
    
    # Smooth image
    print("Smoothing image for 8um data...")
    adata_8um = SPIX.ip.smooth_image(
        adata_8um,
        methods=['graph', 'gaussian'],
        embedding='X_embedding',
        embedding_dims=list(range(args.dimensions)),
        graph_k=args.graph_k,
        graph_t=args.graph_t_8um,
        gaussian_sigma=args.gaussian_sigma_8um,
        n_jobs=args.n_jobs_smooth,
        rescale_mode='final',
    )
    
    # Equalize image
    print("Equalizing image for 8um data...")
    adata_8um = SPIX.ip.equalize_image(
        adata_8um,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_smooth',
        sleft=args.sleft,
        sright=args.sright
    )
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata_8um,
            dimensions=[0, 1, 2],
            embedding='X_embedding_equalize',
            figsize=(10, 10),
            plot_boundaries=False,
            origin=True
        )
    
    # Segment image
    print("Segmenting image for 8um data...")
    SPIX.sp.segment_image(
        adata_8um,
        dimensions=list(range(args.dimensions)),
        embedding='X_embedding_equalize',
        method='image_plot_slic',
        pitch_um=args.pitch_um_8um,
        target_segment_um=args.target_segment_um_8um,
        compactness=args.compactness_8um,
        verbose=True,
        figsize=(10, 10),
        enforce_connectivity=False,
        origin=True,
        show_image=args.show_plots
    )
    
    # Cell type annotation
    print("Performing cell type annotation...")
    adata_8um.layers['counts'] = adata_8um.X.copy()
    sc.pp.normalize_total(adata_8um, target_sum=1e4)
    sc.pp.log1p(adata_8um)
    
    predictions_8bin_crc = celltypist.annotate(
        adata_8um,
        model=args.celltypist_model,
        majority_voting=False,
        use_GPU=args.use_gpu
    )
    adata_8um.obs['predicted_labels'] = predictions_8bin_crc.predicted_labels['predicted_labels'].copy()
    
    adata_8um.X = adata_8um.layers['counts'].copy()
    
    # Map cell types
    print("Mapping cell types...")
    big_group_map, small_group_map = get_cell_type_maps()
    adata_8um.obs["big_group"] = adata_8um.obs["predicted_labels"].map(big_group_map)
    adata_8um.obs["small_group"] = adata_8um.obs["predicted_labels"].map(small_group_map)
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata_8um,
            embedding='X_embedding',
            dimensions=[0, 1, 2],
            color_by='small_group',
            palette='sc.pl.palettes.default_20',
            figsize=(20, 20),
            show_legend=True,
            legend_ncol=1,
            plot_boundaries=False,
            origin=True
        )
    
    # Gene visualization for 8um
    print(f"Visualizing gene {args.gene_8um} for 8um data...")
    SPIX.an.add_gene_expression_embedding(
        adata_8um, genes=[args.gene_8um], segment_key=None,
        normalize_total=True, log1p=True
    )
    
    if args.show_plots:
        SPIX.pl.image_plot(
            adata_8um,
            dimensions=[0],
            embedding='X_gene_embedding',
            boundary_method='pixel',
            figsize=(10, 10),
            fixed_boundary_color='Black',
            cmap='viridis',
            boundary_linewidth=1,
            show_colorbar=True,
            prioritize_high_values=True,
            title=args.gene_8um,
            alpha=1,
            plot_boundaries=False,
            origin=True
        )
        
        SPIX.pl.image_plot(
            adata_8um,
            dimensions=[0],
            embedding='X_gene_embedding',
            color_by='small_group',
            boundary_method='pixel',
            palette='sc.pl.palettes.default_20',
            show_legend=True,
            legend_ncol=1,
            overlap_priority=None,
            imshow_scale_factor=2,
            title=args.gene_8um,
            cmap='viridis',
            figsize=(20, 20),
            segment_color_by_major=False,
            segment_show_pie=False,
            segment_annotate_by='big_group',
            segment_top_n=3,
            segment_pie_scale=10,
            alpha_by='embedding',
            alpha_range=(0.2, 1.0),
            alpha_clip=None,
            prioritize_high_values=True,
            boundary_linewidth=0.5,
            alpha=1,
            plot_boundaries=True,
        )
    
    print("=" * 50)
    print("Pipeline completed successfully!")
    print("=" * 50)


if __name__ == '__main__':
    main()

