#!/usr/local/bin/perl
use feature 'say';
use DB_File;
use BerkeleyDB;

my $file=$ARGV[0];
my $act=$ARGV[1];
my $key_in = $ARGV[2];
my $val = $ARGV[3];

my (%h, $flagx, $flag1, $db, $type); # initialize strict variables
my $ver1 = '1';
my $verx = 'current';

usage() unless $file;

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

die "$file doesn't exist" unless -f $file;

if ($act eq 'clear') {
	$flagx = DB_TRUNCATE ;
	$flag1=O_RDWR|O_TRUNC;
	# backup first
	use File::Copy;
	copy $file, '/tmp/';
} else {
	$flag1 = O_RDWR;
	$flagx = '';
}

if ($db = tie %h, "BerkeleyDB::Hash", -Filename => $file, -Flags => $flagx) { $vers = $verx; $type='hash'; }
elsif ($db = tie %h, "BerkeleyDB::Btree", -Filename => $file, -Flags => $flagx) { $vers = $verx; $type = 'btree'; }
elsif ($db = tie %h, "DB_File", $file, $flag1, 0644, $DB_HASH) { $vers = $ver1; $type = "hash"; }
elsif ($db = tie %h, "DB_File", $file, $flag1, 0644, $DB_BTREE) { $vers = $ver1; $type = "btree"; }
else { die "unknown type"; }

unless ($act) { # view all
	while ((my $k, my $v) = each %h) { say "$k $v"; }
	exit;
}

exit if $act eq 'clear';

if ($act eq 'type') {
	$vers = $BerkeleyDB::db_version if $vers eq 'current';
	say "version $vers $type";
	exit;
}

usage() unless $key_in;

my $caret = '^' if $act eq 'prefix' || $act eq 'delprefix';
my $pattern = $caret . quotemeta $key_in;	# don't match x.x. with x.xx
if ($act eq 'prefix' || $act eq 'grep') {	# match keys from beginning or part
	for my $k (keys %h) { say $k if $k =~ /$pattern/; }
} elsif ($act eq 'delprefix' || $act eq 'delpart') { # delete keys by matching from beginning or part
	for my $k (keys %h) {
		if ($k =~ /$pattern/) {
			delete $h{$k};
			say "Can't delete $k" if $h{$k};
		}
	}
}

# use \0 in key val when share with other c app like postfix, but don't add it with grep or prefix above
if ($vers eq $verx) { $key_in .= "\0"; $val .= "\0"; }

if ($act eq 'get') {
	 say $h{$key_in} if $h{$key_in};
} elsif ($act eq 'add') {
	if ($h{$key_in}) { die "$file key '$key_in' exists"; } else { $h{$key_in}=$val;}
} elsif ($act eq 'del') {
	delete $h{$key_in};
	say "Can't delete $key_in" if $h{$key_in};
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
	use File::Slurp;
	my @lines = read_file "$key_in";
	for my $rec (@lines) {
		chomp $rec;
		$rec .= "\0" if $vers eq $verx;
		delete $h{$rec};
		say "Can't delete $rec" if $h{$rec};
	}
}

untie %h;

sub usage {
	say "usage:
	\$file (view all)
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
	\$file type (show db type)";
	exit;
}
