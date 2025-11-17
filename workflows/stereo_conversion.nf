nextflow.enable.dsl=2

workflow stereo_conversion_workflow {
    
    main:
        // Step 1: Validate raw data existence
        validate_stereo_data()
        
        // Step 2: Convert GEM to h5ad (only if not already converted)
        stereopy_make_h5ad(validate_stereo_data.out.validated_gem)
        
    emit:
        h5ad_file = stereopy_make_h5ad.out.h5ad_file
}

// Process 1: Check if raw Stereo-seq GEM file exists
process validate_stereo_data {
    
    tag "Validate Stereo-seq Data"
    label 'process_single'
    
    exec {
        gem_file = file(params.input_gem_file)
        if (!gem_file.exists()) {
            error "ERROR: Stereo-seq GEM file not found at: ${params.input_gem_file}"
        }
        if (!gem_file.isFile()) {
            error "ERROR: Stereo-seq input path is not a file: ${params.input_gem_file}"
        }
    }
    
    output:
    val gem_file, emit: validated_gem
    
    script:
    """
    echo "Stereo-seq raw data validated: ${params.input_gem_file}"
    """
}

process stereopy_make_h5ad {

    tag "Stereopy: ${input_gem.name}"
    label 'process_medium'

    container params.stereopy_container   // << container is used here

    publishDir "${params.outdir}/data/stereo_intermediate", mode: 'copy'

    input:
        val input_gem
        path script_dir                   // << mounts the script directory

    output:
        path "stereo_converted.h5ad", emit: h5ad_file

    script:
    """
    python ${script_dir}/Stereopy_make_bin3_h5ad.py \
        --data_path ${input_gem} \
        --output stereo_converted.h5ad \
        --bin_size ${params.stereopy_bin_size}
    """
}
