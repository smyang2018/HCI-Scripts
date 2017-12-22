#!/usr/bin/env perl

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
use Bio::ToolBox::Data '1.41';
my $VERSION = 1;

unless (scalar @ARGV) {
	print <<END;

A script to convert other style hg38 chromosome identifiers to Ensembl identifiers.
This uses built-in synonyms for UCSC, NCBI, and others.

Usage:
 $0 <infile> <outfile>

It will handle BED, GFF, GTF, refFlat, genePred, and VCF files.

It will report any unmatched chromosomes that couldn't be converted. 
These are skipped in the output file.

END
	exit;
}

my $infile = shift @ARGV;
my $outfile = shift @ARGV || undef;
my $lookup = make_lookup_table();

if ($infile =~ /\.fa(?:sta)?(?:\.gz)?$/i) {
	# input is a fasta file
	die "can't do fasta files!!!"
}
else {
	# otherwise assume some sort of gene table
	process_table();
}

sub make_lookup_table {
	my %lookup;
	while (my $line = <DATA>) {
		chomp $line;
		my ($chr, $alt) = split('\t', $line);
		$lookup{$alt} = $chr;
	}
	return \%lookup;
}

sub process_table {
	my $Stream = Bio::ToolBox::Data->new(
		stream => 1,
		in     => $infile,
	) or die " unable to open input table $infile! $!\n";
	# we check the chromosome column below
	
	# make output
	unless ($outfile) {
		$outfile = $Stream->path . $Stream->basename . '.ensembl' . $Stream->extension;
	}
	my $Out = $Stream->duplicate($outfile) or 
		die " unable to open output stream for file $outfile! $!\n";
	
	# deal with metadata
	my @comments = $Stream->comments;
	if (@comments) {
		for (my $i =$#comments; $i >= 0; $i--) {
			# delete the existing comments, these are indexed so go in reverse
			# order, we'll add back fixed ones
			$Out->delete_comment($i); 
		}
		foreach my $c (@comments) {
			if ($c =~ /^##sequence\-region\s+([\w\.]+)\s/) {
				# gff3 sequence pragmas
				my $chr = $1;
				if (exists $lookup->{$chr}) {
					my $alt = $lookup->{$chr};
					$c =~ s/$chr/$alt/;
				}
			}
			elsif ($c =~ /^##contig=<ID=([\w\.]+)/) {
				# vcf sequence identifiers
				my $chr = $1;
				if (exists $lookup->{$chr}) {
					my $alt = $lookup->{$chr};
					$c =~ s/$chr/$alt/;
				}
			}
			$Out->add_comment($c);
		}
		
	}
	
	# data replacements
	my $seq_i = $Stream->chromo_column;
	die "can't find chromosome column!\n" unless defined $seq_i;
	my %notfound;
	while (my $row = $Stream->next_row) {
		my $chr = $row->value($seq_i);
		if (exists $lookup->{$chr}) {
			$row->value($seq_i, $lookup->{$chr});
			$Out->write_row($row);
		}
		else {
			$notfound{$chr}++;
		}
	}
	$Out->close_fh;
	$Stream->close_fh;
	if (%notfound) { 
		printf "could not convert the following chromosomes:\n%s\n", 
			join("\n", map {sprintf(" %-25s%d lines", $_, $notfound{$_})} keys %notfound);
	}
	printf "wrote %s\n", $Out->filename;
}


# these synonyms are borrowed from Ensembl VEP, release 87
__DATA__
KI270757.1	chrUn_KI270757v1
KI270757.1	NT_187512.1
KI270741.1	chrUn_KI270741v1
KI270741.1	NT_187497.1
KI270756.1	chrUn_KI270756v1
KI270756.1	NT_187511.1
KI270730.1	chr17_KI270730v1_random
KI270730.1	NT_187385.1
KI270739.1	chr22_KI270739v1_random
KI270739.1	NT_187394.1
KI270738.1	chr22_KI270738v1_random
KI270738.1	NT_187393.1
KI270737.1	chr22_KI270737v1_random
KI270737.1	NT_187392.1
KI270312.1	chrUn_KI270312v1
KI270312.1	NT_187405.1
KI270591.1	chrUn_KI270591v1
KI270591.1	NT_187457.1
KI270371.1	chrUn_KI270371v1
KI270371.1	NT_187494.1
KI270385.1	chrUn_KI270385v1
KI270385.1	NT_187487.1
KI270381.1	chrUn_KI270381v1
KI270381.1	NT_187486.1
KI270517.1	chrUn_KI270517v1
KI270517.1	NT_187438.1
KI270508.1	chrUn_KI270508v1
KI270508.1	NT_187430.1
KI270539.1	chrUn_KI270539v1
KI270539.1	NT_187442.1
KI270593.1	chrUn_KI270593v1
KI270593.1	NT_187456.1
KI270530.1	chrUn_KI270530v1
KI270530.1	NT_187441.1
KI270588.1	chrUn_KI270588v1
KI270588.1	NT_187455.1
KI270392.1	chrUn_KI270392v1
KI270392.1	NT_187485.1
KI270375.1	chrUn_KI270375v1
KI270375.1	NT_187493.1
KI270329.1	chrUn_KI270329v1
KI270329.1	NT_187459.1
KI270336.1	chrUn_KI270336v1
KI270336.1	NT_187465.1
KI270507.1	chrUn_KI270507v1
KI270507.1	NT_187437.1
KI270423.1	chrUn_KI270423v1
KI270423.1	NT_187417.1
KI270382.1	chrUn_KI270382v1
KI270382.1	NT_187488.1
KI270383.1	chrUn_KI270383v1
KI270383.1	NT_187482.1
KI270468.1	chrUn_KI270468v1
KI270468.1	NT_187426.1
KI270379.1	chrUn_KI270379v1
KI270379.1	NT_187472.1
KI270515.1	chrUn_KI270515v1
KI270515.1	NT_187436.1
KI270582.1	chrUn_KI270582v1
KI270582.1	NT_187454.1
KI270316.1	chrUn_KI270316v1
KI270316.1	NT_187403.1
KI270511.1	chrUn_KI270511v1
KI270511.1	NT_187435.1
KI270466.1	chrUn_KI270466v1
KI270466.1	NT_187421.1
KI270518.1	chrUn_KI270518v1
KI270518.1	NT_187429.1
KI270580.1	chrUn_KI270580v1
KI270580.1	NT_187448.1
KI270340.1	chrUn_KI270340v1
KI270340.1	NT_187464.1
KI270422.1	chrUn_KI270422v1
KI270422.1	NT_187416.1
KI270584.1	chrUn_KI270584v1
KI270584.1	NT_187453.1
KI270528.1	chrUn_KI270528v1
KI270528.1	NT_187440.1
KI270330.1	chrUn_KI270330v1
KI270330.1	NT_187458.1
KI270509.1	chrUn_KI270509v1
KI270509.1	NT_187428.1
KI270587.1	chrUn_KI270587v1
KI270587.1	NT_187447.1
KI270394.1	chrUn_KI270394v1
KI270394.1	NT_187479.1
KI270335.1	chrUn_KI270335v1
KI270335.1	NT_187462.1
KI270372.1	chrUn_KI270372v1
KI270372.1	NT_187491.1
KI270388.1	chrUn_KI270388v1
KI270388.1	NT_187478.1
KI270310.1	chrUn_KI270310v1
KI270310.1	NT_187402.1
KI270522.1	chrUn_KI270522v1
KI270522.1	NT_187434.1
KI270366.1	chrUn_KI270366v1
KI270366.1	NT_187470.1
KI270334.1	chrUn_KI270334v1
KI270334.1	NT_187460.1
KI270412.1	chrUn_KI270412v1
KI270412.1	NT_187408.1
KI270302.1	chrUn_KI270302v1
KI270302.1	NT_187396.1
KI270581.1	chrUn_KI270581v1
KI270581.1	NT_187449.1
KI270424.1	chrUn_KI270424v1
KI270424.1	NT_187414.1
KI270548.1	chrUn_KI270548v1
KI270548.1	NT_187445.1
KI270396.1	chrUn_KI270396v1
KI270396.1	NT_187477.1
KI270374.1	chrUn_KI270374v1
KI270374.1	NT_187490.1
KI270395.1	chrUn_KI270395v1
KI270395.1	NT_187476.1
KI270387.1	chrUn_KI270387v1
KI270387.1	NT_187475.1
KI270418.1	chrUn_KI270418v1
KI270418.1	NT_187412.1
KI270389.1	chrUn_KI270389v1
KI270389.1	NT_187473.1
KI270378.1	chrUn_KI270378v1
KI270378.1	NT_187471.1
KI270419.1	chrUn_KI270419v1
KI270419.1	NT_187411.1
KI270544.1	chrUn_KI270544v1
KI270544.1	NT_187444.1
KI270510.1	chrUn_KI270510v1
KI270510.1	NT_187427.1
KI270448.1	chrUn_KI270448v1
KI270448.1	NT_187495.1
KI270590.1	chrUn_KI270590v1
KI270590.1	NT_187452.1
KI270529.1	chrUn_KI270529v1
KI270529.1	NT_187439.1
KI270429.1	chrUn_KI270429v1
KI270429.1	NT_187419.1
KI270376.1	chrUn_KI270376v1
KI270376.1	NT_187489.1
KI270362.1	chrUn_KI270362v1
KI270362.1	NT_187469.1
KI270583.1	chrUn_KI270583v1
KI270583.1	NT_187446.1
KI270521.1	chrUn_KI270521v1
KI270521.1	NT_187496.1
KI270305.1	chrUn_KI270305v1
KI270305.1	NT_187399.1
KI270516.1	chrUn_KI270516v1
KI270516.1	NT_187431.1
KI270337.1	chrUn_KI270337v1
KI270337.1	NT_187466.1
KI270425.1	chrUn_KI270425v1
KI270425.1	NT_187418.1
KI270384.1	chrUn_KI270384v1
KI270384.1	NT_187484.1
KI270393.1	chrUn_KI270393v1
KI270393.1	NT_187483.1
KI270373.1	chrUn_KI270373v1
KI270373.1	NT_187492.1
KI270391.1	chrUn_KI270391v1
KI270391.1	NT_187481.1
KI270386.1	chrUn_KI270386v1
KI270386.1	NT_187480.1
KI270338.1	chrUn_KI270338v1
KI270338.1	NT_187463.1
KI270363.1	chrUn_KI270363v1
KI270363.1	NT_187467.1
KI270538.1	chrUn_KI270538v1
KI270538.1	NT_187443.1
KI270467.1	chrUn_KI270467v1
KI270467.1	NT_187423.1
KI270465.1	chrUn_KI270465v1
KI270465.1	NT_187422.1
KI270320.1	chrUn_KI270320v1
KI270320.1	NT_187401.1
KI270303.1	chrUn_KI270303v1
KI270303.1	NT_187398.1
KI270411.1	chrUn_KI270411v1
KI270411.1	NT_187409.1
KI270315.1	chrUn_KI270315v1
KI270315.1	NT_187404.1
KI270311.1	chrUn_KI270311v1
KI270311.1	NT_187406.1
KI270322.1	chrUn_KI270322v1
KI270322.1	NT_187400.1
KI270333.1	chrUn_KI270333v1
KI270333.1	NT_187461.1
KI270317.1	chrUn_KI270317v1
KI270317.1	NT_187407.1
KI270304.1	chrUn_KI270304v1
KI270304.1	NT_187397.1
KI270417.1	chrUn_KI270417v1
KI270417.1	NT_187415.1
KI270420.1	chrUn_KI270420v1
KI270420.1	NT_187413.1
KI270390.1	chrUn_KI270390v1
KI270390.1	NT_187474.1
KI270589.1	chrUn_KI270589v1
KI270589.1	NT_187451.1
KI270414.1	chrUn_KI270414v1
KI270414.1	NT_187410.1
KI270579.1	chrUn_KI270579v1
KI270579.1	NT_187450.1
KI270364.1	chrUn_KI270364v1
KI270364.1	NT_187468.1
KI270442.1	chrUn_KI270442v1
KI270442.1	NT_187420.1
KI270729.1	chr17_KI270729v1_random
KI270729.1	NT_187384.1
KI270736.1	chr22_KI270736v1_random
KI270736.1	NT_187391.1
KI270438.1	chrUn_KI270438v1
KI270438.1	NT_187425.1
KI270519.1	chrUn_KI270519v1
KI270519.1	NT_187433.1
KI270512.1	chrUn_KI270512v1
KI270512.1	NT_187432.1
KI270435.1	chrUn_KI270435v1
KI270435.1	NT_187424.1
KI270711.1	chr1_KI270711v1_random
KI270711.1	NT_187366.1
GL000009.2	chr14_GL000009v2_random
GL000009.2	NT_113796.3
GL000221.1	chr3_GL000221v1_random
GL000221.1	NT_167215.1
KI270725.1	chr14_KI270725v1_random
KI270725.1	NT_187380.1
KI270740.1	chrY_KI270740v1_random
KI270740.1	NT_187395.1
KI270751.1	chrUn_KI270751v1
KI270751.1	NT_187506.1
KI270746.1	chrUn_KI270746v1
KI270746.1	NT_187501.1
GL000213.1	chrUn_GL000213v1
GL000213.1	NT_167208.1
KI270744.1	chrUn_KI270744v1
KI270744.1	NT_187499.1
GL000220.1	chrUn_GL000220v1
GL000220.1	NT_167214.1
KI270735.1	chr22_KI270735v1_random
KI270735.1	NT_187390.1
KI270734.1	chr22_KI270734v1_random
KI270734.1	NT_187389.1
KI270709.1	chr1_KI270709v1_random
KI270709.1	NT_187364.1
KI270748.1	chrUn_KI270748v1
KI270748.1	NT_187503.1
KI270745.1	chrUn_KI270745v1
KI270745.1	NT_187500.1
GL000208.1	chr5_GL000208v1_random
GL000208.1	NT_113948.1
GL000224.1	chrUn_GL000224v1
GL000224.1	NT_167218.1
KI270752.1	chrUn_KI270752v1
KI270752.1	NT_187507.1
GL000214.1	chrUn_GL000214v1
GL000214.1	NT_167209.1
KI270742.1	chrUn_KI270742v1
KI270742.1	NT_187513.1
KI270715.1	chr2_KI270715v1_random
KI270715.1	NT_187370.1
GL000195.1	chrUn_GL000195v1
GL000195.1	NT_113901.1
KI270753.1	chrUn_KI270753v1
KI270753.1	NT_187508.1
KI270722.1	chr14_KI270722v1_random
KI270722.1	NT_187377.1
KI270719.1	chr9_KI270719v1_random
KI270719.1	NT_187374.1
KI270755.1	chrUn_KI270755v1
KI270755.1	NT_187510.1
KI270712.1	chr1_KI270712v1_random
KI270712.1	NT_187367.1
KI270732.1	chr22_KI270732v1_random
KI270732.1	NT_187387.1
KI270708.1	chr1_KI270708v1_random
KI270708.1	NT_187363.1
KI270731.1	chr22_KI270731v1_random
KI270731.1	NT_187386.1
KI270720.1	chr9_KI270720v1_random
KI270720.1	NT_187375.1
GL000194.1	chr14_GL000194v1_random
GL000194.1	NT_113888.1
KI270713.1	chr1_KI270713v1_random
KI270713.1	NT_187368.1
KI270716.1	chr2_KI270716v1_random
KI270716.1	NT_187371.1
KI270723.1	chr14_KI270723v1_random
KI270723.1	NT_187378.1
GL000226.1	chrUn_GL000226v1
GL000226.1	NT_167220.1
GL000219.1	chrUn_GL000219v1
GL000219.1	NT_167213.1
KI270750.1	chrUn_KI270750v1
KI270750.1	NT_187505.1
KI270724.1	chr14_KI270724v1_random
KI270724.1	NT_187379.1
KI270707.1	chr1_KI270707v1_random
KI270707.1	NT_187362.1
KI270754.1	chrUn_KI270754v1
KI270754.1	NT_187509.1
KI270706.1	chr1_KI270706v1_random
KI270706.1	NT_187361.1
GL000218.1	chrUn_GL000218v1
GL000218.1	NT_113889.1
KI270714.1	chr1_KI270714v1_random
KI270714.1	NT_187369.1
KI270733.1	chr22_KI270733v1_random
KI270733.1	NT_187388.1
KI270721.1	chr11_KI270721v1_random
KI270721.1	NT_187376.1
KI270749.1	chrUn_KI270749v1
KI270749.1	NT_187504.1
GL000216.2	chrUn_GL000216v2
GL000216.2	NT_167211.2
GL000205.2	chr17_GL000205v2_random
GL000205.2	NT_113930.2
KI270718.1	chr9_KI270718v1_random
KI270718.1	NT_187373.1
KI270717.1	chr9_KI270717v1_random
KI270717.1	NT_187372.1
KI270743.1	chrUn_KI270743v1
KI270743.1	NT_187498.1
GL000008.2	chr4_GL000008v2_random
GL000008.2	NT_113793.3
KI270710.1	chr1_KI270710v1_random
KI270710.1	NT_187365.1
GL000225.1	chr14_GL000225v1_random
GL000225.1	NT_167219.1
KI270747.1	chrUn_KI270747v1
KI270747.1	NT_187502.1
KI270726.1	chr14_KI270726v1_random
KI270726.1	NT_187381.1
KI270728.1	chr16_KI270728v1_random
KI270728.1	NT_187383.1
20	CM000682.2
20	chr20
20	NC_000020.11
X	CM000685.2
X	chrX
X	NC_000023.11
13	CM000675.2
13	chr13
13	NC_000013.11
22	CM000684.2
22	chr22
22	NC_000022.11
10	CM000672.2
10	chr10
10	NC_000010.11
6	CM000668.2
6	chr6
6	NC_000006.12
19	CM000681.2
19	chr19
19	NC_000019.10
14	CM000676.2
14	chr14
14	NC_000014.9
18	CM000680.2
18	chr18
18	NC_000018.10
2	CM000664.2
2	chr2
2	NC_000002.12
4	CM000666.2
4	chr4
4	NC_000004.12
21	CM000683.2
21	chr21
21	NC_000021.9
9	CM000671.2
9	chr9
9	NC_000009.12
11	CM000673.2
11	chr11
11	NC_000011.10
17	CM000679.2
17	chr17
17	NC_000017.11
8	CM000670.2
8	chr8
8	NC_000008.11
7	CM000669.2
7	chr7
7	NC_000007.14
15	CM000677.2
15	chr15
15	NC_000015.10
12	CM000674.2
12	chr12
12	NC_000012.12
1	CM000663.2
1	chr1
1	NC_000001.11
16	CM000678.2
16	chr16
16	NC_000016.10
5	CM000667.2
5	chr5
5	NC_000005.10
3	CM000665.2
3	chr3
3	NC_000003.12
MT	chrM
MT	J01415.2
MT	NC_012920.1
KI270727.1	chr15_KI270727v1_random
KI270727.1	NT_187382.1
CHR_HG2062_PATCH	HG2062_PATCH
CHR_HSCHR20_1_CTG1	HSCHR20_1_CTG1
CHR_HSCHR20_1_CTG2	HSCHR20_1_CTG2
CHR_HSCHR20_1_CTG4	HSCHR20_1_CTG4
CHR_HSCHR20_1_CTG3	HSCHR20_1_CTG3
CHR_HSCHRX_1_CTG3	HSCHRX_1_CTG3
CHR_HSCHRX_2_CTG12	HSCHRX_2_CTG12
CHR_HSCHRX_2_CTG3	HSCHRX_2_CTG3
CHR_HSCHR13_1_CTG3	HSCHR13_1_CTG3
CHR_HSCHR13_1_CTG2	HSCHR13_1_CTG2
CHR_HSCHR13_1_CTG6	HSCHR13_1_CTG6
CHR_HSCHR13_1_CTG4	HSCHR13_1_CTG4
CHR_HSCHR13_1_CTG1	HSCHR13_1_CTG1
CHR_HSCHR13_1_CTG5	HSCHR13_1_CTG5
CHR_HG2291_PATCH	HG2291_PATCH
CHR_HG2216_PATCH	HG2216_PATCH
CHR_HG2249_PATCH	HG2249_PATCH
CHR_HG2288_HG2289_PATCH	HG2288_HG2289_PATCH
CHR_HSCHR13_1_CTG7	HSCHR13_1_CTG7
CHR_HSCHR13_1_CTG8	HSCHR13_1_CTG8
CHR_HSCHR22_1_CTG3	HSCHR22_1_CTG3
CHR_HSCHR22_1_CTG6	HSCHR22_1_CTG6
CHR_HSCHR22_1_CTG7	HSCHR22_1_CTG7
CHR_HSCHR22_1_CTG4	HSCHR22_1_CTG4
CHR_HSCHR22_1_CTG5	HSCHR22_1_CTG5
CHR_HSCHR22_1_CTG2	HSCHR22_1_CTG2
CHR_HSCHR22_1_CTG1	HSCHR22_1_CTG1
CHR_HSCHR22_2_CTG1	HSCHR22_2_CTG1
CHR_HSCHR22_3_CTG1	HSCHR22_3_CTG1
CHR_HSCHR22_4_CTG1	HSCHR22_4_CTG1
CHR_HSCHR22_5_CTG1	HSCHR22_5_CTG1
CHR_HSCHR22_6_CTG1	HSCHR22_6_CTG1
CHR_HSCHR22_7_CTG1	HSCHR22_7_CTG1
CHR_HSCHR22_8_CTG1	HSCHR22_8_CTG1
CHR_HG1311_PATCH	HG1311_PATCH
CHR_HSCHR10_1_CTG1	HSCHR10_1_CTG1
CHR_HSCHR10_1_CTG3	HSCHR10_1_CTG3
CHR_HSCHR10_1_CTG2	HSCHR10_1_CTG2
CHR_HSCHR10_1_CTG4	HSCHR10_1_CTG4
CHR_HG2244_HG2245_PATCH	HG2244_HG2245_PATCH
CHR_HG2191_PATCH	HG2191_PATCH
CHR_HG2242_HG2243_PATCH	HG2242_HG2243_PATCH
CHR_HG2241_PATCH	HG2241_PATCH
CHR_HSCHR10_1_CTG6	HSCHR10_1_CTG6
CHR_HG2334_PATCH	HG2334_PATCH
CHR_HSCHR6_MHC_APD_CTG1	HSCHR6_MHC_APD_CTG1
CHR_HSCHR6_1_CTG7	HSCHR6_1_CTG7
CHR_HSCHR6_1_CTG6	HSCHR6_1_CTG6
CHR_HSCHR6_1_CTG2	HSCHR6_1_CTG2
CHR_HSCHR6_1_CTG8	HSCHR6_1_CTG8
CHR_HSCHR6_1_CTG9	HSCHR6_1_CTG9
CHR_HSCHR6_1_CTG3	HSCHR6_1_CTG3
CHR_HSCHR6_1_CTG4	HSCHR6_1_CTG4
CHR_HSCHR6_1_CTG5	HSCHR6_1_CTG5
CHR_HSCHR6_MHC_COX_CTG1	HSCHR6_MHC_COX_CTG1
CHR_HSCHR6_MHC_DBB_CTG1	HSCHR6_MHC_DBB_CTG1
CHR_HSCHR6_MHC_MANN_CTG1	HSCHR6_MHC_MANN_CTG1
CHR_HSCHR6_MHC_MCF_CTG1	HSCHR6_MHC_MCF_CTG1
CHR_HSCHR6_MHC_QBL_CTG1	HSCHR6_MHC_QBL_CTG1
CHR_HSCHR6_MHC_SSTO_CTG1	HSCHR6_MHC_SSTO_CTG1
CHR_HSCHR6_8_CTG1	HSCHR6_8_CTG1
CHR_HG2128_PATCH	HG2128_PATCH
CHR_HG1651_PATCH	HG1651_PATCH
CHR_HSCHR6_1_CTG10	HSCHR6_1_CTG10
CHR_HG2072_PATCH	HG2072_PATCH
CHR_HSCHR19_5_CTG2	HSCHR19_5_CTG2
CHR_HSCHR19_4_CTG2	HSCHR19_4_CTG2
CHR_HSCHR19_1_CTG2	HSCHR19_1_CTG2
CHR_HSCHR19_2_CTG2	HSCHR19_2_CTG2
CHR_HSCHR19_3_CTG2	HSCHR19_3_CTG2
CHR_HSCHR19_1_CTG3_1	HSCHR19_1_CTG3_1
CHR_HSCHR19_2_CTG3_1	HSCHR19_2_CTG3_1
CHR_HSCHR19_3_CTG3_1	HSCHR19_3_CTG3_1
CHR_HSCHR19LRC_COX1_CTG3_1	HSCHR19LRC_COX1_CTG3_1
CHR_HSCHR19LRC_COX2_CTG3_1	HSCHR19LRC_COX2_CTG3_1
CHR_HSCHR19LRC_LRC_I_CTG3_1	HSCHR19LRC_LRC_I_CTG3_1
CHR_HSCHR19LRC_LRC_J_CTG3_1	HSCHR19LRC_LRC_J_CTG3_1
CHR_HSCHR19LRC_LRC_S_CTG3_1	HSCHR19LRC_LRC_S_CTG3_1
CHR_HSCHR19LRC_LRC_T_CTG3_1	HSCHR19LRC_LRC_T_CTG3_1
CHR_HSCHR19LRC_PGF1_CTG3_1	HSCHR19LRC_PGF1_CTG3_1
CHR_HSCHR19LRC_PGF2_CTG3_1	HSCHR19LRC_PGF2_CTG3_1
CHR_HSCHR19_4_CTG3_1	HSCHR19_4_CTG3_1
CHR_HSCHR19KIR_FH15_B_HAP_CTG3_1	HSCHR19KIR_FH15_B_HAP_CTG3_1
CHR_HSCHR19KIR_G085_A_HAP_CTG3_1	HSCHR19KIR_G085_A_HAP_CTG3_1
CHR_HSCHR19KIR_G085_BA1_HAP_CTG3_1	HSCHR19KIR_G085_BA1_HAP_CTG3_1
CHR_HSCHR19KIR_G248_A_HAP_CTG3_1	HSCHR19KIR_G248_A_HAP_CTG3_1
CHR_HSCHR19KIR_G248_BA2_HAP_CTG3_1	HSCHR19KIR_G248_BA2_HAP_CTG3_1
CHR_HSCHR19KIR_GRC212_AB_HAP_CTG3_1	HSCHR19KIR_GRC212_AB_HAP_CTG3_1
CHR_HSCHR19KIR_GRC212_BA1_HAP_CTG3_1	HSCHR19KIR_GRC212_BA1_HAP_CTG3_1
CHR_HSCHR19KIR_LUCE_A_HAP_CTG3_1	HSCHR19KIR_LUCE_A_HAP_CTG3_1
CHR_HSCHR19KIR_LUCE_BDEL_HAP_CTG3_1	HSCHR19KIR_LUCE_BDEL_HAP_CTG3_1
CHR_HSCHR19KIR_RSH_A_HAP_CTG3_1	HSCHR19KIR_RSH_A_HAP_CTG3_1
CHR_HSCHR19KIR_RSH_BA2_HAP_CTG3_1	HSCHR19KIR_RSH_BA2_HAP_CTG3_1
CHR_HSCHR19KIR_T7526_A_HAP_CTG3_1	HSCHR19KIR_T7526_A_HAP_CTG3_1
CHR_HSCHR19KIR_T7526_BDEL_HAP_CTG3_1	HSCHR19KIR_T7526_BDEL_HAP_CTG3_1
CHR_HSCHR19KIR_ABC08_A1_HAP_CTG3_1	HSCHR19KIR_ABC08_A1_HAP_CTG3_1
CHR_HSCHR19KIR_ABC08_AB_HAP_C_P_CTG3_1	HSCHR19KIR_ABC08_AB_HAP_C_P_CTG3_1
CHR_HSCHR19KIR_ABC08_AB_HAP_T_P_CTG3_1	HSCHR19KIR_ABC08_AB_HAP_T_P_CTG3_1
CHR_HSCHR19KIR_FH05_A_HAP_CTG3_1	HSCHR19KIR_FH05_A_HAP_CTG3_1
CHR_HSCHR19KIR_FH05_B_HAP_CTG3_1	HSCHR19KIR_FH05_B_HAP_CTG3_1
CHR_HSCHR19KIR_FH06_A_HAP_CTG3_1	HSCHR19KIR_FH06_A_HAP_CTG3_1
CHR_HSCHR19KIR_FH06_BA1_HAP_CTG3_1	HSCHR19KIR_FH06_BA1_HAP_CTG3_1
CHR_HSCHR19KIR_FH08_A_HAP_CTG3_1	HSCHR19KIR_FH08_A_HAP_CTG3_1
CHR_HSCHR19KIR_FH08_BAX_HAP_CTG3_1	HSCHR19KIR_FH08_BAX_HAP_CTG3_1
CHR_HSCHR19KIR_FH13_A_HAP_CTG3_1	HSCHR19KIR_FH13_A_HAP_CTG3_1
CHR_HSCHR19KIR_FH13_BA2_HAP_CTG3_1	HSCHR19KIR_FH13_BA2_HAP_CTG3_1
CHR_HSCHR19KIR_FH15_A_HAP_CTG3_1	HSCHR19KIR_FH15_A_HAP_CTG3_1
CHR_HSCHR19KIR_RP5_B_HAP_CTG3_1	HSCHR19KIR_RP5_B_HAP_CTG3_1
CHR_HG2021_PATCH	HG2021_PATCH
CHR_HG26_PATCH	HG26_PATCH
CHR_HSCHR14_1_CTG1	HSCHR14_1_CTG1
CHR_HSCHR14_7_CTG1	HSCHR14_7_CTG1
CHR_HSCHR14_2_CTG1	HSCHR14_2_CTG1
CHR_HSCHR14_3_CTG1	HSCHR14_3_CTG1
CHR_HSCHR18_4_CTG1_1	HSCHR18_4_CTG1_1
CHR_HSCHR18_1_CTG1_1	HSCHR18_1_CTG1_1
CHR_HSCHR18_2_CTG1_1	HSCHR18_2_CTG1_1
CHR_HSCHR18_2_CTG2	HSCHR18_2_CTG2
CHR_HSCHR18_1_CTG2	HSCHR18_1_CTG2
CHR_HSCHR18_1_CTG2_1	HSCHR18_1_CTG2_1
CHR_HSCHR18_2_CTG2_1	HSCHR18_2_CTG2_1
CHR_HSCHR18_3_CTG2_1	HSCHR18_3_CTG2_1
CHR_HSCHR18_ALT21_CTG2_1	HSCHR18_ALT21_CTG2_1
CHR_HSCHR18_ALT2_CTG2_1	HSCHR18_ALT2_CTG2_1
CHR_HSCHR18_5_CTG1_1	HSCHR18_5_CTG1_1
CHR_HG2213_PATCH	HG2213_PATCH
CHR_HSCHR2_2_CTG1	HSCHR2_2_CTG1
CHR_HSCHR2_3_CTG1	HSCHR2_3_CTG1
CHR_HSCHR2_4_CTG1	HSCHR2_4_CTG1
CHR_HSCHR2_1_CTG1	HSCHR2_1_CTG1
CHR_HSCHR2_1_CTG5	HSCHR2_1_CTG5
CHR_HSCHR2_1_CTG7	HSCHR2_1_CTG7
CHR_HSCHR2_5_CTG7_2	HSCHR2_5_CTG7_2
CHR_HSCHR2_4_CTG7_2	HSCHR2_4_CTG7_2
CHR_HSCHR2_3_CTG7_2	HSCHR2_3_CTG7_2
CHR_HSCHR2_2_CTG7_2	HSCHR2_2_CTG7_2
CHR_HSCHR2_1_CTG7_2	HSCHR2_1_CTG7_2
CHR_HSCHR2_3_CTG15	HSCHR2_3_CTG15
CHR_HSCHR2_1_CTG15	HSCHR2_1_CTG15
CHR_HSCHR2_2_CTG7	HSCHR2_2_CTG7
CHR_HSCHR2_2_CTG15	HSCHR2_2_CTG15
CHR_HG2232_PATCH	HG2232_PATCH
CHR_HG2233_PATCH	HG2233_PATCH
CHR_HG2290_PATCH	HG2290_PATCH
CHR_HSCHR2_6_CTG7_2	HSCHR2_6_CTG7_2
CHR_HSCHR4_1_CTG4	HSCHR4_1_CTG4
CHR_HSCHR4_1_CTG6	HSCHR4_1_CTG6
CHR_HSCHR4_1_CTG8_1	HSCHR4_1_CTG8_1
CHR_HSCHR4_1_CTG9	HSCHR4_1_CTG9
CHR_HSCHR4_4_CTG12	HSCHR4_4_CTG12
CHR_HSCHR4_1_CTG12	HSCHR4_1_CTG12
CHR_HSCHR4_2_CTG12	HSCHR4_2_CTG12
CHR_HSCHR4_5_CTG12	HSCHR4_5_CTG12
CHR_HSCHR4_3_CTG12	HSCHR4_3_CTG12
CHR_HSCHR4_6_CTG12	HSCHR4_6_CTG12
CHR_HSCHR4_7_CTG12	HSCHR4_7_CTG12
CHR_HSCHR4_2_CTG4	HSCHR4_2_CTG4
CHR_HSCHR4_8_CTG12	HSCHR4_8_CTG12
CHR_HSCHR4_9_CTG12	HSCHR4_9_CTG12
CHR_HG2023_PATCH	HG2023_PATCH
CHR_HSCHR4_11_CTG12	HSCHR4_11_CTG12
CHR_HSCHR21_1_CTG1_1	HSCHR21_1_CTG1_1
CHR_HSCHR21_8_CTG1_1	HSCHR21_8_CTG1_1
CHR_HSCHR21_6_CTG1_1	HSCHR21_6_CTG1_1
CHR_HSCHR21_2_CTG1_1	HSCHR21_2_CTG1_1
CHR_HSCHR21_3_CTG1_1	HSCHR21_3_CTG1_1
CHR_HSCHR21_4_CTG1_1	HSCHR21_4_CTG1_1
CHR_HSCHR21_5_CTG2	HSCHR21_5_CTG2
CHR_HSCHR9_1_CTG1	HSCHR9_1_CTG1
CHR_HSCHR9_1_CTG2	HSCHR9_1_CTG2
CHR_HSCHR9_1_CTG3	HSCHR9_1_CTG3
CHR_HSCHR9_1_CTG4	HSCHR9_1_CTG4
CHR_HSCHR9_1_CTG5	HSCHR9_1_CTG5
CHR_HG2030_PATCH	HG2030_PATCH
CHR_HSCHR9_1_CTG6	HSCHR9_1_CTG6
CHR_HSCHR9_1_CTG7	HSCHR9_1_CTG7
CHR_HSCHR11_1_CTG8	HSCHR11_1_CTG8
CHR_HSCHR11_1_CTG6	HSCHR11_1_CTG6
CHR_HSCHR11_1_CTG7	HSCHR11_1_CTG7
CHR_HSCHR11_1_CTG5	HSCHR11_1_CTG5
CHR_HSCHR11_1_CTG1_1	HSCHR11_1_CTG1_1
CHR_HG142_HG150_NOVEL_TEST	HG142_HG150_NOVEL_TEST
CHR_HG151_NOVEL_TEST	HG151_NOVEL_TEST
CHR_HSCHR11_1_CTG3	HSCHR11_1_CTG3
CHR_HSCHR11_1_CTG2	HSCHR11_1_CTG2
CHR_HSCHR11_2_CTG1	HSCHR11_2_CTG1
CHR_HSCHR11_2_CTG1_1	HSCHR11_2_CTG1_1
CHR_HSCHR11_3_CTG1	HSCHR11_3_CTG1
CHR_HSCHR11_1_CTG1_2	HSCHR11_1_CTG1_2
CHR_HG2217_PATCH	HG2217_PATCH
CHR_HG2116_PATCH	HG2116_PATCH
CHR_HG107_PATCH	HG107_PATCH
CHR_HSCHR17_1_CTG1	HSCHR17_1_CTG1
CHR_HSCHR17_2_CTG2	HSCHR17_2_CTG2
CHR_HSCHR17_1_CTG2	HSCHR17_1_CTG2
CHR_HSCHR17_7_CTG4	HSCHR17_7_CTG4
CHR_HSCHR17_4_CTG4	HSCHR17_4_CTG4
CHR_HSCHR17_5_CTG4	HSCHR17_5_CTG4
CHR_HSCHR17_1_CTG4	HSCHR17_1_CTG4
CHR_HSCHR17_1_CTG5	HSCHR17_1_CTG5
CHR_HSCHR17_2_CTG4	HSCHR17_2_CTG4
CHR_HSCHR17_8_CTG4	HSCHR17_8_CTG4
CHR_HSCHR17_9_CTG4	HSCHR17_9_CTG4
CHR_HSCHR17_3_CTG4	HSCHR17_3_CTG4
CHR_HSCHR17_1_CTG9	HSCHR17_1_CTG9
CHR_HSCHR17_2_CTG1	HSCHR17_2_CTG1
CHR_HSCHR17_3_CTG2	HSCHR17_3_CTG2
CHR_HSCHR17_10_CTG4	HSCHR17_10_CTG4
CHR_HSCHR17_6_CTG4	HSCHR17_6_CTG4
CHR_HSCHR17_2_CTG5	HSCHR17_2_CTG5
CHR_HSCHR8_4_CTG1	HSCHR8_4_CTG1
CHR_HSCHR8_2_CTG1	HSCHR8_2_CTG1
CHR_HSCHR8_1_CTG1	HSCHR8_1_CTG1
CHR_HSCHR8_8_CTG1	HSCHR8_8_CTG1
CHR_HSCHR8_3_CTG1	HSCHR8_3_CTG1
CHR_HSCHR8_9_CTG1	HSCHR8_9_CTG1
CHR_HSCHR8_1_CTG6	HSCHR8_1_CTG6
CHR_HSCHR8_1_CTG7	HSCHR8_1_CTG7
CHR_HSCHR8_5_CTG7	HSCHR8_5_CTG7
CHR_HSCHR8_6_CTG7	HSCHR8_6_CTG7
CHR_HSCHR8_4_CTG7	HSCHR8_4_CTG7
CHR_HSCHR8_3_CTG7	HSCHR8_3_CTG7
CHR_HSCHR8_2_CTG7	HSCHR8_2_CTG7
CHR_HSCHR8_6_CTG1	HSCHR8_6_CTG1
CHR_HSCHR8_5_CTG1	HSCHR8_5_CTG1
CHR_HSCHR8_7_CTG1	HSCHR8_7_CTG1
CHR_HSCHR7_1_CTG1	HSCHR7_1_CTG1
CHR_HSCHR7_2_CTG4_4	HSCHR7_2_CTG4_4
CHR_HSCHR7_1_CTG4_4	HSCHR7_1_CTG4_4
CHR_HSCHR7_1_CTG6	HSCHR7_1_CTG6
CHR_HSCHR7_2_CTG6	HSCHR7_2_CTG6
CHR_HSCHR7_3_CTG6	HSCHR7_3_CTG6
CHR_HSCHR7_2_CTG7	HSCHR7_2_CTG7
CHR_HSCHR7_1_CTG7	HSCHR7_1_CTG7
CHR_HSCHR7_2_CTG1	HSCHR7_2_CTG1
CHR_HG2239_PATCH	HG2239_PATCH
CHR_HSCHR15_1_CTG1	HSCHR15_1_CTG1
CHR_HSCHR15_3_CTG3	HSCHR15_3_CTG3
CHR_HSCHR15_1_CTG3	HSCHR15_1_CTG3
CHR_HSCHR15_1_CTG8	HSCHR15_1_CTG8
CHR_HSCHR15_3_CTG8	HSCHR15_3_CTG8
CHR_HSCHR15_2_CTG8	HSCHR15_2_CTG8
CHR_HSCHR15_5_CTG8	HSCHR15_5_CTG8
CHR_HSCHR15_2_CTG3	HSCHR15_2_CTG3
CHR_HSCHR15_4_CTG8	HSCHR15_4_CTG8
CHR_HSCHR15_6_CTG8	HSCHR15_6_CTG8
CHR_HSCHR12_1_CTG1	HSCHR12_1_CTG1
CHR_HSCHR12_2_CTG2	HSCHR12_2_CTG2
CHR_HSCHR12_5_CTG2	HSCHR12_5_CTG2
CHR_HSCHR12_1_CTG2	HSCHR12_1_CTG2
CHR_HSCHR12_4_CTG2	HSCHR12_4_CTG2
CHR_HSCHR12_1_CTG2_1	HSCHR12_1_CTG2_1
CHR_HSCHR12_2_CTG2_1	HSCHR12_2_CTG2_1
CHR_HSCHR12_3_CTG2_1	HSCHR12_3_CTG2_1
CHR_HSCHR12_6_CTG2_1	HSCHR12_6_CTG2_1
CHR_HSCHR12_4_CTG2_1	HSCHR12_4_CTG2_1
CHR_HSCHR12_5_CTG2_1	HSCHR12_5_CTG2_1
CHR_HSCHR12_7_CTG2_1	HSCHR12_7_CTG2_1
CHR_HSCHR12_3_CTG2	HSCHR12_3_CTG2
CHR_HG1362_PATCH	HG1362_PATCH
CHR_HG23_PATCH	HG23_PATCH
CHR_HG2247_PATCH	HG2247_PATCH
CHR_HSCHR12_2_CTG1	HSCHR12_2_CTG1
CHR_HG2063_PATCH	HG2063_PATCH
CHR_HSCHR1_1_CTG3	HSCHR1_1_CTG3
CHR_HSCHR1_2_CTG3	HSCHR1_2_CTG3
CHR_HSCHR1_1_CTG11	HSCHR1_1_CTG11
CHR_HSCHR1_4_CTG31	HSCHR1_4_CTG31
CHR_HSCHR1_1_CTG31	HSCHR1_1_CTG31
CHR_HSCHR1_2_CTG31	HSCHR1_2_CTG31
CHR_HSCHR1_3_CTG31	HSCHR1_3_CTG31
CHR_HSCHR1_4_CTG32_1	HSCHR1_4_CTG32_1
CHR_HSCHR1_3_CTG32_1	HSCHR1_3_CTG32_1
CHR_HSCHR1_1_CTG32_1	HSCHR1_1_CTG32_1
CHR_HSCHR1_2_CTG32_1	HSCHR1_2_CTG32_1
CHR_HSCHR1_ALT2_1_CTG32_1	HSCHR1_ALT2_1_CTG32_1
CHR_HG2095_PATCH	HG2095_PATCH
CHR_HG2058_PATCH	HG2058_PATCH
CHR_HG986_PATCH	HG986_PATCH
CHR_HG2104_PATCH	HG2104_PATCH
CHR_HG1832_PATCH	HG1832_PATCH
CHR_HG1342_HG2282_PATCH	HG1342_HG2282_PATCH
CHR_HSCHR1_4_CTG3	HSCHR1_4_CTG3
CHR_HSCHR1_3_CTG3	HSCHR1_3_CTG3
CHR_HSCHR1_5_CTG32_1	HSCHR1_5_CTG32_1
CHR_HSCHR1_5_CTG3	HSCHR1_5_CTG3
CHR_HSCHR16_CTG2	HSCHR16_CTG2
CHR_HSCHR16_4_CTG1	HSCHR16_4_CTG1
CHR_HSCHR16_3_CTG1	HSCHR16_3_CTG1
CHR_HSCHR16_1_CTG1	HSCHR16_1_CTG1
CHR_HSCHR16_1_CTG3_1	HSCHR16_1_CTG3_1
CHR_HSCHR16_2_CTG3_1	HSCHR16_2_CTG3_1
CHR_HSCHR16_3_CTG3_1	HSCHR16_3_CTG3_1
CHR_HSCHR16_5_CTG1	HSCHR16_5_CTG1
CHR_HSCHR16_4_CTG3_1	HSCHR16_4_CTG3_1
CHR_HSCHR5_5_CTG1	HSCHR5_5_CTG1
CHR_HSCHR5_4_CTG1	HSCHR5_4_CTG1
CHR_HSCHR5_3_CTG1	HSCHR5_3_CTG1
CHR_HSCHR5_1_CTG1	HSCHR5_1_CTG1
CHR_HSCHR5_2_CTG1	HSCHR5_2_CTG1
CHR_HSCHR5_6_CTG1	HSCHR5_6_CTG1
CHR_HSCHR5_2_CTG1_1	HSCHR5_2_CTG1_1
CHR_HSCHR5_3_CTG1_1	HSCHR5_3_CTG1_1
CHR_HSCHR5_4_CTG1_1	HSCHR5_4_CTG1_1
CHR_HSCHR5_1_CTG5	HSCHR5_1_CTG5
CHR_HSCHR5_2_CTG5	HSCHR5_2_CTG5
CHR_HSCHR5_1_CTG1_1	HSCHR5_1_CTG1_1
CHR_HSCHR5_3_CTG5	HSCHR5_3_CTG5
CHR_HSCHR5_7_CTG1	HSCHR5_7_CTG1
CHR_HSCHR3_1_CTG1	HSCHR3_1_CTG1
CHR_HSCHR3_3_CTG1	HSCHR3_3_CTG1
CHR_HSCHR3_4_CTG2_1	HSCHR3_4_CTG2_1
CHR_HSCHR3_1_CTG2_1	HSCHR3_1_CTG2_1
CHR_HSCHR3_2_CTG2_1	HSCHR3_2_CTG2_1
CHR_HSCHR3_3_CTG2_1	HSCHR3_3_CTG2_1
CHR_HSCHR3_5_CTG2_1	HSCHR3_5_CTG2_1
CHR_HSCHR3_1_CTG3	HSCHR3_1_CTG3
CHR_HSCHR3_2_CTG3	HSCHR3_2_CTG3
CHR_HSCHR3_9_CTG3	HSCHR3_9_CTG3
CHR_HSCHR3_3_CTG3	HSCHR3_3_CTG3
CHR_HSCHR3_4_CTG3	HSCHR3_4_CTG3
CHR_HSCHR3_5_CTG3	HSCHR3_5_CTG3
CHR_HSCHR3_6_CTG3	HSCHR3_6_CTG3
CHR_HSCHR3_7_CTG3	HSCHR3_7_CTG3
CHR_HSCHR3_8_CTG3	HSCHR3_8_CTG3
CHR_HG2066_PATCH	HG2066_PATCH
CHR_HG126_PATCH	HG126_PATCH
CHR_HG2022_PATCH	HG2022_PATCH
CHR_HG2235_PATCH	HG2235_PATCH
CHR_HG2237_PATCH	HG2237_PATCH
Y	CM000686.2
Y	chrY
Y	NC_000024.10
__END__