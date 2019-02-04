#!/bin/usr/python
import sys
import os

check_dict={}
with open(sys.argv[1]) as f1:
	for line in f1:
		data=line.strip().split("\t")
		maf_line="\t".join([data[x] for x in range (0, len(data))])
		if data[0] != "#version 2.4":
			if data[0] != "Hugo_Symbol":
				chromosome=data[4]
				start=data[5]
				stop=data[6]
				ref_allele=data[10]
				tumor_allele_1=data[11]
				tumor_allele_2=data[12]
				tumor_barcode=data[15]
				normal_barcode=data[16]
				key=chromosome+"_"+start+"_"+stop+"_"+ref_allele+"_"+tumor_allele_1+"_"+tumor_allele_2+"_"+tumor_barcode+"_"+normal_barcode
				if key in check_dict:
					pass
				else:
					print maf_line
					check_dict.update({key:1})
			else:
				print maf_line
		else: 
			print maf_line

