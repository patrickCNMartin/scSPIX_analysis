nextflow.enable.dsl=2
include { isMac; isLinux; getContainerImage } from "${baseDir}/lib/utils.nf"

workflow checkAndBuildContainers {
    
    Channel
        .fromPath("${params.containers.containerDir}/*", type: 'dir')
        .set { container_dirs }
    
    buildContainers(container_dirs)
}
process buildContainers {
    
    input:
    each path(containerDir)
    
    output:
    path "*.{sif,tar}", optional: true
    
    script:
    def name = containerDir.name
    def cacheDir = params.containers.containerCache
    def useMac = isMac()
    """
    mkdir -p ${cacheDir}
    
    if [ "${useMac}" = "true" ]; then
        imagePath="${cacheDir}/${name}.tar"
        
        if [ ! -f "\${imagePath}" ]; then
            echo "Building Docker image for ${name}..."
            # Change to containerDir so Docker can find env files in build context
            cd ${containerDir}
            docker build -t ${name}:latest -f Dockerfile .
            docker save ${name}:latest -o \${imagePath}
            echo "Built Docker image for ${name}"
        else
            echo "Docker image for ${name} already exists"
        fi
        ln -s \${imagePath} ${name}.tar
    else
        imagePath="${cacheDir}/${name}.sif"
        
        if [ ! -f "\${imagePath}" ]; then
            echo "Building apptainer image for ${name}..."
            module load apptainer
            # Change to containerDir so apptainer can find env files
            cd ${containerDir}
            apptainer build --fakeroot \${imagePath} ${name}.def
            echo "Built apptainer image for ${name}"
        else
            echo "Apptainer image for ${name} already exists"
        fi
        ln -s \${imagePath} ${name}.sif
    fi
    """
}