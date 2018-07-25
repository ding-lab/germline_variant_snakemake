# germline_calling_snakemake

## Intro

Snakemake workflow to call germline variant by using GATK, VarScan, and Pindel. The Snakefile should be applicable on google cloud.


## Content

### Working Environment

`local_test`: Snakemake workflow run successfully on denali. It is the working version for every environment, and `config.yaml` need to change based on the environment. Update the `sample.txt` with the BAMs pathyou want to work on.

`google_api`: Snakemake workflow combined with google pipeline API successfully run on google cloud. 

### Required Files

`scripts`: Customized scripts for germline variant calling. 

`files`: Required files for germline variant calling tools.

## How to start on a local enviornment

1. Clone the repository: `git clone https://github.com/ding-lab/germline_variant_snakemake.git`

2. Create a conda environment: `conda create -n snakemake python=3.6 snakemake pindel varscan gatk4 samtools pandas bcftools`

3. Activate environment: `source activate snakemake`

4. Go to folder: `cd local_test`

5. Dry run: `snakemake -n -p all_tools`

6. Run a task: `snakemae -j ${how many cpu you want to use} -p all_tools`. Noted that you have to prepare the pindel config file.

## How to start on a google cloud

1. Generate the required commend for google cloud by using the script: `/diskmnt/Projects/Users/wliang/Germline_Noncoding/06_Cloud_Variant_Calling/bampath/generate_command.snakemake.sh`

2. `bash generate_command.snakemake.sh TCGA_WGS_gspath_WWL_Mar2018.LowPass.normal.txt LowPass`

3. Create a VM in Project.

4. Clone the repository: `git clone https://github.com/ding-lab/germline_variant_snakemake.git`

5. Run a commend: `gcloud alpha genomics pipelines run --pipeline-file ~/germline_variant_snakemake/google_api/germline_snakemake.yaml --inputs fafile=gs://dinglab/reference/Homo_sapiens_assembly19.fasta,faifile=gs://dinglab/refer
ence/Homo_sapiens_assembly19.fasta.fai,dictfile=gs://dinglab/reference/Homo_sapiens_assembly19.dict,bamfile=gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/LUAD/DNA/WGS/HMS-RK/ILLUMINA/TCGA-44-4112-11A-01D-1103_1
20318_SN1120_0124_AC0HNPACXX_s_2_rg.sorted.bam,baifile=gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/LUAD/DNA/WGS/HMS-RK/ILLUMINA/TCGA-44-4112-11A-01D-1103_120318_SN1120_0124_AC0HNPACXX_s_2_rg.sorted.bam.bai,sa
mple=TCGA-44-4112-11A-01D-1103-02 --outputs outputPath=gs://wliang/germline_snakemake/output/LowPass/TCGA-44-4112-11A-01D-1103-02/ --logging gs://wliang/germline_snakemake/logging/LowPass/ --project washu-medici
ne-pancan --disk-size datadisk:50 --preemptible`
