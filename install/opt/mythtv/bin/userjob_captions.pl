#!/usr/bin/perl
# Job to extract captions
# command line - 
# /opt/mythtv/bin/userjob_captions.pl "%FILE%" expr
# filename subtitle_type
# 9999_999999999.mpg 708

    use MythTV;

# Connect to mythbackend
    my $Myth = new MythTV();

    my $basename = @ARGV[0];
    my $search = @ARGV[1];
    my $sgroup = new MythTV::StorageGroup();
    my $basedir = $sgroup->FindRecordingDir($basename);
    my $fullfilename = "$basedir/$basename";
    system ("ls", "-l", $fullfilename) == 0 or die "File Not Found";
    system ("ionice", "-c3", "-p$$") == 0 or die "ionice failed";;
    system ("nice", "mythccextractor", "-i", $fullfilename) == 0 
        or die "mythcextrator failed";
# Examples of file names of srt files produced - 
# 2706_20160323190200.708-service-01.und.srt
# 2706_20160323190200.608-cc1.und.srt
    my $bname;
    ($bname) = ($basename =~ /([^\.]*)\./);
    my $selectedFile = "";
    $selectedFile = select_file("$basedir/$bname*$search*.srt");
    if ($selectedFile eq "") {
        $selectedFile = select_file("$basedir/$bname*.srt");
    }
    if ($selectedFile eq "") {
        die "Error: no subtitle found";
    }
    print "Selected subtitles: $selectedFile link: $basedir/$bname.srt\n";
#   hard link
    link $selectedFile, "$basedir/$bname.srt";

# parameter is search string
    sub select_file {
        my $search = shift;
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
        return $selectedFile;
    }
