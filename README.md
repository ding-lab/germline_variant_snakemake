# germline_calling_snakemake

## Intro

Snakemake workflow to call germline variant by using GATK, VarScan, and Pindel. The Snakefile should be applicable on google cloud.


## Content

### Working Environment

`local_test`: Snakemake workflow run successfully on denali. It is the working version for every environment, and `config.yaml` need to change based on the environment. Update the `sample.txt` with the BAMs pathyou want to work on.

`google_api`: Snakemake workflow combined with google pipeline API successfully run on google cloud. 

`cluster_google_api`: Run snakemake workflows in a cluster mode.

### Required Files

`scripts`: Customized scripts for germline variant calling. 

`files`: Required files like chromosome intervals for germline variant calling tools (Check if your reads started with `chr` or not. Change the prefix of chromosome accordingly).

## How to start on a local enviornment

1. Clone the repository: `git clone https://github.com/ding-lab/germline_variant_snakemake.git`

2. Change the priority of conda channels:

```
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
```

3. Create a conda environment: `conda create -n snakemake python=3.6 snakemake pindel varscan gatk4 samtools pandas bcftools`

4. Activate environment: `source activate snakemake`

5. Go to folder: `cd local_test`

6. Change the path to `pindel2vcf` in `config.yaml` accordinly. (Follow the section below)

7. Dry run: `snakemake -n -p all_tools`

8. Run a task: `snakemake -j ${how many cpu you want to use} -p all_tools`. Noted that all the files will be kept. Remerber to delete temp files to save the disk space.

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

## Configure snakemake workflow based on your working enviornment (only for local_test)

1. Find out the path to the cloned repository.

2. `source activate snakemake` and find out the path to the `pindel2vcf` by typing `which pindel`. `pindel` and `pindel2vcf` are in the same folder.

3. `vi config.yaml`

```
samples: {Your file with header and sample lines} 
# sample lines should follow the format: ID\tPath2Ref\tPath2BAM
interval_prefix: "{Path to cloned repo}/germline_variant_snakemake/files/interval_chr"
path_to_pindel2vcf: "{Path to pindel}2vcf"
```

## Result VCF
The result vcfs are `{sample}.gatk.snv.filtered.vcf`, `{sample}.gatk.indel.filtered.vcf`, `{sample}.varscan.snv.filtered.vcf`, `{sample}.varscan.indel.filtered.vcf`, `{sample}.pindel.vcf`.

## Merge result VCFs 
There is no good commend to replace CombineVariants in gatk4, so we need to stick with gatk 3.8
1. Use docker image: `broadinstitute/gatk3:3.8-0`
2. Merge commend

```
java -Xms256m -Xmx512m -jar GenomeAnalysisTK.jar -T CombineVariants -R /path/to/reference/GRCh37-lite.fa -o ${id}.merged.vcf \
--variant:gsnp ${id}.gatk.snp.filtered.vcf \
--variant:gindel ${id}.gatk.indel.filtered.vcf \
--variant:vsnp ${id}.varscan.snp.filtered.vcf \
--variant:vindel ${id}.varscan.indel.filtered.vcf \
--variant:pindel ${id}.pindel.vcf \
-genotypeMergeOptions PRIORITIZE \
-priority gsnp,vsnp,gindel,vindel,pindel
```
