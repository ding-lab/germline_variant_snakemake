# Call germline variant

import os
import pandas as pd
from pathlib import Path
from snakemake.remote.GS import RemoteProvider as GSRemoteProvider
GS = GSRemoteProvider()

BUCKET = "wliang/snakemake_germlinevariant/highpass/"
INTERVALPREFIX = "/home/germline_calling_snakemake/files/interval_chr"
CHR=[str(i) for i in range (1,23)]
CHR.append("X")
CHR.append("Y")

### Get BAM path and sample id from config file

configfile: "config.yaml"

SAMPLE = pd.read_table(config["samples"])["sample"].drop_duplicates().tolist()
BAMPATH_DICT = pd.read_table(config["samples"])[["sample","bampath"]].drop_duplicates().set_index("sample")["bampath"].to_dict()
REF_DICT = pd.read_table(config["samples"])[["sample","reference"]].drop_duplicates().set_index("sample")["reference"].to_dict()
FILE_DICT = pd.read_table(config["samples"])[["sample","filename"]].drop_duplicates().set_index("sample")["filename"].to_dict()

### Run GATK HaplotypeCaller and Select Variant
rule gatk_haplotypecaller:
    input: 
        genome_fa = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
        bam = lambda wildcards: GS.remote(BAMPATH_DICT[wildcards.sample]),
        interval = f"{INTERVALPREFIX}{{ix}}.list"
    output: temp("{sample}.gatk.raw.chr{ix}.vcf")
    shell: "gatk HaplotypeCaller -R {input.genome_fa} -I {input.bam} -L {input.interval} -O {output} --standard-min-confidence-threshold-for-calling 30.0"

rule gatk_selectvariant_snp:
    input:
        genome_fa = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
        input_vcf = "{sample}.gatk.raw.chr{ix}.vcf"
    output: temp("{sample}.gatk.snp.chr{ix}.vcf")
    shell: "gatk SelectVariants -R {input.genome_fa} -V {input.input_vcf} -O {output} -select-type SNP -select-type MNP"

rule gatk_selectvariant_indel:
    input:
        genome_fa = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
        input_vcf = "{sample}.gatk.raw.chr{ix}.vcf"
    output: temp("{sample}.gatk.indel.chr{ix}.vcf")
    shell: "gatk SelectVariants -R {input.genome_fa} -V {input.input_vcf} -O {output} -select-type INDEL"

rule gatk_merge_snp_vcf:
    input: calls= expand('{{sample}}.gatk.snp.chr{ix}.vcf', ix=CHR)
    output: "{sample}.gatk.snp.vcf"
    wrapper: "0.26.0/bio/bcftools/concat"

rule gatk_merge_indel_vcf:
    input: calls= expand('{{sample}}.gatk.indel.chr{ix}.vcf', ix=CHR)
    output: "{sample}.gatk.indel.vcf"
    wrapper: "0.26.0/bio/bcftools/concat"

rule test_gatk:
    input: expand("{sample}.gatk.indel.vcf", sample=SAMPLE)


###Run Varscan
rule varscan_mpileup2snp:
    input:
         genome_fa = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
         bam = lambda wildcards: GS.remote(BAMPATH_DICT[wildcards.sample])
    output:temp("{sample}.varscan.snp.chr{ix}.vcf")
    params: chr="{ix}"
    shell: "samtools mpileup -q 1 -Q 13 -f {input.genome_fa} -r {params.chr} {input.bam} | varscan mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 > {output}"

rule varscan_mpileup2indel:
    input:
         genome_fa = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
         bam = lambda wildcards: GS.remote(BAMPATH_DICT[wildcards.sample])
    output:temp("{sample}.varscan.indel.chr{ix}.vcf")
    params: chr="{ix}"
    shell: "samtools mpileup -q 1 -Q 13 -f {input.genome_fa} -r {params.chr} {input.bam} | varscan mpileup2indel - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 > {output}"

rule varscan_snp_index:
    input: "{sample}.varscan.snp.chr{ix}.vcf"
    output: temp("{sample}.varscan.snp.chr{ix}.vcf.gz")
    shell: "bcftools view {input} -Oz -o {output}; bcftools index {output}"

rule varscan_indel_index:
    input: "{sample}.varscan.indel.chr{ix}.vcf"
    output: temp("{sample}.varscan.indel.chr{ix}.vcf.gz")
    shell: "bcftools view {input} -Oz -o {output}; bcftools index {output}"

rule varscan_merge_snp_vcf:
    input: calls= expand('{{sample}}.varscan.snp.chr{ix}.vcf.gz', ix=CHR)
    output: "{sample}.varscan.snp.vcf"
    wrapper: "0.26.0/bio/bcftools/concat"

rule varscan_merge_indel_vcf:
    input: calls= expand('{{sample}}.varscan.indel.chr{ix}.vcf.gz', ix=CHR)
    output: "{sample}.varscan.indel.vcf"
    wrapper: "0.26.0/bio/bcftools/concat"


###Run Pindel

rule pindel_call:
    input:
        ref = lambda wildcards: GS.remote(REF_DICT[wildcards.sample]),
        samples = lambda wildcards: GS.remote(BAMPATH_DICT[wildcards.sample])
        filename = lambda wildcards: FILE_DICT[wildcards.sample]
    output: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw"
    params:
        prefix="pindel/chr{ix}/{sample}.chr{ix}",
        extra="-x 4 -w 0.1 -B 0 -M 3 -J pindel-centromere-exclude.bed -c {ix}",
        chr="{ix}",
        sample="{sample}"
    threads: 4
    shell: "echo -e '/home/{input.filename}\t500\t{params.sample}' > {params.sample}.pindel_config.txt ;  pindel {params.extra} -T {threads} -f {input.ref} -i {params.sample}.pindel_config.txt -o {params.prefix} ; cat pindel/chr{params.chr}/{params.sample}.chr{params.chr}_D pindel/chr{params.chr}/{params.sample}.chr{params.chr}_INV pindel/chr{params.chr}/{params.sample}.chr{params.chr}_TD pindel/chr{params.chr}/{params.sample}.chr{params.chr}_SI | grep ChrID > {output}"

#Generate the config file for pindel_filter.v0.5.pl

rule pindel_filter_config:
    input: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw"
    output: "pindel/chr{ix}/{sample}.pindel.input.chr{ix}.txt"
    params: 
        sample="{sample}",
        chr="{ix}",
    run:
        for ix in CHR:
            filename={output}
#f"pindel/chr{params.chr}/{params.sample}.pindel.input.chr{params.chr}.txt"
            os.makedirs(os.path.dirname(filename), exist_ok=True)
            with open(filename, "w") as f:
                f.write ( \
f"pindel.filter.pindel2vcf = /diskmnt/Projects/Users/wliang/miniconda3/envs/snakemake/bin/pindel2vcf\n\
pindel.filter.variants_file = pindel/chr{params.chr}/{params.sample}.pindel.out.chr{params.chr}.raw\n\
pindel.filter.REF = /diskmnt/Datasets/Reference/human_genome/GRCh37-lite/GRCh37-lite.fa\n\
pindel.filter.date = 000000\n\
pindel.filter.heterozyg_min_var_allele_freq = 0.2\n\
pindel.filter.homozyg_min_var_allele_freq = 0.8\n\
pindel.filter.mode = germline\n\
pindel.filter.apply_filter = true\n\
pindel.filter.germline.min_coverages = 10\n\
pindel.filter.germline.min_var_allele_freq = 0.20\n\
pindel.filter.germline.require_balanced_reads = 'true'\n\
pindel.filter.germline.remove_complex_indels = 'true'\n\
pindel.filter.germline.max_num_homopolymer_repeat_units = 6")


rule filter_pindel:
    input: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw"
    output: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw.CvgVafStrand_pass.Homopolymer_pass.vcf"
    params: chr='{ix}',
            sample='{sample}'
    shell: "perl scripts/pindel_filter.v0.5.pl pindel/chr{params.chr}/{params.sample}.pindel.input.chr{params.chr}.txt"

rule index_pindel:
    input: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw.CvgVafStrand_pass.Homopolymer_pass.vcf"
    output: "pindel/chr{ix}/{sample}.pindel.out.chr{ix}.raw.CvgVafStrand_pass.Homopolymer_pass.vcf.gz"
    shell: 'bcftools view {input} -Oz -o {output}; bcftools index {output}'

rule pindel_merge_vcf:
    input: calls=expand("pindel/chr{ix}/{{sample}}.pindel.out.chr{ix}.raw.CvgVafStrand_pass.Homopolymer_pass.vcf.gz", ix=CHR)
    output: "{sample}.pindel.vcf"
    wrapper: "0.27.0/bio/bcftools/concat"

rule all_tools:
    input: 
        expand("{sample}.gatk.snp.filtered.vcf", sample=SAMPLE),
        expand("{sample}.gatk.indel.filtered.vcf", sample=SAMPLE),
        expand("{sample}.varscan.snp.filtered.vcf", sample=SAMPLE),
        expand("{sample}.varscan.indel.filtered.vcf", sample=SAMPLE),
        expand("{sample}.pindel.vcf", sample=SAMPLE)

rule filter:
    input: "{sample}.gatk.snp.vcf", "{sample}.gatk.indel.vcf", "{sample}.varscan.snp.vcf", "{sample}.varscan.indel.vcf"
    output: "{sample}.gatk.snp.filtered.vcf", "{sample}.gatk.indel.filtered.vcf", "{sample}.varscan.snp.filtered.vcf", "{sample}.varscan.indel.filtered.vcf"
    shell: "perl scripts/filter_g:atk_varscan.pl `pwd`"

#rule merge_vcf:
#    input: 
#        gsnp = "gatk.snp.filtered.vcf",
#        gindel = "gatk.indel.filtered.vcf",
#        vsnp = "varscan.snp.filtered.vcf", 
#        vindel = "varscan.indel.filtered.vcf",
#        pindel = "pindel.vcf",
#        genome_fa = GENOME_FA
#    output: "merged.vcf"
#    singularity: "docker://broadinstitute/gatk3:3.8-0"
#    shell: "java -Xms256m -Xmx512m -jar GenomeAnalysisTK.jar -T CombineVariants -R {input.genome_fa} -o {output} --variant:gsnp {input.gsnp} --variant:gindel {input.gindel} --variant:vsnp {input.vsnp} --variant:vindel {input.vindel} --variant:pindel {input.pindel} -genotypeMergeOptions PRIORITIZE -priority gsnp,vsnp,gindel,vindel,pindel"
    
   
