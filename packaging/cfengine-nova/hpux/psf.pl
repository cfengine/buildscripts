#!/usr/local/bin/perl -w
################################################################################
#
#  psf
#
#  Builds a Product Specification File (psf) from the directories listed
#  on the command line.  It assumes that the following naming convention
#  has been used for the directory names.  The first part of the directory
#  name is the product name, and the rest is the product version.
#
#  Author:  David C. Snyder
#
#  $Log: psf,v $
#  Revision 1.2  1997/09/05 11:44:16  dsnyder
#  Changed the name of the script to psf (from psfls)
#
#  Revision 1.1  1997/09/02 15:00:42  dsnyder
#  Initial revision
#
################################################################################

use strict;

die "Usage:  $0: dir ...\n" unless ( @ARGV );

my ($dir, $tag, $revision, $lctag);
$dir = $ARGV[0];
$tag = $ARGV[1];
$revision = $ARGV[2];
$lctag = lc $tag;
my @scripttypes = ( "preinstall", "postinstall", "preremove", "postremove" );

print <<EOF;
product
    tag                  $tag
    revision             $revision
EOF

foreach my $type (@scripttypes)
{
    my @files = glob("*.$type");
    if (scalar(@files) > 1)
    {
        print "More than one $type file found\n";
        exit(1);
    }
    foreach my $file (@files)
    {
        printf("    %-21s%s\n", $type, $file);
    }
}

print <<EOF;
    fileset
    tag               $lctag
    file_permissions  -o root -g root
EOF
listdir( $dir ) if ( -d $dir );
print <<EOF;
   end
end
EOF
exit( 0 );


sub listdir {
    my $dir = shift;
    my ( $mode, $entry );
    my @directories;

    opendir CWD, "$dir" or die "$0: opendir $dir: $!\n";
    printf "      directory         %s=/%s\n",
        $dir, $dir;
    foreach $entry ( sort readdir CWD ) {
        my $packagescript = 0;
        foreach my $type (@scripttypes)
        {
            if ($entry =~ /.*\.$type/)
            {
                $packagescript = 1;
            }
        }
        next if ($packagescript or $entry eq "." or $entry eq ".." or
            $entry eq "..install_finish" or
            $entry eq "..install_start");
        lstat "$dir/$entry" or die "$0: stat $dir/$entry: $!\n";
        if ( -d _ ) {
            push @directories, $entry;
        } else {
            printf "      file              %s\n", $entry;
        }
    }
    foreach $entry ( sort @directories ) {
        listdir( "$dir/$entry" );
    }
#    closedir CWD;
}

