#!/usr/bin/perl
use strict;
use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin/..");
use config;


my $parentDir = abs_path("$FindBin::Bin/..");
my $configFile = "$parentDir/findpdbabs.conf";

my %config = config::ReadConfig($configFile);

my $abdir  = $config{'abpdbdir'};
my $allseq = "allabs.faa";
my $repseq = "cdhit.faa";
my $tplDir = "${parentDir}/$config{'tplsubdir'}";

unlink $allseq;

print "Getting list of antibody files...";
my @pdbfiles = GetFileList($abdir, '.pdb');
print "done\n";

print STDERR "Concatenating files...";
foreach my $file (@pdbfiles)
{
    my $pdbcode = $file;
    $pdbcode =~ s/.*\///;
    $pdbcode =~ s/\..*?$//;
    `pdbgetchain L,H ${abdir}/$file | pdb2pir -c -f -l ${pdbcode}_ >>$allseq`;
    print STDERR '.';
}
print "done\n";

# Grab and compile CD-HIT if not there
if( ! -d "cdhit" )
{
    print STDERR "Building cd-hit\n";
    `git clone git\@github.com:weizhongli/cdhit.git`;
    `(cd cdhit; make)`;
    print STDERR "done\n";
}

print STDERR "Running CD-HIT...";
`cdhit/cd-hit -c 0.6 -n 3 -i $allseq -o $repseq`;
print STDERR "done\n";

SplitFastaFiles($repseq, $tplDir);
unlink $allseq;
unlink $repseq;
unlink "${repseq}.clstr";


#*************************************************************************
sub SplitFastaFiles
{
    my($repseq, $tplDir) = @_;

    if(open(my $fpin, '<', $repseq))
    {
        my $seq = '';
        while(<$fpin>)
        {
            if(/\>/)
            {
                if($seq ne '')
                {
                    PrintSeq($seq, $tplDir);
                    $seq = '';
                }
            }
            $seq .= $_;
        }
        
        if($seq ne '')
        {
            PrintSeq($seq, $tplDir);
            $seq = '';
        }
    }
}

sub PrintSeq
{
    my($seq, $tplDir) = @_;
    my @lines = split(/\n/, $seq);
    my $filename = $lines[0];
    $filename =~ s/\>//;
    $filename = "${tplDir}/${filename}.faa";
    if(open(my $fpOut, '>', $filename))
    {
        print $fpOut $seq;
        close $fpOut;
    }
    else
    {
        print STDERR "Error: Unable to write $filename\n";
    }
}



#*************************************************************************
sub GetFileList
{
    my($dir, $ext) = @_;
    my @files = ();
    if(opendir(my $dirFp, $dir))
    {
        @files = grep(/$ext/, readdir($dirFp));
        closedir($dirFp);
    }
    return(@files);
}