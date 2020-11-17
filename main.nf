
def reference_tree = params.assays[params.assay].reference
def input_params = params.assays[params.assay].pipeline_params
def assay_type = params.assays[params.assay].assay_type
def container_hash = params.assays[params.assay].container
def sample_base = params.sample_base
def output_base = params.output_base


// split by command and/or space(s) and remove any remaining nulls
// def samples = params.samples.split(/[,\ ]+/) - null

def samples = [
  ["20-10580-1", "20-10580-1-630865-retracted"],
  ["20-10583-1", "20-10583-1-630865-retracted"],
  ["20-10588-1", "20-10588-1-630865-retracted"],
  ["20-10597-1", "20-10597-1-630865-retracted"],
  ["20-10598-1", "20-10598-1-630865-retracted"],
  ["20-10599-1", "20-10599-1-630865-retracted"],
  ["20-10603-1", "20-10603-1-630865-retracted"],
  ["20-10605-1", "20-10605-1-630865-retracted"],
  ["20-10606-1", "20-10606-1-630865-retracted"],
  ["20-10611-1", "20-10611-1-630865-retracted"],
  ["20-10612-1", "20-10612-1-630865-retracted"]
]

println("Total samples: " + samples.size())
println("Samples: " + samples.join(", "))

//Channel.from(samples).map {
  //s -> [s, "${sample_base}/${s}/${assay_type}/libraries/"]
//}.set { sample_ch }

Channel.from(samples).map {
  s -> 
    if (s.size == 1){
      return [s[0], "${sample_base}/${s[0]}/${assay_type}/libraries/"]
    }
    else  {
      return [s[0], "${sample_base}/${s[0]}/${assay_type}/libraries/${s[1]}"]
    }
}.view().set { sample_ch }

process run_pipeline {
  echo true
  label "pipeline"
  container container_hash
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
