#!/usr/local/bin/perl
# read and edit Berkeley DB both 1.x and higher versions
use DB_File;
use BerkeleyDB;

my $file=$ARGV[0];
my $act=$ARGV[1];
my $key_in = $ARGV[2];
my $val = $ARGV[3];

my (%h, $bdb, $type);
my $ver1 = '1';
my $verx = 'current';
# connection flag
my $flag1 = O_RDWR;
my $flagx = '';

# no argument
usage() unless $file;

# creating needs a special option and must be done before no-file die
if ($act eq 'create') {
	die 'no version to create' unless $key_in;
	die 'no type to create' unless $val;
	if ($key_in == 1) {
		tie %h, "DB_File", $file, O_RDWR|O_CREAT, 0644, ${'DB_'.uc($val)}  or die "$!\n";
	} elsif ($key_in eq 'current') {
		tie %h, 'BerkeleyDB::'.ucfirst($val), -Filename => $file, -Flags => DB_CREATE;
	}
	untie %h;
	exit;
}

# no-file die before change
die "$file doesn't exist" unless -f $file;

if ($bdb = tie %h, "BerkeleyDB::Hash", -Filename => $file, -Flags => $flagx) { $vers = $verx; $type='Hash'; }
elsif ($bdb = tie %h, "BerkeleyDB::Btree", -Filename => $file, -Flags => $flagx) { $vers = $verx; $type = 'Btree'; }
elsif ($bdb = tie %h, "DB_File", $file, $flag1, 0644, $DB_HASH) { $vers = $ver1; $type = "HASH"; }
elsif ($bdb = tie %h, "DB_File", $file, $flag1, 0644, $DB_BTREE) { $vers = $ver1; $type = "BTREE"; }
else { die "unknown type"; }

# accept 1 argument
# view all
unless ($act) {
	while ((my $k, my $v) = each %h) { print "$k $v\n"; }
	exit;
}

# accept 2 arguments
if ($act eq 'clear') {
	# don't clear when first connected becuse type is unknown and DB_TRUNCATE allow hash connection to clear then change btree to hash
	untie %h;
	# backup before erasing
	use File::Copy;
	copy $file, '/tmp/';
	# reconnect
	$bdb = tie %h, "BerkeleyDB::$type", -Filename => $file, -Flags => DB_TRUNCATE if $vers eq $verx;
	$bdb = tie %h, "DB_File", $file, O_RDWR|O_TRUNC, 0644, ${'DB_'.$type} if $vers eq $ver1;
	untie %h;
	exit;
} elsif ($act eq 'type') {
	$vers = $BerkeleyDB::db_version if $vers eq 'current';
	print "version $vers $type\n";
	exit;
} elsif ($act eq 'keys') {
	print "$_\n" for keys(%h);
	exit;
}

# accept 3 arguments
usage() unless $key_in;

my $caret = '^' if $act eq 'prefix' || $act eq 'delprefix';
my $pattern = $caret . quotemeta $key_in;	# don't match x.x. with x.xx
if ($act eq 'prefix' || $act eq 'grep') {	# match keys from beginning or part
	for my $k (keys %h) { print "$k\n" if $k =~ /$pattern/; }
} elsif ($act eq 'delprefix' || $act eq 'delpart') { # delete keys by matching from beginning or part
	for my $k (keys %h) {
		if ($k =~ /$pattern/) {
			delete $h{$k};
			print "Can't delete $k\n" if $h{$k};
		}
	}
}

# use \0 in key val when share with other c app like postfix, but don't add it with grep or prefix above
if ($vers eq $verx) { $key_in .= "\0"; $val .= "\0"; }

if ($act eq 'get') {
	 print "$h{$key_in}\n" if $h{$key_in};
} elsif ($act eq 'add') {
	if ($h{$key_in}) { die "$file key '$key_in' exists"; } else { $h{$key_in}=$val;}
} elsif ($act eq 'del') {
	delete $h{$key_in};
	print "Can't delete $key_in\n" if $h{$key_in};
} elsif ($act eq 'count') {
	if ($h{$key_in}) {
		$h{$key_in}+= $val;
		$h{$key_in}.="\0" if $vers eq $verx;
	} else {
		$h{$key_in}=$val;
	}
} elsif ($act eq 'change') {
	die "file key '$key_in' doesn't exist" unless $h{$key_in};
	$h{$key_in}=$val;
} elsif ($act eq 'delist') {
	require File::Slurp;
	File::Slurp->import( read_file );
	my @lines = read_file("$key_in");
	for my $rec (@lines) {
		chomp $rec;
		$rec .= "\0" if $vers eq $verx;
		delete $h{$rec};
		print "Can't delete $rec\n" if $h{$rec};
	}
}

untie %h;

sub usage {
	print "usage:
	\$file (view all)
	\$file keys (view all keys)
	\$file get \$key (read a key)
	\$file prefix \$key (search keys by prefix)
	\$file grep \$key (search keys by part)
	\$file add \$key \$val
	\$file count \$key \$val (add or increase \$val. Empty \$val reset to 0)
	\$file change \$key \$newval
	\$file del \$key
	\$file delprefix \$key (delete keys by prefix)
	\$file delpart \$key (delete keys by part)
	\$file delist \$list (text file lists IP to delete line by line)
	\$file create \$version ($ver1 or $verx) \$type (btree or hash)
	\$file clear
	\$file type (show db type)\n";
	exit;
}
