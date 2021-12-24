import groovy.json.JsonSlurper
import groovy.json.JsonOutput

def reference_tree = params.assays[params.assay].reference
def assay_type = params.assays[params.assay].assay_type
def container_hash = params.assays[params.assay].container
def sample_base = params.sample_base.replaceAll('[/]*$', '')
def output_base = params.output_base.replaceAll('[/]*$', '')


// set up params file (target file + optional gene list)
def input_params;
if (assay_type == "cdl") {
  def jsonSlurper = new JsonSlurper()
  String paramsJSON = new File("params/cdl.params.json").text
  input_params = jsonSlurper.parseText(paramsJSON)
} else if (assay_type == "exome") {
  input_params = ["target": "target.bed", "genelist": []]
} else if (assay_type == "exome-panel") {
  def genelist = params.gene_list.split(/[,\ ]+/) - null
  input_params = ["target": "target.bed", "genelist": genelist]
}

print("Params are: ${input_params}")
def input_params_json = JsonOutput.toJson(input_params)

// split by command and/or space(s) and remove any remaining nulls
def samples = params.samples.split(/[,\ ]+/) - null
println("Total samples: " + samples.size())
println("Samples: " + samples.join(", "))

Channel.from(samples).map {
  s -> [s, UUID.randomUUID().toString(), "${sample_base}/${s}/${assay_type}/libraries/", input_params_json]
}.set { sample_ch }

process run_pipeline {
  echo true
  label "pipeline"
  container container_hash
  input:
    tuple val(sample), val(uuid), val(fastq_path), val(inparams) from sample_ch
    path references, stageAs: "references" from reference_tree
  output:
    path("outputs/*") into output_ch
    path("inputs/params.json")

  // publish, but drop the "outputs/" prefix
  publishDir "${output_base}/${sample}/${assay_type}/analyses/${uuid}/output/", mode: 'copy', overwrite: 'true', saveAs: {f -> f.tokenize("/").drop(1).join("/")}
  publishDir "${output_base}/${sample}/${assay_type}/analyses/${uuid}/", pattern: "params.json" mode: 'copy', overwrite: 'true', saveAs: { f -> "params.json"}
  
  script:
  """
  wget --quiet "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip"
  unzip -qq awscliv2.zip
  sudo ./aws/install || ./aws/install
  
  # set up directory structure as expected by snakemake file
  # necessary as we can't stage into directories at the root ('/') directly
  mkdir -p inputs/libraries && ln -s `pwd`/inputs /inputs
  mkdir outputs && ln -s `pwd`/outputs /outputs
  ln -s `pwd`/references /references
  
  # download input libraries; note this is compatible with restored files
  aws s3 cp --recursive --force-glacier --only-show-errors ${fastq_path} inputs/libraries

  # configure inputs
  echo '${inparams}' > inputs/params.json

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
