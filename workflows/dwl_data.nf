nextflow.enable.dsl=2

include { isMac} from "${baseDir}/lib/utils.nf"
//=============================================================================
// PROCESSES
//=============================================================================
process download_visiumHD {
    publishDir "${params.dwl.data}/visiumHD", mode: 'copy', overwrite: true
    
    input:
    val url
    
    output:
    path "${params.dwl.visiumHD.rename}_*"
    
    script:
    def useMac = isMac()
    """
    echo "Download VisiumHD"
    echo "Downloading from: ${url}"
    
    if [ "${useMac}" = "true" ]; then
        # curl: -L follows redirects, -O saves with remote filename
        curl -L -O "${url}"
    else
        # wget: downloads with remote filename
        wget "${url}"
    fi
    
    # Get the downloaded filename (the most recent file in current directory)
    downloaded_file=\$(ls -t | head -n 1)
    
    echo "Downloaded file: \$downloaded_file"
    
    # Rename by prepending the prefix to the original filename
    mv "\$downloaded_file" "${params.dwl.stereo.rename}_\${downloaded_file}"
    
    echo "Renamed to: ${params.dwl.stereo.rename}_\${downloaded_file}"
    """
}
process download_stereo {
    publishDir "${params.dwl.data}/stereo", mode: 'copy', overwrite: true
    
    input:
    val url
    
    output:
    path "${params.dwl.stereo.rename}_*"
    
    script:
    def useMac = isMac()
    """
    echo "Download Stereo Seq"
    echo "Downloading from: ${url}"
    
    if [ "${useMac}" = "true" ]; then
        # curl: -L follows redirects, -O saves with remote filename
        curl -L -O "${url}"
    else
        # wget: downloads with remote filename
        wget "${url}"
    fi
    
    # Get the downloaded filename (the most recent file in current directory)
    downloaded_file=\$(ls -t | head -n 1)
    
    echo "Downloaded file: \$downloaded_file"
    
    # Rename by prepending the prefix to the original filename
    mv "\$downloaded_file" "${params.dwl.stereo.rename}_\${downloaded_file}"
    
    echo "Renamed to: ${params.dwl.stereo.rename}_\${downloaded_file}"
    """
}
//=============================================================================
// Workflow
//=============================================================================

workflow download_data {
    // def visium_data = file("${params.dwl.visiumHD.rename}")
    // if (!visium_data) {
    //     visium_url = Channel.of("${params.dwl.visiumHD.url}")
    //     download_visiumHD(visium_url)
    // } else {
    //     println "Visium Data already present - Skipping"
    // }
    
    def stereo_data = file("${params.dwl.data}/stereo/${params.dwl.stereo.rename}")
    
    if (!stereo_data.exists()) {
        stereo_url = Channel.of("${params.dwl.stereo.url}")
        println "Downloading from: ${params.dwl.stereo.url}"
        download_stereo(stereo_url)
    } else {
        println "Stereo-seq Data already present - Skipping"
    }
}