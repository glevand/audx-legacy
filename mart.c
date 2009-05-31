/*
 *  mart - music cover art lookup
 *
 *  Copyright 2009 Geoff Levand
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License, Version 2 as
 *  published by the Free Software Foundation.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 * Amazon product images:
 *  http://images.amazon.com/images/P/[ASIN].01.[FORMAT]
 *  ASIN = amazon shop id number
 *  TZZZZZZZ = default image
 *  THUMBZZZ = thumbnail image
 *  MZZZZZZZ = medium image
 *  LZZZZZZZ = large image
*/

#if defined(HAVE_CONFIG_H)
#include "config.h"
#endif

#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <musicbrainz3/mb_c.h>

static void print_version(void)
{
	printf("mart (" PACKAGE_NAME ") " PACKAGE_VERSION "\n");
}

static void print_usage(void)
{
	print_version();
	printf(
"music cover art lookup\n"
"Usage: mart [-a, --artist artist] [-f, --first-only] [-h, --help]\n"
"            [ -t, --title title] [-v, --verbose] [-V, --version]\n");
}

/**
 * enum opt_value - Tri-state options variables.
 */

enum opt_value {opt_undef = 0, opt_yes, opt_no};

/**
 * struct opts - Values from command line options.
 */

struct opts {
	const char *artist;
	enum opt_value show_help;
	enum opt_value first_only;
	const char *title;
	unsigned int verbosity;
	enum opt_value show_version;
};

/**
 * opts_parse - Parse the command line options.
 */

static int opts_parse(struct opts* opts, int argc, char *argv[])
{
	static const struct option long_options[] = {
		{"artist",      required_argument, NULL, 'a'},
		{"first-only",  no_argument,       NULL, 'f'},
		{"help",        no_argument,       NULL, 'h'},
		{"title",       required_argument, NULL, 't'},
		{"verbose",     no_argument,       NULL, 'v'},
		{"version",     no_argument,       NULL, 'V'},
		{ NULL, 0, NULL, 0},
	};
	static const char short_options[] = "a:fht:vV";
	static const struct opts default_values;

	*opts = default_values;

	while(1) {
		int c = getopt_long(argc, argv, short_options, long_options,
			NULL);

		if (c == EOF)
			break;

		switch(c) {
		case 'a':
			opts->artist = optarg;
			break;
		case 'h':
			opts->show_help = opt_yes;
			break;
		case 'f':
			opts->first_only = opt_yes;
			break;
		case 't':
			opts->title = optarg;
			break;
		case 'v':
			opts->verbosity++;
			break;
		case 'V':
			opts->show_version = opt_yes;
			break;
		default:
			opts->show_help = opt_yes;
			return -1;
		}
	}

	return optind != argc;
}

int main(int argc, char *argv[])
{
	int result;
	struct opts opts;
	MbReleaseFilter mbfilter;
	MbQuery mbq;
	MbResultList mblist;
	unsigned int i;
	unsigned int end;
	unsigned int count;

	result = opts_parse(&opts, argc, argv);

	if (result | (!opts.artist && !opts.title)) {
		print_usage();
		return EXIT_FAILURE;
	}

	if (opts.show_help == opt_yes) {
		print_usage();
		return EXIT_SUCCESS;
	}

	if (opts.show_version == opt_yes) {
		print_version();
		return EXIT_SUCCESS;
	}

	mbfilter = mb_release_filter_new();
	if (opts.artist)
		mbfilter = mb_release_filter_artist_name(mbfilter, opts.artist);
	if (opts.title)
		mbfilter = mb_release_filter_title(mbfilter, opts.title);

	mbq = mb_query_new(NULL, NULL);
	mblist = mb_query_get_releases(mbq, mbfilter);

	mb_release_filter_free(mbfilter);
	mbfilter = NULL;
	mb_query_free(mbq);
	mbq = NULL;

        for (count = i = 0, end = mb_result_list_get_size(mblist);
		i < end; i++) {
		MbRelease mbr;
		char asin[16];

		mbr = mb_result_list_get_release(mblist, i);
		mb_release_get_asin(mbr, asin, sizeof(asin));
		mb_release_free(mbr);

		if (opts.verbosity)
			fprintf(stderr, "[%s - %s]: %i '%s'\n", opts.artist,
				opts.title, i, asin);

		if (*asin) {
			count++;
			printf("http://images.amazon.com"
				"/images/P/%s.01.TZZZZZZZ\n", asin);

			if (opts.first_only == opt_yes)
				break;
		}
	}

	mb_result_list_free(mblist);

	if (count == 0) {
		fprintf(stderr, "[%s - %s]: no ASIN info found\n", opts.artist,
			opts.title);
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
