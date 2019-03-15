# germline_calling_snakemake

## Intro

Snakemake workflow to call germline variant by using GATK, VarScan, and Pindel. The Snakefile should be applicable on google cloud, Dinglab cluster, and MGI cluster.


## Content of Directory

### Working Environment

`local_test`: Settings for runs in Dinglab cluster Denali.

`google_api`: Settings for runs on google cloud. 

`mgi`: Settings for runs in MGI cluster.

### Required Files

`scripts`: Customized scripts for germline variant calling.

`files`: Required files like chromosome intervals (Check if your reads started with `chr` or not. Change the prefix of chromosome accordingly).

`env`: Conda env yml files for GATK 3.8. This tool need to be set seperately because it is not compatible with other tools.

## Sanity check of your BAM before snakemake run

Since GATK requires BAMs to be formatted in a specific way, Snakemake will complain about it if GATK can't run smoothly (and most of errors come from it). Highly recommend user to run GATK locally first to  make sure there is no problem on running GATK HaplotypeCaller. If there is an error, GATK blog is a good resource for troubleshooting. Below are some common errors and solution:

- Check if the chromosome starts with `chr` or not, and change the chromosome interval files accordingly. 

- Make sure if the ReadGroup is correct. If not, use `gatk AddOrReplaceReadGroups` to change accordingly.


## How to start a run on local environment and MGI

1. Clone the repository: `git clone https://github.com/ding-lab/germline_variant_snakemake.git`

2. Change the priority of conda channels:

```
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
```

3. Create a conda environment: `conda create -n snakemake python=3.6 snakemake pindel varscan gatk4 samtools pandas bcftools vcf2maf ensembl-vep`

4. Create a seperate conda environment for GATK 3.8: `conda env create -f germline_variant_snakemake/env/gatk38.yml`. `conda activate gatk38` and then follow the [Note here](https://bioconda.github.io/recipes/gatk/README.html). Briefly, download archived version GATK 3.8 to folder, and run `gatk3-register /path/to/GenomeAnalysisTK[-$PKG_VERSION.tar.bz2|.jar]`.
  
5. Activate environment: `conda activate snakemake`

### On local environment

6. Go to folder: `cd local_test`

7. Change the path to `pindel2vcf` and GATK 3.8 jar file in `config.yaml` accordinly. (See the section below)

8. Dry run: `snakemake -n -p all_tools`

9. Run a task: `snakemake -j ${how many cpu you want to use} -p all_tools`. Noted that all the files will be kept. Remerber to delete temp files to save space.

### On MGI

6. Go to folder : `cd mgi`

7. Change the path to `pindel2vcf` and GATK 3.8 jar file in `config.ymal` accordinly. (See the section below)

8. Make a folder for LSF logs: `mkdir lsf_logs`

9. Check if `/bin/bash` works. If it is masked by other bash path such as `/gsc/bin/bash`, follow the [confluence page here](https://confluence.ris.wustl.edu/display/DL/How+to+run+Docker+on+MGI)

10. Run a task: `bash run.sh`

## How to start on google cloud

1. Generate the required commend for google cloud by using the script: `/diskmnt/Projects/Users/wliang/Germline_Noncoding/06_Cloud_Variant_Calling/bampath/generate_command.snakemake.sh`

2. `bash generate_command.snakemake.sh TCGA_WGS_gspath_WWL_Mar2018.LowPass.normal.txt LowPass`

3. Create a VM in Project.

4. Get sufficient authentication scopes: `gcloud auth login`

5. Clone the repository: `git clone https://github.com/ding-lab/germline_variant_snakemake.git`

6. Run a google pipeline API commend: 
```
gcloud alpha genomics pipelines run \
--pipeline-file ~/germline_variant_snakemake/google_api/germline_snakemake.yaml \
--inputs fafile=gs://dinglab/reference/Homo_sapiens_assembly19.fasta,\
faifile=gs://dinglab/reference/Homo_sapiens_assembly19.fasta.fai,\
dictfile=gs://dinglab/reference/Homo_sapiens_assembly19.dict,\
bamfile=gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/LUAD/DNA/WGS/HMS-RK/ILLUMINA/TCGA-44-4112-11A-01D-1103_120318_SN1120_0124_AC0HNPACXX_s_2_rg.sorted.bam,\
baifile=gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/LUAD/DNA/WGS/HMS-RK/ILLUMINA/TCGA-44-4112-11A-01D-1103_120318_SN1120_0124_AC0HNPACXX_s_2_rg.sorted.bam.bai,\
sample=TCGA-44-4112-11A-01D-1103-02 \
--outputs outputPath=gs://wliang/germline_snakemake/output/LowPass/TCGA-44-4112-11A-01D-1103-02/ \
--logging gs://wliang/germline_snakemake/logging/LowPass/ \
--project washu-medicine-pancan \
--disk-size datadisk:50 \
--preemptible
```

7. Since preemptible machines might be shut down for no reasons, it would be helpful to launch batch jobs by using script `submit_google_api.py`. This scirpt reads manifest, launchs jobs for the first 30 samples of manifest, checks the status of lauched job evey minutes, and keeps a certain number of VMs for running. The output `{filename_of_manifest}.result.tsv` gives you a snapshot of `case_full_barcode	cmd	status	operation_id	num_of_repeats`. Noted that if a sample related job has been launched more than 16 times, the script stops lauch it again. User is suggested to go check the specific job or sample, make sure there is no problems, and relauch it manually. One sample usually can be completed withing 16 times.

## Configure snakemake workflow based on your working enviornment (only for local_test)

1. Find out the path to the cloned repository.

2. `conda activate snakemake` and find out the path to the `pindel2vcf` by typing `which pindel`. `pindel` and `pindel2vcf` are in the same folder.

3. `vi config.yaml`

```
samples: {Your file with header and sample lines} 
# sample lines should follow the format: ID\tPath2Ref\tPath2BAM
interval_prefix: "{Path to cloned repo}/germline_variant_snakemake/files/interval_chr"
path_to_pindel2vcf: "{Path to pindel}2vcf"
path_to_gatk_jar: "{Path to GenomeAnalysisTK.jar}"
```

## Result VCF

Change the input of rule `all_tools` in `Snakefile` to the result VCF user would like. The defalt is one multi-sample merged VCF and one MAF file. 
