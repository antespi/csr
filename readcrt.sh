#!/bin/bash

# Errors
E_BAD_PARAMS=51
E_CSR_NOT_FOUND=51

PARAMS=1
OPENSSL=/usr/bin/openssl
CHMOD=/bin/chmod
LESS=/bin/less

if [ ! -x $OPENSSL ]; then
   echo "ERROR : OpenSSL not installed or not found at $OPENSSL"
   exit $E_OPENSSL_NOT_FOUND;
fi

if [ ! $# -eq $PARAMS ]; then
   echo "Usage: $0 <crt_file>"
   exit $E_BAD_PARAMS;
fi

FILE=$1

if [ ! -f "$FILE" ]; then
   echo "ERROR : '$FILE' not found"
   exit $E_CSR_NOT_FOUND;
fi

$OPENSSL x509 -text -noout -in "$FILE" | $LESS



