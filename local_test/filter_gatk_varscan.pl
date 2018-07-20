#!/usr/bin/perl

### snv: union call from varscan and gatk
### indel: callings from pindel or both gatak and varscan

use strict;
use warnings;
die unless @ARGV == 2;

my ($run_dir,$sample_name)=@ARGV;

my $pindel_vcf=$run_dir."/".$sample_name."pindel.vcf"; 
my $gatk_vcf=$run_dir."/".$sample_name.".gatk.indel.vcf";
my $vars_vcf=$run_dir."/".$sample_name.".varscan.raw.indel.vcf";
my $gatk_vcf_filter=$run_dir."/".$sample_name.".gatk.indel.filtered.vcf";
my $vars_vcf_filter=$run_dir."/".$sample_name.".varscan.indel.filtered.vcf";

my $gatk_snv_vcf=$run_dir."/".$sample_name.".gatk.snp.vcf";
my $vars_snv_vcf=$run_dir."/".$sample_name.".varscan.raw.snp.vcf";
my $gatk_snv_vcf_filter=$run_dir."/".$sample_name.".gatk.snp.filtered.vcf";
my $vars_snv_vcf_filter=$run_dir."/".$sample_name.".varscan.snp.filtered.vcf";

my $vcf_cutoff=0.2; 
my $min_coverage=10; 
 
my %pindelvcf=();
my %gatkvcf=();
my %varsvcf=(); 
my %removegatk=();
my %removevars=();

open(INP,"<$pindel_vcf") or die "Can't open '$pindel_vcf': $!";
open(ING,"<$gatk_vcf") or die "Can't open '$gatk_vcf': $!"; 
open(INV,"<$vars_vcf") or die "Can't open '$vars_vcf': $!" ; 
open(OUTG,">$gatk_vcf_filter");
open(OUTV,">$vars_vcf_filter"); 
open(INSG,"<$gatk_snv_vcf") or die "Can't open '$gatk_snv_vcf': $!";
open(INSV,"<$vars_snv_vcf") or die "Can't open '$vars_snv_vcf': $!";
open(OUTSG,">$gatk_snv_vcf_filter"); 
open(OUTSV,">$vars_snv_vcf_filter");

while(<INP>)
  {
	my $line=$_; 
	chomp($line); 
	if($line=~/^#/) 
	{
		next; 
	}
	else { 
	my @temp=split("\t",$line); 
	my $id=$temp[0]."_".$temp[1];
	my $refvar=$temp[3]."_".$temp[4];
	#print "pindel","\t",$id,"\t",$refvar,"\n"; 
	#<STDIN>; 
	$pindelvcf{$id}=$refvar; 
	}

  }

while(<ING>)
  {

    my $line=$_;
    chomp($line);
    if($line=~/^#/)
    {
        next;
    }
    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1]; 
	my $refvar=$temp[3]."_".$temp[4];
	#print "gatk","\t",$id,"\t",$refvar,"\n";
	#<STDIN>;
    $gatkvcf{$id}=$refvar;
    }

  }

while(<INV>)
  {

    my $line=$_;
    chomp($line);
    if($line=~/^#/)
    {
        next;
    }
    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1];
	my $refvar=$temp[3]."_".$temp[4];
    $varsvcf{$id}=$refvar;
    }

  }

## remove inconsistence between pindel, gatk and varscan
 
foreach my $id (sort keys %gatkvcf) 
	{
		if(defined $pindelvcf{$id}) 
		{
			if($pindelvcf{$id} ne $gatkvcf{$id}) 
			{
			  $removegatk{$id}=1; 	
			  #print "removegatk 1","\t",$id,"\n";
			  #<STDIN>;
			}  	
		}
	
		if((!defined $varsvcf{$id}) || (defined $varsvcf{$id} && ($varsvcf{$id} ne $gatkvcf{$id})))
        {
              $removegatk{$id}=1;
			  #print "removegatk 2","\t",$id,"\n";
        }	

	}	 

foreach my $id (sort keys %varsvcf)
    {
        if(defined $pindelvcf{$id})
        {
            if($pindelvcf{$id} ne $varsvcf{$id})
            {
              $removevars{$id}=1;
			  #print "removevars 1","\t",$id,"\n";
            }
        }

        if((!defined $gatkvcf{$id}) || (defined $gatkvcf{$id} && ($varsvcf{$id} ne $gatkvcf{$id})))
        {
              $removevars{$id}=1;
			#print "removevars 2","\t",$id,"\n";
        }
    
    }

close(INP);
close(ING);
close(INV);
close(INSG);
close(INSV);

open(INP,"<$pindel_vcf");
open(ING,"<$gatk_vcf");
open(INV,"<$vars_vcf");
open(INSG,"<$gatk_snv_vcf");
open(INSV,"<$vars_snv_vcf");

while(<INV>)
  {

    my $line=$_;
	#print $line,"\n";
    chomp($line);
    if($line=~/^#/)
    {
        print OUTV $line,"\n";;
    }
    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1];
    my $refvar=$temp[3]."_".$temp[4];
    my $infor=$temp[9]; 
	my @temp2=split(":",$infor); 
	my $n_ref_fw=$temp2[-4];
	my $n_ref_rev=$temp2[-3];
	my $n_var_fw=$temp2[-2];
	my $n_var_rev=$temp2[-1];
	#print $n_ref_fw,"\n"; 
	#print $n_ref_rev,"\n";
	#print $n_var_fw,"\n";
	#print $n_var_rev,"\n";
	#print $$n_ref_fw,"\t",$n_ref_rev,"\t",$n_var_fw,"\t",$n_var_rev,"\n";

	#<STDIN>;

	## remove M allele ##
	if($refvar=~/M/) { next; }
	if($refvar=~/R/) { next; }

	### coverage and vaf cut-off ##
	
	if($n_ref_fw+$n_ref_rev+$n_var_fw+$n_var_rev>=$min_coverage && (($n_var_rev+$n_var_fw)/($n_ref_fw+$n_ref_rev+$n_var_fw+$n_var_rev)>$vcf_cutoff)) 
	{
		if(!defined $removevars{$id}) 
		{
			print OUTV $line,"\n"; 
		}
	}

    }

  }


while(<ING>)
  {

    my $line=$_;
    chomp($line);
    if($line=~/^#/)
    {
        print OUTG $line,"\n";;
    }

    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1];
    my $refvar=$temp[3]."_".$temp[4];
	my $afdf=$temp[7];
	my $desc=$temp[8];
    my $infor=$temp[9];
    my @temp2=split(":",$infor); 
	## remove M allel ##
  	if($refvar=~/M/) { next; }
	if($refvar=~/R/) { next; }

    if($desc=~/AD/) 
	{

	my @temp3=split(",",$temp2[1]); 	
	my $n_ref=$temp3[0]; 
	my $n_var=$temp3[1];
	#print $n_ref,"\t",$n_var,"\n";
	#<STDIN>; 
	if($n_ref+$n_var>=$min_coverage && ($n_var/($n_ref+$n_var)>$vcf_cutoff))
    {
        if(!defined $removegatk{$id})
        {
            print OUTG $line,"\n";
        }
    }

    }
    }
  }

#<STDIN>;
while(<INSV>)
  {

    my $line=$_;
    chomp($line);
    if($line=~/^#/)
    {
        print OUTSV $line,"\n";;
    }
    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1];
    my $refvar=$temp[3]."_".$temp[4];
    my $infor=$temp[9];
    my $n_ref_fw=(split(":",$infor))[-4];
    my $n_ref_rev=(split(":",$infor))[-3];
    my $n_var_fw=(split(":",$infor))[-2];
    my $n_var_rev=(split(":",$infor))[-1];    
    if($refvar=~/M/) { next; }
    if($refvar=~/R/) { next; }
	#print $line,"\n";
    #print $n_ref_fw,"\n"; 
    #print $n_ref_rev,"\n";
    #print $n_var_fw,"\n";
    #print $n_var_rev,"\n";
	#<STDIN>;
	if($n_ref_fw+$n_ref_rev+$n_var_fw+$n_var_rev>=$min_coverage && (($n_var_rev+$n_var_fw)/($n_ref_fw+$n_ref_rev+$n_var_fw+$n_var_rev)>$vcf_cutoff))
    {
         print OUTSV $line,"\n";
    }

    }

  }

while(<INSG>)
  {

    my $line=$_;
    chomp($line);

    if($line=~/^#/)
    {
        print OUTSG $line,"\n";;
    }

    else {
    my @temp=split("\t",$line);
    my $id=$temp[0]."_".$temp[1];
    my $refvar=$temp[3]."_".$temp[4];
    my $infor=$temp[9];
    my @temp2=split(":",$infor);
    my $desc=$temp[8];

	## remove M allele ##
  	if($refvar=~/M/) { next; }
	if($refvar=~/R/) { next; }

	if($desc=~/AD/) 
	{
    my @temp3=split(",",$temp2[1]);
    my $n_ref=$temp3[0];
    my $n_var=$temp3[1];
    if($n_ref+$n_var>=$min_coverage && ($n_var/($n_ref+$n_var)>$vcf_cutoff))
    {
            print OUTSG $line,"\n";
    }
    }
}
  }

close(INP);
close(ING);
close(INV);
close(INSG);
close(INSV); 
close(OUTG); 
close(OUTV); 
close(OUTSG); 
close(OUTSV); 


