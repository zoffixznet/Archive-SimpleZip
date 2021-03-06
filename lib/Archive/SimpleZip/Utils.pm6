
unit module Archive::SimpleZip::Utils;

use v6;

need Compress::Zlib::Raw;
use NativeCall;

sub crc32(int32 $crc, Blob $data) is export
{
    my $indata := nativecast CArray[uint8], $data ;
    my int32 $newCRC = Compress::Zlib::Raw::crc32($crc, $indata, $data.bytes);

    return $newCRC;
}


class ProxyWrite is export
{
    # Need this class to work around "tell" not working as expected.
    # See RT 123838: IO::Handle::tell return 0, no matter what
    #     https://rt.perl.org/Ticket/Display.html?id=123838

    has IO::Handle $.filehandle ;
    has Int        $!offset = 0 ;

    method write(Blob $data)
    {
        $!offset += $data.elems;
        $.filehandle.write($data);
    }

    method write-at(Int $index, Blob $data)
    {
        $.filehandle.seek($index, SeekFromBeginning);
        $.filehandle.write($data);
        $.filehandle.seek($!offset, SeekFromBeginning);
    }

    method tell()
    {
        return $!offset;
    }

    method close()
    {
        close $.filehandle;
    }
}


sub get-DOS-time(Instant $timestamp) is export
{
    # TODO - add something to cope with time < 1980 

    my $dt = DateTime.new($timestamp) ;

	my Int $time = 0;
	$time += $dt.second        +>  1 ;
	$time += $dt.minute        +<  5 ;
	$time += $dt.hour          +< 11 ;

	$time += $dt.day-of-month  +< 16 ;
	$time += $dt.month         +< 21 ;
	$time += ($dt.year - 1980) +< 25 ;

	return $time;
}

sub make-canonical-name(Str $name, Bool $forceDir = False, :$SPEC = $*SPEC) is export
{
    # This sub is derived from Archive::Zip::_asZipDirName

    # Return the normalized name as used in a zip file (path
    # separators become slashes, etc.).
    # Will translate internal slashes in path components (i.e. on Macs) to
    # underscores.  Discards volume names.
    # When $forceDir is set, returns paths with trailing slashes 
    #
    # input         output
    # .             '.'
    # ./a           a
    # ./a/b         a/b
    # ./a/b/        a/b
    # a/b/          a/b
    # /a/b/         a/b
    # c:\a\b\c.doc  a/b/c.doc      # on Windows
    # "i/o maps:whatever"   i_o maps/whatever   # on Macs

    my ($volume, $directories, $file) =
      $SPEC.splitpath( $SPEC.canonpath($name), nofile=>$forceDir);
      
    my @dirs = $SPEC.splitdir($directories)>>.subst('/', '_', :g) ; 

    if  @dirs > 0  
        { @dirs.pop if @dirs[*-1] eq '' }   # remove empty component
    @dirs.push: $file // '' ;

    my $normalised-path = @dirs.join: '/' ;

    # Leading directory separators should not be stored in zip archives.
    # Example:
    #   C:\a\b\c\      a/b/c
    #   C:\a\b\c.txt   a/b/c.txt
    #   /a/b/c/        a/b/c
    #   /a/b/c.txt     a/b/c.txt
    $normalised-path .= subst(/ ^ "/" /, '') ;  # remove leading separator

    return $normalised-path;
}
