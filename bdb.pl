#!/usr/local/bin/perl

use feature say;
use DB_File;
use BerkeleyDB;

$file=$ARGV[0];
$act=$ARGV[1];
$key=$ARGV[2];
$val=$ARGV[3];
usage() unless $file;

if ($act eq 'create') {
	die 'no version to create' unless $key;
	die 'no type to create' unless $val;
	if ($key == 1) {
		tie %h, "DB_File", $file, O_RDWR|O_CREAT, 0644, ${'DB_'.uc($val)}  or die "$!\n";
	} elsif ($key eq 'current') {
		tie %h, 'BerkeleyDB::'.ucfirst($val), -Filename => $file, -Flags => DB_CREATE;
	}
	untie %h;
	exit;
}

die 'no file' unless -f $file;

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

if ($db = tie %h, BerkeleyDB::Hash, -Filename => $file, -Flags => $flagx) { $ver = 'current'; $type='hash'; }
elsif ($db = tie %h, BerkeleyDB::Btree, -Filename => $file, -Flags => $flagx) { $ver = 'current'; $type = 'btree'; }
elsif ($db = tie %h, "DB_File", $file, $flag1, 0644, $DB_HASH) { $ver = '1'; $type = "hash"; }
elsif ($db = tie %h, "DB_File", $file, $flag1, 0644, $DB_BTREE) { $ver = '1'; $type = "btree"; }
else { die "unknown type"; }

# use \0 in key val when share with other c app like postfix
if ($ver eq 'current') { $key .= "\0"; $val .= "\0"; }
unless ($act) { # view all
	while ((my $key, my $val) = each %h) { say "$key $val"; }
	exit;
}
usage() unless $act;

if ($act eq 'type') {
	$ver= $BerkeleyDB::db_version if $ver eq 'current';
	say "version $ver $type";
	exit;
}

usage() unless $key;
if ($act eq 'get') {
	 say $h{$key} if $h{$key};
} elsif ($act eq 'add') {
	if ($h{$key}) { die "$file key '$key' exists"; } else { $h{$key}=$val;}
} elsif ($act eq 'del') {
	delete $h{$key};
	say "Can't delete $key" if $h{$key};
} elsif ($act eq 'count') {
	if ($h{$key}) {
		$h{$key}+= $val;
		$h{$key}.="\0" if $ver eq 'current';
	} else {
		$h{$key}=$val;
	}
} elsif ($act eq 'change') {
	die "file key '$key' doesn't exist" unless $h{$key};
	$h{$key}=$val;
} elsif ($act eq 'delist') {
	use File::Slurp;
	@lines = read_file "$key";
	for my $rec (@lines) {
		chomp $rec;
		$rec .= "\0" if $ver eq 'current';
		delete $h{$rec};
		say "Can't delete $rec" if $h{$rec};
	}
}

untie %h;

sub usage {
	say "usage:
	\$file (view all)
	\$file get \$key (read a key)
	\$file add \$key \$val
	\$file count \$key \$val (add or increase \$val)
	\$file change \$key \$newval
	\$file del \$key
	\$file delist \$list (text file lists IP to delete line by line)
	\$file create \$version (1 or $var) \$type (btree or hash)
	\$file clear
	\$file type (show db type)";
	exit;
}
