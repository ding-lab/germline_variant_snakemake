####
#Aim: Generate google cloud command
#Usage: bash generate_command.sh ${List_of_BAMs} ${JobName} ${DiskSize(in gb)}
#1. bash generate_command.gatk.sh TCGA_WGS_gspath_WWL_Mar2018.HighPass.txt HighPass 
#2. bash generate_command.gatk.sh TCGA_WGS_gspath_WWL_Mar2018.LowPass.txt LowPass
#Author: Wen-Wen Liang @ Wash U (liang.w@wustl.edu)
####


echo "#" > ~/gcloud_command.$2.merge.sh
while read lines; do
	id=$(echo $lines | awk -F " " '{print $3}')
	passvalue=$2
	size="50"
	ref=$(echo $lines | awk -F " " '{if ($8=="HG19_Broad_variant") print "gs://ding_lab_reference/Homo_sapiens_assembly19.fasta"; else print "gs://ding_lab_reference/GRCh37-lite.fa"}')
	reffile=$(echo $lines | awk -F " " '{if ($8=="HG19_Broad_variant") print "Homo_sapiens_assembly19.fasta"; else print "GRCh37-lite.fa"}')
	yaml="~/germline_variant_snakemake/google_api/merge_germline.yaml"
	dict=$(echo $ref | awk -F "." '{print $1}')
	gatk_snp_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.gatk.snp.filtered.vcf"
	gatk_indel_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.gatk.indel.filtered.vcf"
	varscan_snp_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.varscan.snp.filtered.vcf"
	varscan_indel_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.varscan.indel.filtered.vcf"
	pindel_path="gs://wliang/germline_snakemake/output/${passvalue}/${id}/${id}.pindel.vcf"

	echo "gcloud alpha genomics pipelines run --pipeline-file ${yaml} --inputs fafile=${ref},faifile=${ref}.fai,dictfile=${dict}.dict,id=${id},passvalue=${passvalue},ref=${reffile},gsnp=${gatk_snp_path},gindel=${gatk_indel_path},vsnp=${varscan_snp_path},vindel=${varscan_indel_path},pindel=${pindel_path} --outputs outputPath=gs://wliang/germline_snakemake/output/${passvalue}/${id}/ --logging gs://wliang/germline_snakemake/logging/${passvalue}/merge/ --disk-size datadisk:${size} --preemptible" >> ~/gcloud_command.$2.merge.sh
done < $1
