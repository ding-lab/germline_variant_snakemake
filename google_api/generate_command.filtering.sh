####
#Aim: Generate google cloud command
#Usage: bash generate_command.sh ${List_of_BAMs} ${JobName}
#1. bash generate_command.pipeline.sh ~/job/merge.todo.highpass.txt HighPass
#Author: Wen-Wen Liang @ Wash U (liang.w@wustl.edu)
####


while read lines; do
	id=$(echo $lines | awk -F " " '{print $3}')
	passvalue=$2
	ref=$(echo $lines | awk -F " " '{if ($8=="HG19_Broad_variant") print "gs://ding_lab_reference/Homo_sapiens_assembly19.fasta"; else print "gs://ding_lab_reference/GRCh37-lite.fa"}')
	reffile=$(echo $lines | awk -F " " '{if ($8=="HG19_Broad_variant") print "Homo_sapiens_assembly19.fasta"; else print "GRCh37-lite.fa"}')
	yaml="./germline_variant_snakemake/google_api/vcf_filtering.yaml"
	wxs_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/prefilter.snp_indel.vcf.gz"
	wgs_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.${passvalue}.merged.vcf"

	gcloud alpha genomics pipelines run --pipeline-file ${yaml} --inputs fafile=${ref},faifile=${ref}.fai,ref=${reffile},id=${id},passvalue=${passvalue},wxsvcf=${wxs_path},wgsvcf=${wgs_path} --outputs outputPath=gs://wliang/germline_snakemake/output/${passvalue}/ --logging gs://wliang/germline_snakemake/logging/compare/ --preemptible
done < $1
