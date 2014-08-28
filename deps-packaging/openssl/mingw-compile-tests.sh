#!/bin/sh

TESTS="evp_test randtest rsa_test shatest sha1test sha256t sha512t md5test"

FIXME: compiler

for i in $TESTS; do
  $(DEB_HOST_GNU_TYPE)-gcc -o $i.exe $i.c -I../include -I.. ../libcrypto.a -lgdi32
done
