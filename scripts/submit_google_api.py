#!/usr/bin/env python3
###
#Aim: Check the status of VM jobs and keep launching jobs if the running vm is less than 25.
#Author: Wen-Wei Liang @ Wash U (liang.w@wustl.edu)
#Usuage: python submit_google_api.py {path_to_sample_manifest} 
###

import os
import sys
import pandas as pd
import subprocess

# Read sample manifest and create dictionary of {sample:google_pipeline_api_commend}
def cmd_from_manifest(path_to_manifest):
    passvalue = str(path_to_manifest).split(".")[1]
    cmd = "gcloud alpha genomics pipelines run --pipeline-file ~/germline_variant_snakemake/google_api/germline_snakemake.yaml --project washu-medicine-pancan --preemptible --inputs fafile="
    bucket = "gs://wliang/germline_snakemake/"

    # Read manifest and generate requried fileds
    header = ["case", "case_16_barcode", "case_full_barcode", "sample_type_num", "sample_type", "exp_type", "platform", "reference", "file_name", "file_size", "project", "uuid1", "uuid2", "gspath_to_bam", "gspath_to_bai", "center", "cancer_type", "pass", "case_15_barcode", "tn", "wxs_barcode", "wxs_uuid", "gspath_to_wxs_vcf", "gspath_to_wxs_bam", "wgs_coverage"]
    df = pd.read_table(path_to_manifest, names=header)
    df["size"] = df["file_size"].apply(lambda x: x*2/1000000000 if x*2/1000000000 > 50 else "50") # Convert the file size from byte to GB

    # Get the gspath of reference files
    df["gspath_to_ref"] = df["reference"].apply(lambda x: "gs://dinglab/reference/Homo_sapiens_assembly19.fasta" if x=="HG19_Broad_variant" else "gs://dinglab/reference/GRCh37-lite.fa")
    df["dict"] = df["gspath_to_ref"].str.split(".").str[0]+".dict"

    # Assign bucket
    df["log"] = bucket+"logging/"+passvalue+"/"+df["case_full_barcode"]
    df["output"] = bucket+"output/"+passvalue+"/"+df["case_full_barcode"]

    # Get the full commend
    df["cmd_input"] = cmd+df["gspath_to_ref"]+",faifile="+df["gspath_to_ref"]+".fai,dictfile="+df["dict"]+",bamfile="+df["gspath_to_bam"]+",baifile="+df["gspath_to_bai"]+",sample="+df["case_full_barcode"]+" --logging "+df["log"]+" --outputs outputPath="+df["output"]

    #Generate dict
    d = df[["case_full_barcode","cmd_input"]].drop_duplicates().set_index("case_full_barcode")["cmd_input"].to_dict()
    return d


# Launch VM and get operation id from stderr
def get_operation_id(cmd):
    output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, universal_newlines=True).splitlines()[0].split("/")[1].strip("].")
    return output

# Take https://github.com/googlegenomics/pipelines-api-examples/tree/master/tools for reference
# Return status: Done and Fail
def check_status(operation_id, sec):
    cmd = "gcloud alpha genomics operations describe "+operation_id+" --format='value(done)'" 
    status = subprocess.check_output(cmd, shell=True, universal_newlines=True).splitlines()[0]
    if status == "False":
        time.sleep(sec)
        status = subprocess.check_output(cmd, shell=True, universal_newlines=True).splitlines()[0]
    else:
        return status


# Define again() function to ask user if they want to use the calculator again
def again():

    # Take input from user
    calc_again = input('''
Do you want to calculate again?
Please type Y for YES or N for NO.
''')

    # If user types Y, run the calculate() function
    if calc_again == 'Y':
        calculate()

    # If user types N, say good-bye to the user and end the program
    elif calc_again == 'N':
        print('See you later.')

    # If user types another key, run the function again
    else:
        again()


CMD_DICT = cmd_from_manifest(sys.argv[1])
print (CMD_DICT)

##gcloud alpha genomics operations describe EO_koavTLBiyiuPkg5itowsggsbm6-geKg9wcm9kdWN0aW9uUXVldWU --format='value(done)'
