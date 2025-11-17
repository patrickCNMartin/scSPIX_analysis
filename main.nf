nextflow.enable.dsl=2

// Include subworkflows from workflows directory
include { stereo_conversion_workflow } from './workflows/stereo_conversion'
include { visiumhd_conversion_workflow } from './workflows/visiumhd_conversion'
include { stereo_analysis_workflow } from './workflows/stereo_analysis'
include { visiumhd_analysis_workflow } from './workflows/visiumhd_analysis'
include { container_converter } from './modules/container_converter'


workflow {
    
    // Step 0: Convert all .tar containers to .sif files
    log.info "Checking and converting container cache..."
    container_converter()
    
    // Wait for container conversion to complete before proceeding
    container_converter.out.converted_sifs.collect()
    
    // Stereo-seq workflow: conversion + analysis
    if (params.run_stereo) {
        stereo_results = stereo_conversion_workflow()
        stereo_analysis_workflow(stereo_results.h5ad_file)
    }
    
    // VisiumHD workflow: conversion + analysis
    if (params.run_visiumhd) {
        visiumhd_results = visiumhd_conversion_workflow()
        visiumhd_analysis_workflow(visiumhd_results.zarr_file, visiumhd_results.h5ad_8um_file)
    }
}