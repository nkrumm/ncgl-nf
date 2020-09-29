
def reference_tree = params.assays[params.assay].reference
def input_params = params.assays[params.assay].pipeline_params

def sample_base = "s3://uwlm-personal/nkrumm/NCGL/200925_NB502000_0429_AHFGKCAFX2"
def output_base = "s3://uwlm-personal/nkrumm/NCGL/outputs"

// split by command and/or space(s) and remove any remaining nulls
def samples = params.samples.split(/[,\ ]+/) - null
println("Total samples: " + samples.size())
println("Samples: " + samples.join(", "))

sample_ch = Channel.from(samples).map {
  s -> [s, "${sample_base}/${s}/unknown/"]
}

process run_task {
  echo true
  label "pipeline"

  input:
    tuple val(sample), path(fastqs, stageAs: "inputs/libraries") from sample_ch
    path params, stageAs: "inputs/params.json" from input_params
    path references, stageAs: "references" from reference_tree

  output:
    path("outputs/*") into output_ch

  // publish, but drop the "outputs/" prefix
  publishDir "${output_base}/${sample}/", mode: 'copy', overwrite: 'true', saveAs: {f -> f.tokenize("/").drop(1).join("/")}

  script:

  """
  # set up directory structure as expected by snakemake file
  # necessary as we can't stage into directories at the root ('/') directly
  ln -s `pwd`/inputs /inputs
  ln -s `pwd`/references /references
  mkdir outputs && ln -s `pwd`/outputs /outputs
  
  touch /outputs/test.out

  # configure inputs
  python /usr/local/bin/prep_analysis.py \
    /cpdx/snakemake_preconfig.json \
    outputs/snakemake_config.json


  export RUN_KEY_ROOT="test-run-key"

  # run analysis
  snakemake -s /usr/local/bin/Snakefile \
    --cores ${task.cpus} \
    --resources mem_mb=${task.memory.toMega()} \
    --config maxthreads=${task.cpus} memory=${task.memory.toMega()}
  
  """

}