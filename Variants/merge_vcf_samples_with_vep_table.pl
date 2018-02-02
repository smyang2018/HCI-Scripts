#!/usr/bin/perl

# Timothy J. Parnell, PhD
# Huntsman Cancer Institute
# University of Utah
# Salt Lake City, UT 84112
#  
# This package is free software; you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0.  
# 
# Updated versions of this file may be found in the repository
# https://github.com/tjparnell/HCI-Scripts/

use strict;
use Getopt::Long;
use Bio::ToolBox::Data '1.40';
use Bio::ToolBox::utility;

my $VERSION = 1.4;

unless (@ARGV) {
	print <<END;

A script to merge the sample columns from a VCF file into an Ensembl 
VEP output annotation table. VEP does not preserve sample information. 
This script remedies this problem. Only specific sample tags are 
included, on the assumption that not all are required.

If no sample columns are present in the VCF file, then the tags are 
taken from the INFO column instead.

The sample information is put in behind the first ID column.

Usage: $0 --vcf <input.vcf> --in <input.annot.txt>
Options: 
  --vcf <input.vcf>     Define the original VCF file with the sample 
                        information. Requires one or more sample columns.
  --input <input.txt>   Define the VEP annotation table to be modified.
  --output <output.txt> Define the output table. The default behavior is 
                        to overwrite input file.
  --tags <GT,AD>        Provide a comma delimited list of attribute tags 
                        from the sample column to include in the output.
                        If not defined, then the default is GT:AD.
  --samples <index>     Provide the 0-based index(es) of the sample columns 
                        from which to collect the tag information. Provide 
                        a comma-delimited list, range, or specify the option 
                        multiple times. The INFO field is column 7, and 
                        sample columns begin at column 9. The default is 
                        to take all samples present in the VCF file.
  --samples ask         Indicate that the sample columns should be interactively 
                        chosen from a list of available columns in the VCF.
  --ref                 Include the reference allele if desired 
END
	exit;
}

my $vcffile;
my $infile;
my $outfile;
my $tagList = 'GT,AD';
my $do_ref;
my @samples;

GetOptions( 
	'input=s'   => \$infile, # input table
	'vcf=s'     => \$vcffile, # input vcf
	'output=s'  => \$outfile, # output vcf
	'tags=s'    => \$tagList, # list of attribute tags
	'samples=s' => \@samples, # list of samples to collect from
	'ref!'      => \$do_ref, # include the reference
) or die "bad options!\n";

my @tags = split /,/, $tagList;


### Load sample information
print " Loading sample information from $vcffile...\n";
my $vcfData = Bio::ToolBox::Data->new(
	stream   => 1,
	file     => $vcffile,
) or die "unable to load $vcffile!\n";
die "$vcffile is not a VCF file!\n" unless $vcfData->vcf;


# get the samples
if (@samples) {
	if (scalar(@samples) == 1 and $samples[0] =~ /[,\-]/) {
		@samples = parse_list(shift @samples);
	}
	elsif ($samples[0] eq 'ask') {
		shift @samples;
		@samples = ask_user_for_index($vcfData, " Enter the desired sample columns:  ");
	}
} 
else {
	if ($vcfData->last_column >= 9) {
		@samples = (9 .. $vcfData->last_column);
	}
	else {
		print " no samples found in vcf file! Using INFO field instead\n";
		push @samples, 7;
	}
}
my @sampleNames = map {$vcfData->name($_)} @samples;
my %sampleInfo;
my %sampleRef;
$vcfData->iterate(\&store_sample_data);
	# vep does screwy things with the start position and alternate allele 
	# and does not take what the VCF simply provides
	# therefore, we have to mimic VEP and screw with these values
	
	# we offload this to a separate subroutine so that we can iteratively 
	# handle multiple alternate alleles
$vcfData->close_fh;



### Load and process table
print " Adding sample information...\n";
my $Data = Bio::ToolBox::Data->new(file => $infile) or 
	die "unable to load $infile!";

# add new columns
my $last = $Data->last_column;
my @new_i; # new column indices to be used later
foreach (@sampleNames) {
	push @new_i, $Data->add_column($_);
}
my $ref_i;
if ($do_ref) {
	$ref_i = $Data->add_column('Reference');
}

# find columns
my $loc_i = $Data->find_column('Location');
my $alt_i = $Data->find_column('Allele');
die "can't find the Location column!\n" unless defined $loc_i;
die "can't find the Allele column!\n" unless defined $alt_i;

# add the sample information
my $noFind = 0;
$Data->iterate( \&table_iterator );

# check for errors
if ($noFind) {
	print " $noFind rows did not have a corresponding samples in the VCF files\n";
}



### Finish up

# reorder the columns
push @new_i, $ref_i if $do_ref;
$Data->reorder_column(0, @new_i, 1 .. $last);

# add sample information comments
$Data->add_comment(sprintf "Sample Information tags = %s", join(':', @tags));

# save the file
my $saved;
if ($outfile) {
	$saved = $Data->save($outfile);
}
else {
	$saved = $Data->save;
}
print " wrote file $saved\n";




### subroutines

sub store_sample_data {
	my $row = shift;
	
	# check the reference and alternate alleles
	my $ref = $row->value(3);
	my $alt = $row->value(4);
	if ($alt =~ /,/) {
		# we have two alternate alleles at the same point
		# we have to process these separately one at a time
		my @alleles = split ',', $alt;
		foreach my $a (@alleles) {
			# call ourself for each allele
			$row->value(4, $a); # set the allele to each alternate
			store_sample_data($row);
		}
		return;
	}
	
	# set the allele and start appropriately based on variant type
	my $attrib = $row->attributes;
	my ($allele, $allele2, $start);
		# VEP bugs where 2 different alleles could be recorded, so deal with it
	if (exists $attrib->{INFO}{SVTYPE} and 
		$attrib->{INFO}{SVTYPE} !~ /snp/i
	) {
		# I think VEP defaults to using the SVTYPE INFO field?
		if ($attrib->{INFO}{SVTYPE} eq 'DEL') {
			$allele = 'deletion';
			$allele2 = '-';
			$start = $row->start + 1;
		}
		elsif ($attrib->{INFO}{SVTYPE} eq 'INS') {
			$allele = 'insertion';
			$allele2 = '-';
			$start = $row->start;
		}
		elsif ($attrib->{INFO}{SVTYPE} =~ /^DUP/) {
			$allele = 'duplication';
			$allele2 = '-';
			$start = $row->start + 1;
		}
		else {
			$allele = $attrib->{INFO}{SVTYPE};
			$allele2 = '-';
			$start = $row->start + 1;
		}
	}
	elsif (length($ref) > 1 and length($alt) > 1) {
		# sequence alteration, probably multinucleotide that don't fit in the 
		# other categories
		$allele = substr($alt, 1);
		$start = $row->start + 1;
	}
	elsif (length($ref) < length($alt) ) {
	 	# insertion
		$allele = substr($alt, 1);
		$start = $row->start;
	}
	elsif (length($ref) > length($alt) ) {
	 	# deletion
	 	$allele = '-';
		$start = $row->start + 1;
	}
	else {
		# snv
		$allele = $alt;
		$start = $row->start;
	}
	
	
	# chromosome
	my $chr = $row->seq_id;
	$chr =~ s/^chr//; # Ensembl doesn't like chr prefix
	
	# collect the sample attribute tags
	my @values;
	foreach my $i (@samples) {
		push @values, join(':', map { $attrib->{$i}{$_} || '.' } @tags);
	}
	
	# generate id and store data under it
	my $id = sprintf "%s_%d_%s", $chr, $start, $allele;
	$sampleInfo{$id} = \@values; 
	$sampleRef{$id} = $ref if $do_ref;
	if ($allele2) {
		$id = sprintf "%s_%d_%s", $chr, $start, $allele2;
		$sampleInfo{$id} = \@values; 
		$sampleRef{$id} = $ref if $do_ref;
	}
}


sub table_iterator {
	my $row = shift;
	# generate id for sample lookup
	my ($chr, $start) = split ':', $row->value($loc_i), 2;
	my $alt = $row->value($alt_i);
	if ($start =~ /^(\d+)\-\d+$/) {
		# the location is a range, take the first value I hope
		$start = $1;
	}
	my $id = sprintf "%s_%d_%s", $chr, $start, $alt;
	
	unless (exists $sampleInfo{$id}) {
		# this is a problem, not in the original vcf file!?
		# more likely programmatic error due to complex alleles
		foreach (@new_i) {$row->value($_, '-')}
		printf "cannot find id $id for %s %s\n", $row->value($loc_i), $row->value($alt_i);
		$noFind++;
		next;
	}
	
	# store the information
	for my $i (0 .. $#new_i) {
		$row->value( $new_i[$i], $sampleInfo{$id}->[$i] );
	}
	$row->value($ref_i, $sampleRef{$id}) if $do_ref;
}


