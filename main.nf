
def reference_tree = params.assays[params.assay].reference
def input_params = params.assays[params.assay].pipeline_params
def assay_type = params.assays[params.assay].assay_type
def container_hash = params.assays[params.assay].container
def sample_base = params.sample_base
def output_base = params.output_base


// split by command and/or space(s) and remove any remaining nulls
def samples = params.samples.split(/[,\ ]+/) - null


println("Total samples: " + samples.size())
println("Samples: " + samples.join(", "))

Channel.from(samples).map {
  s -> [s, "${sample_base}/${s}/${assay_type}/libraries/"]
}.set { sample_ch }


process run_pipeline {
  echo true
  label "pipeline"
  container container_hash
  input:
    // tuple val(sample), path(fastqs, stageAs: "inputs/libraries") from sample_ch
    tuple val(sample), val(fastq_path) from sample_ch
    path params, stageAs: "inputs/params.json" from input_params
    path references, stageAs: "references" from reference_tree

  output:
    path("outputs/*") into output_ch

  // publish, but drop the "outputs/" prefix
  publishDir "${output_base}/${sample}/${assay_type}/analyses/${uuid}/output/", mode: 'copy', overwrite: 'true', saveAs: {f -> f.tokenize("/").drop(1).join("/")}

  script:
  def uuid = UUID.randomUUID().toString()
  """
  # download input libraries; note this is compatible with restored files
  wget --quiet "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip"
  unzip -qq awscliv2.zip
  sudo ./aws/install || ./aws/install
  
  mkdir -p inputs/libraries
  aws s3 cp --recursive --force-glacier --only-show-errors ${fastq_path} inputs/libraries

  # set up directory structure as expected by snakemake file
  # necessary as we can't stage into directories at the root ('/') directly
  ln -s `pwd`/inputs /inputs
  ln -s `pwd`/references /references

  mkdir outputs && ln -s `pwd`/outputs /outputs
  
  # configure inputs
  python /usr/local/bin/prep_analysis.py \
    /cpdx/snakemake_preconfig.json \
    outputs/snakemake_config.json


  export RUN_KEY_ROOT="${sample}/${assay_type}/analyses/${uuid}/"

  # run analysis
  snakemake -s /usr/local/bin/Snakefile \
    --cores ${task.cpus} \
    --resources mem_mb=${task.memory.toMega()} \
    --config maxthreads=${task.cpus} memory=${task.memory.toMega()}
  
  """

}
