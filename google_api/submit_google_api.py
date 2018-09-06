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
    cmd = "gcloud alpha genomics pipelines run --pipeline-file ~/germline_variant_snakemake/google_api/germline_snakemake.yaml --project washu-medicine-pancan --preemptible --inputs fafile="
    bucket = "gs://wliang/germline_snakemake/"

    # Read manifest and generate requried fileds
    df = pd.read_table(path_to_manifest, names=header)
    df["size"] = df["file_size"].apply(lambda x: x*2/1000000000 if x*2/1000000000 > 50 else "50") # Convert the file size from byte to GB

    # Get the gspath of reference files
    df["gspath_to_ref"] = df["reference"].apply(lambda x: "gs://ding_lab_reference/Homo_sapiens_assembly19.fasta" if x=="HG19_Broad_variant" else ( "gs://ding_lab_reference/GRCh37-lite.fa" if x=="GRCh37" else "Not_Determined"))
    df["dict"] = df["gspath_to_ref"].str.split(".").str[0]+".dict"

    # Assign bucket
    df["log"] = bucket+"logging/"+df["pass"]+"/"+df["case_full_barcode"]
    df["output"] = bucket+"output/"+df["pass"]+"/"+df["case_full_barcode"]

    # Get the full commend
    df["cmd"] = cmd+df["gspath_to_ref"]+",faifile="+df["gspath_to_ref"]+".fai,dictfile="+df["dict"]+",bamfile="+df["gspath_to_bam"]+",baifile="+df["gspath_to_bai"]+",sample="+df["case_full_barcode"]+",passvalue="+df["pass"]+" --logging "+df["log"]+" --outputs outputPath="+df["output"]

    # build table
    d = df[["case_full_barcode","cmd"]]
    d["status"] = "Pending"
    d["operation_id"] = "Not_Assigend"
    d["num_of_repeats"] = 0

    return d


# Launch VM and get operation id from stderr
def get_operation_id(row):
    cmd = row["cmd"]
    case = row["case_full_barcode"]
    print("Launching "+cmd)
    operation_id = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, universal_newlines=True).splitlines()[0].split("/")[1].strip("].")
    print("Operation ID for "+case+" is "+operation_id)
    return operation_id

# Take https://github.com/googlegenomics/pipelines-api-examples/tree/master/tools for reference
# Return status: Done and Fail
def check_status(row):
    operation_id = row["operation_id"]
    case = row["case_full_barcode"]
    print("check "+case+" : "+operation_id+"...")
    cmd = "gcloud alpha genomics operations describe "+operation_id+" --format='value(done)'" 
    cmd2 = "gcloud alpha genomics operations describe "+operation_id+" --format='value(error)'"
    status = subprocess.check_output(cmd, shell=True, universal_newlines=True).splitlines()[0]
    if status == "False":
        print("case "+case+" : "+operation_id+" is running.")
        return "Running"
    else:
        print("case "+case+" : "+operation_id+" is complete. Check if the task is successful...")
        done = subprocess.check_output(cmd2, shell=True, universal_newlines=True).splitlines()[0]
        msg = subprocess.check_output(cmd2, shell=True, universal_newlines=True).splitlines()
        if done:
            print("case "+case+" : "+operation_id+" is failed")
            print(msg)
            return "Fail"
        else:
            print("case "+case+" : "+operation_id+" is successfully done")
            return "Done"

#print(build_table(sys.argv[1])["cmd"][0])

## Create the default table based on sys.argv[1]
RESULT_TSV = build_table(sys.argv[1])
RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)

## Generate an undone_list based on the status and number of tries.
UNDONE_LIST = RESULT_TSV[(RESULT_TSV["status"]!="Done") & (RESULT_TSV["num_of_repeats"]<=15)]["case_full_barcode"].tolist()
print("There are "+str(len(UNDONE_LIST))+" samples to work on.")

## If there are undone tasks
while len(UNDONE_LIST) !=0:
    ## Generate a smaller tsv for task to run
    ## Wait for user to manage the length of working list. If timeout, then 30 VMs.
    ## Select the first x samples from undone_list
    print('Please press Cltr-C when you wish to change the number of running VM')
    try:
        for i in range(0, 10):
            time.sleep(1)
        print('Waiting for 10 seconds. 30 VMs will keep running this time.')
        WORKING_LIST = UNDONE_LIST[:30]
    except KeyboardInterrupt:
        num=input("How many jobs you want to run this time? ")
        print(num + " VMs will keep running this time.")
        num=int(num)
        WORKING_LIST = UNDONE_LIST[:num]
    ## Group samples based on status. Check if the stauts == running.
    WORKING_TSV = RESULT_TSV[(RESULT_TSV["case_full_barcode"].isin(WORKING_LIST)) & (RESULT_TSV["status"] != "Running")]
    CHECKING_TSV = RESULT_TSV[(RESULT_TSV["case_full_barcode"].isin(WORKING_LIST)) & (RESULT_TSV["status"] == "Running")]
    if len(WORKING_TSV)>0:
        ## Luanch VM and get operation ID
        WORKING_TSV["operation_id"] = WORKING_TSV.apply(get_operation_id, axis=1)
        WORKING_TSV["status"] = "Running"
        WORKING_TSV["num_of_repeats"] += 1
        RESULT_TSV.update(WORKING_TSV)
    if len(CHECKING_TSV)>0:
        ## Check the status until task is complete
        CHECKING_TSV["status"] = CHECKING_TSV.apply(check_status, axis=1)
        ## Update the result table
        RESULT_TSV.update(CHECKING_TSV)
    RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)
    ## Generate a new undone_list based on the status 
    UNDONE_LIST = RESULT_TSV[(RESULT_TSV["status"]!="Done") & (RESULT_TSV["num_of_repeats"]<=15)]["case_full_barcode"].tolist()
    print("There are "+str(len(UNDONE_LIST))+" samples to work on.")
    ## Wait for 300 second and check the status againg
    time.sleep(300)
else:
    RESULT_TSV.to_csv("result.tsv", sep="\t", index=False)
