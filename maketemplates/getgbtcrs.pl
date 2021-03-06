#!/usr/bin/perl
use strict;
use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin/..");
use config;

my $parentDir  = abs_path("$FindBin::Bin/..");
my $configFile = "$parentDir/findpdbabs.conf";

my %config = config::ReadConfig($configFile);

my $allseq="$FindBin::Bin/data/genbanktcrs.faa";
my $tmpseq="tmptcrseqs.faa";
my $repseq=$config{'tcrseqsfile'};

unlink $repseq;

# Grab and compile CD-HIT if not there
if( ! -d "cdhit" )
{
    print STDERR "Building cd-hit\n";
    `git clone git\@github.com:weizhongli/cdhit.git`;
    `(cd cdhit; make)`;
    print STDERR "done\n";
}

RelabelTCRs($tmpseq, $allseq);

print STDERR "Running CD-HIT...";
`cdhit/cd-hit -T 0 -c 0.6 -n 3 -i $tmpseq -o $repseq`;
print STDERR "done\n";

print STDERR "Non-redundant TCR sequences are in $repseq\n";

unlink $tmpseq;
unlink "${repseq}.clstr";

sub RelabelTCRs
{
    my($repseq, $tmpseq) = @_;

    if(open(my $in, '<', $tmpseq))
    {
        if(open(my $out, '>', $repseq))
        {
            my $header     = '';
            my $sequence   = '';
            while(<$in>)
            {
                chomp;
                if(/\>/)
                {
                    if($header ne '')
                    {
                        PrintFaa($out, $header, $sequence, 80);
                    }

                    $header   = $_;
                    $sequence = '';
                }
                else
                {
                    $sequence .= $_;
                }
            }
            
            if($header ne '')
            {
                PrintFaa($out, $header, $sequence, 80);
            }
            close $out;
        }
        close $in;
    }
}

sub FixHeader
{
    my($header) = @_;
    $header = substr($header,1);
    $header =~ s/\s.*//;    # Remove from first space
    $header =~ s/\|\|/\|/g; # Replace || with |
    $header =~ s/^pdb\|//;  # Remove pdb|
    $header =~ s/^sp\|//;   # Remove sp|
    $header =~ s/^pir\|//;  # Remove pir|
    $header =~ s/^prf\|//;  # Remove prf|
    $header =~ s/\|/_/g;    # Replace | with _
    
    $header = ">tcr${header}"; # Put >tcr on the start
    return($header);
}

sub PrintFaa
{
    my($out, $header, $sequence, $minlen) = @_;

    # Get just the description part of the header
    my $description = $header;
    $description =~ s/.*\|//; 
    
    if((length($sequence) >= $minlen) &&
       (($description =~ /tcr/i) ||
        ($description =~ /t-cell\s+receptor/i) ||
        ($description =~ /t-cell-receptor/i) ||
        ($description =~ /t\s+cell\s+receptor/i)) &&
       !($description =~ /antibod/i) &&
       !($description =~ /hybrid/i) &&
       !($description =~ /VH/i) &&
       !($description =~ /VL/i) &&
       !($description =~ /AEA36685\.1/i) &&   # Weird one!
       !($description =~ /hypothetical/i))
    {
        $header = FixHeader($header);
        
        print $out "$header\n";
        while(length($sequence))
        {
            my $this = substr($sequence, 0, 80);
            print $out "$this\n";
            $sequence = substr($sequence, 80);
        }
    }
    else
    {
        printf STDERR "Info: Rejected $header%s\n",
            (length($sequence) < $minlen)?" (length)":"";
    }
}
