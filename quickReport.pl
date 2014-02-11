#!/usr/bin/perl -w

use FindBin;                # Find the script location
use lib "$FindBin::Bin/lib";# Add the script libdir to libs
use Molmed::Sisyphus::Libpath;

use strict;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

use Molmed::Sisyphus::Common qw(mkpath);

=pod

=head1 NAME

quickReport.pl - Create a brief report and mail it to the specified address

=head1 SYNOPSIS

 quickReport.pl -help|-man
 quickReport.pl -runfolder <runfolder> -mail <email address> [-debug]

=head1 OPTIONS

=over 4

=item -h|-help

prints out a brief help text.

=item -m|-man

Opens the manpage.

=item -runfolder

The runfolder to generate report on.

=item -mail

Send the report to this email address

=item -debug

Print debugging information

=back

=head1 DESCRIPTION

Compiles some quick statistics about the run and sends a mail to the specified address.

=cut

# Parse options
my($help,$man) = (0,0);
my($rfPath,$mail) = (undef,undef);
our($debug) = 0;

GetOptions('help|?'=>\$help,
	   'man'=>\$man,
	   'runfolder=s' => \$rfPath,
	   'mail=s' => \$mail,
	   'debug' => \$debug,
	  ) or pod2usage(-verbose => 0);
pod2usage(-verbose => 1)  if ($help);
pod2usage(-verbose => 2)  if ($man);

unless(defined $rfPath && -e $rfPath){
    print STDERR "Runfolder not specified or does not exist\n";
    pod2usage(-verbose => 1);
    exit;
}

# Create a new sisyphus object for common functions
my $sisyphus = Molmed::Sisyphus::Common->new(PATH=>$rfPath, DEBUG=>$debug);
$rfPath = $sisyphus->PATH;

# Get the statistics generated by RTA/CASAVA
my($RtaLaneStats,$RtaSampleStats) = $sisyphus->resultStats();

my %laneFrac;
my %laneUnknown;

foreach my $sample (keys %{$RtaSampleStats}){
    foreach my $lane (keys %{$RtaSampleStats->{$sample}}){
#	foreach my $read (keys %{$RtaSampleStats->{$sample}->{$lane}}){
	# Only look at read 1
	foreach my $barcode (keys %{$RtaSampleStats->{$sample}->{$lane}->{1}}){
	    if($barcode eq 'Undetermined'){
		$laneUnknown{$lane} = sprintf('%.1f', $RtaSampleStats->{$sample}->{$lane}->{1}->{$barcode}->{PctLane});
	    }else{
		push @{$laneFrac{$lane}}, sprintf(' %.1f:%s', $RtaSampleStats->{$sample}->{$lane}->{1}->{$barcode}->{PctLane}, $sample);
	    }
	}
    }
}

open(my $repFh, '>', "$rfPath/quickReport.txt");
print $repFh join("\t", "Lane", "Read", "ReadsPF (M)", "Yield Q30 (G)", "ErrRate", "Excluded", "Sample Fractions", "Unidentified"), "\n";
foreach my $lane (sort {$a<=>$b} keys %{$RtaLaneStats}){
    foreach my $read (sort {$a<=>$b} keys %{$RtaLaneStats->{$lane}}){
	print $repFh join("\t", $lane, $read,
			  sprintf('%.0f', (defined($RtaLaneStats->{$lane}->{$read}->{PF}) ? $RtaLaneStats->{$lane}->{$read}->{PF} : 0)/1e6),
			  sprintf('%.1f', (defined($RtaLaneStats->{$lane}->{$read}->{YieldQ30}) ? $RtaLaneStats->{$lane}->{$read}->{YieldQ30} : 0)/1e9),
			  defined($RtaLaneStats->{$lane}->{$read}->{ErrRate}) ? $RtaLaneStats->{$lane}->{$read}->{ErrRate} : '-',
			  $RtaLaneStats->{$lane}->{$read}->{ExcludedTiles});
	print $repFh "\t", join(',', sort({sortLaneFrac($a,$b)} @{$laneFrac{$lane}}));

#	if(exists $laneUnknown{$lane}){
	    print $repFh "\t", (defined($laneUnknown{$lane}) ? $laneUnknown{$lane} : '');
#	}
	print $repFh "\n";
    }
}
close($repFh);

if(defined $mail && $mail =~ m/\w\@\w/){
    open(my $repFh, '<', "$rfPath/quickReport.txt");
    my $msg = '<html><body><table>' . "\n";
    my $i=0;
    while(<$repFh>){
	$i++;
	s:\t:</td><td>:g;
	s:,:<br />:g;
	if($i==1){
	    s/td/th/g;
	    $msg .= '<tr><th>' . $_ . '</tr>';
	}elsif($i%2 > 0){
	    $msg .= '<tr><td>' . $_ . '</tr>';
	}else{
	    $msg .= '<tr bgcolor="#dddddd"><td>' . $_ . '</tr>';
	}
    }
    $msg .= '</table>'. "\n";
    $msg .= '</body></html>';

    require Net::SMTP;
    #Create a new object with 'new'.
    my $smtp = Net::SMTP->new("smtp.uu.se");
    #Send the MAIL command to the server.
    $smtp->mail('seq@medsci.uu.se');
    #Send the server the 'Mail To' address.
    $smtp->to($mail);
    #Start the message.
    $smtp->data();
    #Send the message.
    $smtp->datasend('From: seq@medsci.uu.se' . "\n");
    $smtp->datasend("To: $mail\n");
    $smtp->datasend("Subject: " . basename($rfPath) . "\n");
    $smtp->datasend("MIME-Version: 1.0\n");
    $smtp->datasend("Content-Type: text/html; charset=us-ascii\n");
    $smtp->datasend("\n");
    $smtp->datasend("$msg\n\n");
    #End the message.
    $smtp->dataend();
    #Close the connection to your server.
    $smtp->quit();
}


sub sortLaneFrac{
    my @a = split ':', $_[0];
    my @b = split ':', $_[1];
    return($a[0]<=>$b[0]);
}