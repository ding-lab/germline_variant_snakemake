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
import time

header = ["case", "case_16_barcode", "case_full_barcode", "sample_type_num", "sample_type", "exp_type", "platform", "reference", "file_name", "file_size", "project", "uuid1", "uuid2", "gspath_to_bam", "gspath_to_bai", "center", "cancer_type", "pass", "case_15_barcode", "tn", "wxs_barcode", "wxs_uuid", "gspath_to_wxs_vcf", "gspath_to_wxs_bam", "wgs_coverage"]

# Read sample manifest and create a table
def build_table(path_to_manifest):
    passvalue = str(path_to_manifest).split(".")[1]
    cmd = "gcloud alpha genomics pipelines run --pipeline-file ~/germline_variant_snakemake/google_api/germline_snakemake.yaml --project washu-medicine-pancan --preemptible --inputs fafile="
    bucket = "gs://wliang/germline_snakemake/"

    # Read manifest and generate requried fileds
    df = pd.read_table(path_to_manifest, names=header)
    df["size"] = df["file_size"].apply(lambda x: x*2/1000000000 if x*2/1000000000 > 50 else "50") # Convert the file size from byte to GB

    # Get the gspath of reference files
    df["gspath_to_ref"] = df["reference"].apply(lambda x: "gs://dinglab/reference/Homo_sapiens_assembly19.fasta" if x=="HG19_Broad_variant" else "gs://dinglab/reference/GRCh37-lite.fa")
    df["dict"] = df["gspath_to_ref"].str.split(".").str[0]+".dict"

    # Assign bucket
    df["log"] = bucket+"logging/"+passvalue+"/"+df["case_full_barcode"]
    df["output"] = bucket+"output/"+passvalue+"/"+df["case_full_barcode"]

    # Get the full commend
    df["cmd"] = cmd+df["gspath_to_ref"]+",faifile="+df["gspath_to_ref"]+".fai,dictfile="+df["dict"]+",bamfile="+df["gspath_to_bam"]+",baifile="+df["gspath_to_bai"]+",sample="+df["case_full_barcode"]+" --logging "+df["log"]+" --outputs outputPath="+df["output"]

    # build table
    d = df[["case_full_barcode","cmd"]]
    d["status"] = "Pending"
    d["operation_id"] = "Not_Assigend"
    d["num_of_repeats"] = 0

    return d


# Launch VM and get operation id from stderr
def get_operation_id(row):
    cmd = row["cmd"]
    print("Launching "+cmd)
    operation_id = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, universal_newlines=True).splitlines()[0].split("/")[1].strip("].")
    print("Operation ID for this launching VM is "+operation_id)
    return operation_id

# Take https://github.com/googlegenomics/pipelines-api-examples/tree/master/tools for reference
# Return status: Done and Fail
def check_status(row):
    operation_id = row["operation_id"]
    print("check "+operation_id+"...")
    cmd = "gcloud alpha genomics operations describe "+operation_id+" --format='value(done)'" 
    cmd2 = "gcloud alpha genomics operations describe "+operation_id+" --format='value(error)'"
    status = subprocess.check_output(cmd, shell=True, universal_newlines=True).splitlines()[0]
    while status == "False":
        print(operation_id+" is not complete. Will check after 300 seconds")
        time.sleep(300)
        status = subprocess.check_output(cmd, shell=True, universal_newlines=True).splitlines()[0]
    else:
        print(operation_id+" is complete. Check if the task is successful...")
        done = subprocess.check_output(cmd2, shell=True, universal_newlines=True).splitlines()[0]
        if done == "-":
            print(operation_id+" is successfully done")
            return "Done"
        else:
            print(operation_id+" is failed")
            return "Fail"




RESULT_TSV = build_table(sys.argv[1])
RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)
UNDONE_LIST = RESULT_TSV[RESULT_TSV["status"]!="Done"]["case_full_barcode"].tolist()


while len(UNDONE_LIST) !=0:
    ## Generate a smaller tsv for task to run
    WORKING_LIST = UNDONE_LIST[:25]
    WORKING_TSV = RESULT_TSV[RESULT_TSV["case_full_barcode"].isin(WORKING_LIST)]
    ## Luanch VM and get operation ID
    WORKING_TSV["operation_id"] = WORKING_TSV.apply(get_operation_id, axis=1)
    WORKING_TSV["status"] = "Running"
    ## Check the status until task is complete
    WORKING_TSV["status"] = WORKING_TSV.apply(check_status, axis=1)
    ## Update the result table
    RESULT_TSV.update(WORKING_TSV)
    RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)
    ## Generate a new undone_list based on the status 
    UNDONE_LIST = RESULT_TSV[RESULT_TSV["status"]!="Done"]["case_full_barcode"].tolist()
else:
    RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)
