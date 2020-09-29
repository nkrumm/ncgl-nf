
def input_libraries = "s3://uwlm-personal/nkrumm/NCGL/200925_NB502000_0429_AHFGKCAFX2/${params.sample}/unknown/"

def reference_tree = params.assays[params.assay].reference
def input_params = params.assays[params.assay].pipeline_params

process run_task {
  echo true
  label "pipeline"

  input:
    path fastqs, stageAs: "inputs/libraries" from input_libraries
    path params, stageAs: "inputs/params.json" from input_params
    path references, stageAs: "references" from reference_tree

  output:
    path("outputs/*") into output_ch

  publishDir "s3://uwlm-personal/nkrumm/NCGL/outputs/${sample_id}/"

  script:

  """
  # set up directory structure as expected by snakemake file
  # necessary as we can't stage into directories at the root ('/') directly
  ln -s `pwd`/inputs /inputs
  ln -s `pwd`/references /references
  mkdir outputs && ln -s `pwd`/outputs /outputs
  
  touch /outputs/test.out

  # configure inputs
  # python /usr/local/bin/prep_analysis.py \
    # /cpdx/snakemake_preconfig.json \
    # outputs/snakemake_config.json


  RUN_KEY_ROOT="test-run-key"

  # run analysis
  # snakemake -s /usr/local/bin/Snakefile \
    # --cores ${task.cpus} \
    # --resources mem_mb=${task.memory} \
    # --config maxthreads=${task.cpus} memory=${task.memory}
  
  """

}