nextflow.enable.dsl=2

include { isMac; isLinux;} from "${baseDir}/lib/utils.nf"
//=============================================================================
// PROCESSES
//=============================================================================
process download_visiumHD {
    publishDir "${params.dwl.data}/visiumHD", mode: 'copy', overwrite: true
    input:
    path url
    output:
    path ${params.dwl.visiumHD.rename}
    script:
    """
    echo "Download Visium HD"
    if [ "${useMac}" = "true" ]; then
        curl ${url}
    else
        wget ${url}
    fi
    """
}


process download_stereo {
    publishDir "${params.dwl.data}/stereo", mode: 'copy', overwrite: true
    input:
    path url
    output:
    path ${params.dwl.stereo.rename}
    script:
    """
    echo "Download Stereo Seq"
    if [ "${useMac}" = "true" ]; then
        curl ${url}
    else
        wget ${url}
    fi
    """
}

//=============================================================================
// Workflow
//=============================================================================

workflow download_data {
    // visium_data = file("${params.dwl.visiumHD.rename}")
    // if (!visium_data) {
    //     visium_url = Channel.fromPath("${params.dwl.visiumHD.url}")
    //     download_visiumHD(visium_url)
    // } else {
    //     println "Visium Data already present - Skipping"
    // }
    
    stereo_data = file("${params.dwl.stereo.rename}")
    if (!stereo_data) {
        stereo_url = Channel.fromPath("${params.dwl.stereo.url}")
        download_stereo(stereo_url)
    } else {
        println "Stereo-seq Data already present - Skipping"
    }

}