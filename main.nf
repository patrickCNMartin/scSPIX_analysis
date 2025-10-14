//=============================================================================
// WORKFLOW
//=============================================================================
nextflow.enable.dsl=2

include {download_data} from './workflows/dwl_data.nf'

workflow {
    if (params.dwl.run == true) {
        download_data()
    }
    
}