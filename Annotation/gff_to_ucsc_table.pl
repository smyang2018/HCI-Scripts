#!/usr/bin/perl

# documentation at end of file

use strict;
use Getopt::Long;
use Pod::Usage;
use Bio::ToolBox::parser::gff '1.53';
use Bio::ToolBox::GeneTools 1.53 qw(ucsc_string filter_transcript_support_level);
use Bio::ToolBox::utility qw(open_to_write_fh format_with_commas);

my $VERSION = '1.53';

print "\n This program will convert a GFF3 file to UCSC gene table\n";

### Quick help
unless (@ARGV) { 
	# when no command line options are present
	# print SYNOPSIS
	pod2usage( {
		'-verbose' => 0, 
		'-exitval' => 1,
	} );
}



### Get command line options and initialize values
my (
	$infile,
	$outfile,
	$tsl,
	$gz,
	$verbose,
	$help,
	$print_version,
);

# Command line options
GetOptions( 
	'in=s'      => \$infile, # the gff3 data file
	'out=s'     => \$outfile, # name of output file 
	'tsl=s'     => \$tsl, # transcript support level filter
	'gz!'       => \$gz, # compress output
	'verbose!'  => \$verbose, # verbose print statements
	'help'      => \$help, # request help
	'version'   => \$print_version, # print the version
) or die " unrecognized option(s)!! please refer to the help documentation\n\n";

# Print help
if ($help) {
	# print entire POD
	pod2usage( {
		'-verbose' => 2,
		'-exitval' => 1,
	} );
}

# Print version
if ($print_version) {
	print " Biotoolbox script gff3_to_ucsc_table.pl, version $VERSION\n\n";
	exit;
}



### Check for requirements
unless ($infile) {
	$infile = shift @ARGV or
		die " no input file! use --help for more information\n";
}
unless ($infile =~ /\.g[tf]f 3? (?: \.gz )? $/xi) {
	die " input file doesn't have a gff extension! Is this a GFF file?\n";
}

if ($outfile) {
	# be nice and add an extension for them if it's missing
	unless ($outfile =~ /\.reff?lat(?:\.gz)?$/) {
		$outfile .= '.refFlat';
	}
}
else {
	# define a new output file name for them
	$outfile = $infile;
	$outfile =~ s/\.g[tf]f 3? (?: \.gz )? $/.refFlat/xi;
}
unless (defined $gz) {
	# mimic the input file as far as compression is concerned
	$gz = 1 if $infile =~ m/\.gz$/i;
}

### Open the output files
# Open the output gene table file
my $outfh = open_to_write_fh($outfile, $gz) or 
	die " unable to open file handle for '$outfile'!\n";

# Print headers
$outfh->print( join("\t", qw(#geneName name chrom strand txStart txEnd cdsStart 
	cdsEnd exonCount exonStarts exonEnds) ) . "\n");



### Process the GFF3 table
# initialize global variables
my %counts; # a hash of known written features
my %unknowns; # a hash of unrecognized feature types to report at the end
process_gff_file_to_table();


### Finished

# Close output file
$outfh->close;
my $count = 0;
my $string;
foreach (sort {$a cmp $b} keys %counts) {
	$count += $counts{$_};
	$string .= sprintf("  Wrote %s %s features\n", format_with_commas($counts{$_}), $_);
}
printf " Finished! Wrote %s features to file '$outfile'\n$string", 
	format_with_commas($count);


# print warnings about unknown feature types
if (%unknowns) {
	print " Unrecognized features that were not included\n";
	foreach (sort {$a cmp $b} keys %unknowns) {
		print "  Skipped $unknowns{$_} '$_' features\n";
	}
}




sub process_gff_file_to_table {
	
	# open gff3 parser object
	my $parser = Bio::ToolBox::parser::gff->new($infile) or
		die " unable to open input file '$infile'!\n";
	
	# Process the top features
	my @top_features = $parser->top_features(
		do_gene  => 1,
		do_exon  => 1,
		do_cds   => 1,
		simplify => 0,
	);
	printf " parsed %d top features\n", scalar @top_features;
	while (@top_features) {
		my $feature = shift @top_features;
		my $type = $feature->primary_tag;
		
		# check the type
		if ($type =~ /chromosome|contig|scaffold|sequence|region/i) {
			# skip chromosomes
			next;
		}
		elsif ($type =~ /gene|rna|transcript/i) {
			# a recognizable gene or transcript
			
			# filter tsl as necessary
			if ($tsl) {
				my $f_gene = filter_transcript_support_level($feature, $tsl);
				next unless $f_gene;
				$feature = $f_gene;
			}
			
			# print UCSC
			my $string = ucsc_string($feature);
			$counts{$type} += 1;
			$outfh->print($string);
		}
		else {
			# catchall for unrecognized feature types
			# record and warn at end
			$unknowns{$type} += 1;
			next;
		}
	}
	my $orphans = $parser->orphans;
	if (@$orphans) {
		printf " Input file has issues: %d orphans found!\n", scalar @$orphans;
	}
}

__END__

=head1 NAME

gff_to_ucsc_table.pl

A script to convert a GFF3 file to a UCSC style refFlat table

=head1 SYNOPSIS

gff_to_ucsc_table.pl [--options...] <filename>
  
  Options:
  --in <filename>   [gff3 gtf]
  --out <filename> 
  --tsl [1|2|3|4|5|NA|best|best1|best2|best3|best4|best5]
  --gz
  --verbose
  --version
  --help

=head1 OPTIONS

The command line flags and descriptions:

=over 4

=item --in <filename>

Specify the input GFF3 or GTF file. The file may be compressed with gzip.

=item --out <filename>

Specify the output filename. By default it uses the input file base 
name appended with '.refFlat'.

=item --tsl <level>

Filter transcripts on the Ensembl GTF/GFF3 attribute 'transcript_support_level', 
which is described at L<Ensembl TSL glossary entry|http://uswest.ensembl.org/info/website/glossary.html>.
Provide a level of support to filter. Values include: 
    
    1       All splice junctions supported by evidence
    2       Transcript flagged as suspect or only support from multiple ESTs
    3       Only support from single EST
    4       Best supporting EST is suspect
    5       No support
    best    Transcripts at the best (lowest) available level are taken
    best1   The word followed by a digit 1-5, indicating any transcript 
            at or better (lower) than the indicated level
    NA      Only transcripts without a level (NA) are retained.

=item --gz

Specify whether (or not) the output file should be compressed with gzip. 
The default is to mimic the status of the input file

=item --verbose

Specify that extra information be printed as the GFF3 file is parsed.

=item --version

Print the version number.

=item --help

Display this POD documentation.

=back

=head1 DESCRIPTION

This program will convert GFF3 or GTF annotation file to a UCSC-style 
gene table, using the refFlat format. This includes transcription 
and translation start and stops, as well as exon start and stops, 
but does not include coding exon frames. See the documentation at 
L<http://genome.ucsc.edu/goldenPath/gbdDescriptionsOld.html#RefFlat> 
for more information.

The program assumes the input GFF file includes standard 
parent-E<gt>child relationships using primary IDs and primary tags, 
including gene, mRNA, exon, CDS, and UTRs. Non-standard genes, 
including non-coding RNAs, will also be processed too. Chromosomes, 
contigs, and embedded sequence are ignored. Non-pertinent features are 
safely ignored but reported. Most pragmas are ignored. 
Multiple parentage and shared features, for example exons common to 
multiple alternative transcripts, are properly handled. See the 
documentation for the GFF3 file format at 
L<http://www.sequenceontology.org/resources/gff3.html> for more 
information. 

=head1 AUTHOR

 Timothy J. Parnell, PhD
 Howard Hughes Medical Institute
 Dept of Oncological Sciences
 Huntsman Cancer Institute
 University of Utah
 Salt Lake City, UT, 84112

This package is free software; you can redistribute it and/or modify
it under the terms of the Artistic License 2.0.  
