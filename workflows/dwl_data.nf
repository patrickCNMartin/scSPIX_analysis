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
    path "${params.dwl.visiumHD.rename}*"
    
    script:
    def useMac = isMac()
    """
    echo "Download VisiumHD"
    echo "Downloading from: ${url}"
    
    if [ "${useMac}" = "true" ]; then
        curl -L -O "${url}"
    else
        wget "${url}"
    fi
    
    downloaded_file=\$(ls -t | head -n 1)
    
    echo "Downloaded file: \$downloaded_file"
    
    mv "\$downloaded_file" "${params.dwl.visiumHD.rename}\${downloaded_file}"
    
    echo "Renamed to: ${params.dwl.visiumHD.rename}\${downloaded_file}"
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
        curl -L -O "${url}"
    else
        wget "${url}"
    fi
    
    downloaded_file=\$(ls -t | head -n 1)
    
    echo "Downloaded file: \$downloaded_file"
    
    mv "\$downloaded_file" "${params.dwl.stereo.rename}_\${downloaded_file}"
    
    echo "Renamed to: ${params.dwl.stereo.rename}_\${downloaded_file}"
    """
}
//=============================================================================
// Workflow
//=============================================================================

workflow download_data {
    def visium_dir = file("${params.dwl.data}/visiumHD/")
    if (!visium_dir.exists() || visium_dir.list().length == 0) {
        visium_urls = Channel.fromList(params.dwl.visiumHD.url)
        download_visiumHD(visium_urls)
        println "Downloading ${params.dwl.visiumHD.url.size()} VisiumHD files"
    } else {
        println "Visium Data already present - Skipping"
    }
    
    def stereo_data = file("${params.dwl.data}/stereo/")
    if (!stereo_data.exists()) {
        stereo_url = Channel.of("${params.dwl.stereo.url}")
        println "Downloading from: ${params.dwl.stereo.url}"
        download_stereo(stereo_url)
    } else {
        println "Stereo-seq Data already present - Skipping"
    }
}