nextflow.enable.dsl=2

workflow visiumhd_analysis_workflow {
    take:
        zarr_file
        h5ad_8um_file
    
    main:
        visiumhd_multiscale(zarr_file, h5ad_8um_file)
        
    emit:
        results_dir = visiumhd_multiscale.out.results_dir
}

// Process: VisiumHD multiscale analysis workflow
process visiumhd_multiscale {
    
    tag "VisiumHD Multiscale: ${zarr_input}"
    label 'process_large'
    
    publishDir "${params.outdir}/results/visiumhd_multiscale", mode: 'copy'
    
    input:
    path zarr_input
    path h5ad_input
    
    output:
    path "visiumhd_multiscale_results", emit: results_dir, type: 'dir'
    
    script:
    """
    mkdir -p visiumhd_multiscale_results
    python ${params.script_dir}/VisiumHD_2um_CRC_multiscale_workflow.py \\
        --input_zarr ${zarr_input} \\
        --input_8um_h5ad ${h5ad_input} \\
        --out_dir visiumhd_multiscale_results \\
        --omp_threads ${params.omp_threads} \\
        --openblas_threads ${params.openblas_threads} \\
        --mkl_threads ${params.mkl_threads} \\
        --numexpr_threads ${params.numexpr_threads}
    """
}