#!/bin/python
#05 Jan 2019 - Wen-Wei Liang @ WashU -

import sys
import getopt
import gzip

class autovivification(dict):
    '''Implementation of perl's autovivification feature.'''
    def __init__( self , *args , **kwargs ):
        super( autovivification , self ).__init__( *args , **kwargs )
        self.itemlist = super( autovivification , self ).keys()
    def __getitem__(self, item):
        try:
            return dict.__getitem__(self, item)
        except KeyError:
            value = self[item] = type(self)()
            return value

def main():
    def usage():
        print """
    pick_caller.py : why do I exist?

    USAGE: pick_caller.py  [-h] <VCF filename>
     -h    print this message
     <VCF filename>    input file
        """

    if len(sys.argv) == 2:
        vcfFH= sys.argv[1]
    else:
        usage()
        sys.exit()

    try:
        vcfF = gzip.open(vcfFH,"r")
    except IOError:
        print("VCF file does not exist!")  


    for line in vcfF:
        line=line.strip()
        # print the info lines
        if line.startswith("##"):
            print line
        elif line.startswith("#CHROM"):
            F = line.split("\t")
            F = F[:9]+F[10:]
            print ('\t'.join(map(str,F)))
        else:
            F = line.split("\t")

            ref = str(F[3])
            info_f = str(F[7]).split(";")
            format_f = str(F[8]).split(":")
            sample1_f = str(F[9]).split(":")
            barcode_f = str(F[10]).split(":")

            ### Choose between sample1_f and barcode_f
            ## Check genotype
            if sample1_f[0]!= "./." and barcode_f[0]!= "./.":
                count_sample1 = sample1_f.count(".")
                count_barcode = barcode_f.count(".")
                if count_sample1 > count_barcode:
                    F = F[:9]+F[10:]
                    print ("\t".join(map(str,F)))
                elif count_sample1 <= count_barcode:
                    F = F[:10]
                    print ("\t".join(map(str,F)))
                else:
                    print("Check")
            elif barcode_f[0]=="./.":
                F = F[:10]
                print("\t".join(map(str,F)))
            elif sample1_f[0]=="./.":
                F = F[:9]+F[10:]
                print("\t".join(map(str,F)))
            else:
                print("Check", "\t".join(map(str,F)))


if __name__ == "__main__":
    main()
