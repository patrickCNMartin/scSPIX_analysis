//=============================================================================
// WORKFLOW
//=============================================================================
nextflow.enable.dsl=2

include {download_data} from './workflows/dwl_data.nf'
include {checkAndBuildContainers} from './workflows/build_containers.nf'

workflow {
    if (params.containers.check_and_build == true){
        println "Checking if containters are present and Building..."
        checkAndBuildContainers()
    }
    if (params.dwl.run == true) {
        println "Downloading data..."
        download_data()
    }
    
}