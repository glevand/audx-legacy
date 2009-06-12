#!/usr/bin/perl -w
#
# Copyright 2008 Geoff Levand
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#

package audx;
require Exporter;

use strict;
use warnings;

our $VERSION = 1.00;
our @ISA = qw(Exporter);
our @EXPORT = qw(dir_make file_exists file_remove file_info_parse
	file_info_print tags_from_metaflac tags_print flac_decode
	faac_encode nero_encode);

sub dir_make (@)
{
	my ($dir, $verbosity) = @_;

	# Prepare for shell: 'The B-52's' -> 'The B-52'\''s'.

	$dir =~ s/'/'\\''/g;

	my $cmd = q(mkdir -p ') . $dir . q(');

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 4);

	my $result = system($cmd);

	if ($result) {
		print STDERR ("error: @" . $cmd . "@ failed.\n");
		exit 1;
	}
}

sub file_exists (@)
{
	my ($file) = @_;

	return ( -f $file );
}

sub file_remove (@)
{
	my ($file) = @_;

	$file =~ s/'/'\\''/g;
	return system(q(rm ') . $file . q('));
}

# file_info_parse - collect info from path and file name.

sub file_info_parse (@)
{
	my ($info, $file, $verbosity) = @_;

	# %{albumartist}/%{albumtitle}/%{artist} - %{number} - %{title}.%{extension}
	# prefix: '/home/geoff/music/collection/flac/'
	# path:  '10,000 Maniacs/Blind Man's Zoo/'
	# name:  '10,000 Maniacs - 01 - Eat For Two'

	$info->{full} = $file;

	$info->{full} =~ m{^(.+/)([^/]+/[^/]+/)([^/]+)\.(flac)$};

	$info->{prefix} = $1;
	$info->{path} = $2;
	$info->{name} = $3;
	$info->{ext} = $4;

	$info->{path} =~ m{^([^/]+)/([^/]+)/$};

	$info->{albumartist} = $1;
	$info->{albumtitle} = $2;

	$info->{name} =~ m{^(.+) - ([0-9][0-9]) - (.+)$};

	$info->{artist} = $1;
	$info->{number} = $2;
	$info->{title} = $3;
}

sub file_info_print (@)
{
	my ($info, $verbosity) = @_;

	if ($verbosity) {
		print STDOUT ("--------------------------------------------\n");
		print STDOUT ("i-file:        '" . $info->{full} . "'\n");
		print STDOUT ("i-prefix:      '" . $info->{prefix} . "'\n");
		print STDOUT ("i-path:        '" . $info->{path} . "'\n");
		print STDOUT ("i-name:        '" . $info->{name} . "'\n");
		print STDOUT ("i-ext:         '" . $info->{ext} . "'\n");
	}
	if ($verbosity >= 2) {
		print STDOUT ("i-albumartist: '"
			. $info->{albumartist} . "'\n");
		print STDOUT ("i-albumtitle:  '" . $info->{albumtitle} . "'\n");
		print STDOUT ("i-number:      '" . $info->{number} . "'\n");
		print STDOUT ("i-title:       '" . $info->{title} . "'\n");
	}
}

sub mart_from_info (@)
{
	my ($info, $verbosity) = @_;

	print STDOUT ("i-albumartist: '" . $info->{albumartist} . "'\n");
	print STDOUT ("i-albumtitle:  '" . $info->{albumtitle} . "'\n");

	my $cmd = "metaflac --list --block-type=VORBIS_COMMENT '" . $in_file
		. "'";

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 4);

	my $meta = qx($cmd);
	chomp($meta);

}

sub tags_from_metaflac (@)
{
	my ($tags, $in_file, $verbosity) = @_;

	# Prepare for shell: 'I'm Eighteen' -> 'I'\''m Eighteen'.

	$in_file =~ s/'/'\\''/g;

	my $cmd = "metaflac --list --block-type=VORBIS_COMMENT '" . $in_file
		. "'";

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 4);

	my $meta = qx($cmd);
	chomp($meta);

	$tags->{meta} = $meta if ($verbosity >= 3);

	$tags->{artist} = $1  if ($meta =~ m{: ARTIST=(.*)}i);
	$tags->{album} = $1   if ($meta =~ m{: ALBUM=(.*)}i);
	$tags->{title} = $1   if ($meta =~ m{: TITLE=(.*)}i);
	$tags->{track} = $1   if ($meta =~ m{: TRACKNUMBER=(.*)}i);
	$tags->{disk} = $1    if ($meta =~ m{: DISKNUMBER=(.*)}i);
	$tags->{date} = $1    if ($meta =~ m{: DATE=(.*)}i);
	$tags->{genre} = $1   if ($meta =~ m{: GENRE=(.*)}i);
	$tags->{comment} = $1 if ($meta =~ m{: COMMENT=(.*)}i);
}

sub tags_print (@)
{
	my ($tags, $verbosity) = @_;

	return if (!$verbosity);

	print STDOUT ("t-meta: @" . $tags->{meta} . "@\n")
		if ($verbosity >= 3 && defined($tags->{meta}));
	print STDOUT ("t-artist:      '" . $tags->{artist} . "'\n");
	print STDOUT ("t-album:       '" . $tags->{album} . "'\n");
	print STDOUT ("t-title:       '" . $tags->{title} . "'\n");
	print STDOUT ("t-track:       '" . $tags->{track} . "'\n");
	print STDOUT ("t-disk:        '" . $tags->{disk} . "'\n")
		if (defined($tags->{disk}));
	print STDOUT ("t-date:        '" . $tags->{date} . "'\n")
		if (defined($tags->{date}));
	print STDOUT ("t-genre:       '" . $tags->{genre} . "'\n")
		if (defined($tags->{genre}));
	print STDOUT ("t-comment:     '" . $tags->{comment} . "'\n")
		if (defined($tags->{comment}));
}

sub flac_decode (@)
{
	my ($in_file, $out_file, $dry_run, $verbosity) = @_;

	my $silent = ($verbosity > 1) ? "" : "--silent ";
	my $sink = ($verbosity > 1) ? "" : " 2> /dev/null";

	# Prepare for shell: 'Livin' Thing' -> 'Livin'\'' Thing'.

	$in_file =~ s/'/'\\''/g;
	$out_file =~ s/'/'\\''/g;

	my $cmd = q(flac --decode --decode-through-errors --force ) . $silent
		. q(--output-name=') . $out_file . q(' ') . $in_file . q(')
		. $sink;

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 4);

	my $result;

	if (!$dry_run) {
		$result = system($cmd);
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": cmd: @" . $cmd
			. "@ failed.\n") if $result;
	}

	return !!$result;
}

sub faac_encode (@)
{
	my ($in_file, $tags, $quality, $out_file, $dry_run, $verbosity) = @_;
	my $result;
	my $tag;

	my $sink = ($verbosity > 1) ? "" : " 2> /dev/null";

	$in_file =~ s/'/'\\''/g;
	$out_file =~ s/'/'\\''/g;

	if (!defined($tags->{artist}) || !defined($tags->{album})
		|| !defined($tags->{title}) || !defined($tags->{track})) {
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": bad tags.\n");
		exit 1;
	}

	my $cmd = q(faac ) . $quality;

	$tag = $tags->{artist};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( --artist ') . $tag . q(');

	$tag = $tags->{album};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( --album ') . $tag . q(');

	$tag = $tags->{title};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( --title ') . $tag . q(');

	$cmd .= q( --track ) . $tags->{track};

	$cmd .= q( --year ) . $tags->{date} if (defined($tags->{date}));

	if (defined($tags->{genre})) {
		$tag = $tags->{genre};
		$tag =~ s/'/'\\''/g;
		$cmd .= q( --genre ') . $tag . q(');
	}

	$cmd .= q( --disc ) . $tags->{disc} if (defined($tags->{disc}));

	if (defined($tags->{comment})) {
		$tag = $tags->{comment};
		$tag =~ s/'/'\\''/g;
		$cmd .= q( --comment ') . $tag . q(');
	}

	$cmd .= q( -o ') . $out_file . q(' ') . $in_file . q(') . $sink;

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 2);

	if (!$dry_run) {
		$result = system($cmd);
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": cmd: @" . $cmd
			. "@ failed.\n") if $result;
	}

	return !!$result;
}

sub nero_encode (@)
{
	my ($in_file, $tags, $quality, $out_file, $dry_run, $verbosity) = @_;
	my $result;
	my $cmd;

	my $sink = ($verbosity > 1) ? "" : " 2> /dev/null";

	$in_file =~ s/'/'\\''/g;
	$out_file =~ s/'/'\\''/g;

	if (!defined($tags->{artist}) || !defined($tags->{album})
		|| !defined($tags->{title}) || !defined($tags->{track})) {
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": bad tags.\n");
	}

	$cmd = q(neroAacEnc -lc ) . $quality . q( -of ') . $out_file
		. q(' -if ') . $in_file . q(') . $sink;

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 2);

	if (!$dry_run) {
		$result = system($cmd);
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": cmd: @" . $cmd
			. "@ failed.\n") if $result;
	}

	return !!$result;
}

sub nero_tag (@)
{
	my ($tags, $file, $dry_run, $verbosity) = @_;
	my $result;
	my $tag;
	my $cmd;

	my $sink = ($verbosity > 1) ? "" : " 2> /dev/null";

	$file =~ s/'/'\\''/g;

	if (!defined($tags->{artist}) || !defined($tags->{album})
		|| !defined($tags->{title}) || !defined($tags->{track})) {
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": bad tags.\n");
	}

	$cmd = q(neroAacTag ') . $file . q(');

	$tag = $tags->{artist};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( -meta:artist=') . $tag . q(');

	$tag = $tags->{album};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( -meta:album=') . $tag . q(');

	$tag = $tags->{title};
	$tag =~ s/'/'\\''/g;
	$cmd .= q( -meta:title=') . $tag . q(');

	$cmd .= q( -meta:track=) . $tags->{track};

	$cmd .= q( -meta:year=) . $tags->{date} if (defined($tags->{date}));

	if (defined($tags->{genre})) {
		$tag = $tags->{genre};
		$tag =~ s/'/'\\''/g;
		$cmd .= q( -meta:genre=') . $tag . q(');
	}

	$cmd .= q( -meta:disc=) . $tags->{disc} if (defined($tags->{disc}));

	if (defined($tags->{comment})) {
		$tag = $tags->{comment};
		$tag =~ s/'/'\\''/g;
		$cmd .= q( -meta:comment=') . $tag . q(');
	}

	#  totaltracks
	#  totaldiscs
	#  url
	#  copyright
	#  lyrics
	#  credits
	#  rating
	#  label
	#  composer
	#  isrc
	#  mood
	#  tempo

	print STDOUT ("cmd: @" . $cmd . "@\n") if ($verbosity >= 2);

	if (!$dry_run) {
		$result = system($cmd);
		print STDERR ( __PACKAGE__ . ": " . __LINE__ . ": cmd: @" . $cmd
			. "@ failed.\n") if $result;
	}

	return !!$result;
}

1;

__END__
