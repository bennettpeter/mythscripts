#!/usr/bin/perl
# Job to extract captions
# command line - 
# /opt/mythtv/bin/userjob_captions.pl "%FILE%" expr
# filename subtitle_type
# 9999_999999999.mpg 708



#    print ((shift @ARGV) . "\n")
#    $a = shift
#    print $a . "\n"

    use MythTV;

# Connect to mythbackend
    my $Myth = new MythTV();

    my $basename = @ARGV[0];
    my $search = @ARGV[1];
    print "Name = $basename\n";
    my $sgroup = new MythTV::StorageGroup();
    my $basedir = $sgroup->FindRecordingDir($basename);
    print "basedir = $basedir\n";
    my $fullfilename = "$basedir/$basename";
    print "fullfilename = $fullfilename\n";
    system ("ls", "-l", $fullfilename) == 0 or die "File Not Found";
#    system ("mythccextractor", "-i", $basename) == 0 or die "mythcextrator failed";
# Examples of file names of srt files produced - 
# 2706_20160323190200.708-service-01.und.srt
# 2706_20160323190200.608-cc1.und.srt
    my $bname;
    if ($basename =~ /([^\.]*)\./) {
        print "match $1\n";
    }
    ($bname) = ($basename =~ /([^\.]*)\./);
    print "bname = $bname\n";
    my $selectedFile = "";
    $selectedFile = select_file("$basedir/$bname*$search*.srt");
    if ($selectedFile eq "") {
        $selectedFile = select_file("$basedir/$bname*.srt");
    }
    print "selectedFile: $selectedFile link: $basedir/$bname.srt\n";
    # hard link
    link $selectedFile, "$basedir/$bname.srt";

    # parameter is search string
    sub select_file {
        my $search = shift;
        print "Search $search\n";
        my $selectedFile = "";
        my $selectedFileSize = 0;
        foreach my $file (glob("$search")) {
            my $filesize = (stat($file))[7];
            print "$file $filesize\n";
            if ($filesize > $selectedFileSize) {
                $selectedFileSize = $filesize;
                $selectedFile = $file;
            }
        }
        print "selectedFile: $selectedFile\n";
        return $selectedFile;
    }
    
    
