nextflow.enable.dsl=2

workflow container_converter {
    
    main:
        // Get all .tar files from container cache directory
        tar_files = Channel.fromPath("${params.container_cache_dir}/*.tar")
        
        // Check if .sif already exists, if not convert
        check_and_convert(tar_files)
        
    emit:
        converted_sifs = check_and_convert.out.sif_file
}

// Process: Check cache and convert TAR to SIF
process check_and_convert {
    
    tag "Convert: ${tar_file.name}"
    label 'conversion_single'
    
    publishDir "${params.container_cache_dir}", mode: 'copy', pattern: '*.sif'
    
    input:
    path tar_file
    
    output:
    path "*.sif", emit: sif_file, optional: true
    
    script:
    // Extract basename without .tar extension
    sif_filename = tar_file.getBaseName() + ".sif"
    sif_path = "${params.container_cache_dir}/${sif_filename}"
    
    """
    # Check if .sif already exists
    if [ -f "${sif_path}" ]; then
        echo "SIF already exists: ${sif_filename}, skipping conversion"
        # Copy it to current directory so it's captured in output
        cp "${sif_path}" "${sif_filename}"
    else
        echo "Converting ${tar_file.name} to ${sif_filename}..."
        module add apptainer
        apptainer build "${sif_filename}" "docker-archive://${tar_file}"
        
        if [ $? -eq 0 ]; then
            echo "Successfully converted: ${sif_filename}"
        else
            echo "ERROR: Failed to convert ${tar_file.name}"
            exit 1
        fi
    fi
    """
}