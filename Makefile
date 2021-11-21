#!/usr/bin/make -f

.PHONY : all install test clean

all:

test:
	git submodule update --init test/framework/
	test/run-all-tests.sh

