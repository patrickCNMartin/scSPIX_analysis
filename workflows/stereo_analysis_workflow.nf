nextflow.enable.dsl=2

workflow stereo_analysis_workflow {
    take:
        h5ad_file
    
    main:
        stereo_multiscale(h5ad_file)
        
    emit:
        results_dir = stereo_multiscale.out.results_dir
}

// Process: Stereo-seq multiscale analysis workflow
process stereo_multiscale {
    
    tag "Stereo-seq Multiscale: ${h5ad_input.name}"
    label 'process_large'
    
    publishDir "${params.outdir}/results/stereo_multiscale", mode: 'copy'
    
    input:
    path h5ad_input
    
    output:
    path "stereo_multiscale_results", emit: results_dir, type: 'dir'
    
    script:
    """
    mkdir -p stereo_multiscale_results
    python ${params.script_dir}/Stereo_seq_MOSTA_bin3_multiscale.py \\
        --input_h5ad ${h5ad_input} \\
        --out_dir stereo_multiscale_results \\
        --omp_threads ${params.omp_threads} \\
        --openblas_threads ${params.openblas_threads} \\
        --mkl_threads ${params.mkl_threads} \\
        --numexpr_threads ${params.numexpr_threads}
    """
}