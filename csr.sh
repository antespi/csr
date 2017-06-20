#!/bin/bash

# Errors
E_BAD_PARAMS=51
E_CONFIG_NOT_FOUND=52
E_OPENSSL_NOT_FOUND=53
E_BAD_CONFIG=54
E_DSA_PARAMFILE=11
E_DSA_KEY=12
E_DSA_ENCKEY=13
E_RSA_KEY=21
E_RSA_ENCKEY=22
E_CSR=31

PARAMS=1
OPENSSL=/usr/bin/openssl
CHMOD=/bin/chmod
LESS=/bin/less

CONFIG_FILE='subject.conf'
OPENSSL_FILE='openssl.conf'

if [ ! -x $OPENSSL ]; then
   echo "ERROR : OpenSSL not installed or not found at $OPENSSL"
   exit $E_OPENSSL_NOT_FOUND;
fi

if [ ! $# -eq $PARAMS ]; then
   echo "Usage: $0 <subdomain.domain.com>"
   exit $E_BAD_PARAMS;
fi

if [ -f "$CONFIG_FILE" ]; then
   . "$CONFIG_FILE"
else
   echo "ERROR : No $CONFIG_FILE file found, please copy '$CONFIG_FILE.dist' to '$CONFIG_FILE' and configure your data"
   exit $E_CONFIG_NOT_FOUND;
fi

if [ ! -f $OPENSSL_FILE ] && [ -z "$SUBJECT" ]; then
    if [ -z "$COUNTRY" ]; then echo "ERROR : Country not set"; exit $E_BAD_CONFIG; fi
    if [ -z "$STATE" ]; then echo "ERROR : State not set"; exit $E_BAD_CONFIG; fi
    if [ -z "$LOCATION" ]; then echo "ERROR : Location not set"; exit $E_BAD_CONFIG; fi
    if [ -z "$ORG" ]; then echo "ERROR : Organization not set"; exit $E_BAD_CONFIG; fi
    if [ -z "$ORGUNIT" ]; then echo "ERROR : Organization unit not set"; exit $E_BAD_CONFIG; fi
fi

DOMAIN=$1

if [ "$SIGNALG" != 'sha256' ] && [ "$SIGNALG" != 'sha1' ] && [ "$SIGNALG" != 'md5' ]; then
    echo "NOTICE : Bad signature algorithm, using sha1"
    SIGNALG='sha1'
fi

if [ "$KEYALG" != 'dsa' ] && [ "$KEYALG" != 'rsa' ]; then
    echo "NOTICE : Bad key algorithm, using rsa"
    KEYALG='rsa'
fi

if [ "$BITS" != '512' ] && [ "$BITS" != '1024' ] && [ "$BITS" != '2048' ] && [ "$BITS" != '4096' ]; then
    echo "NOTICE : Bad key lenght, using 2048"
    BITS='2048'
fi

if [ "$KEYALG" == 'dsa' ]; then
   if [ ! -f $DOMAIN.dsaparam.pem ]; then
      echo "[*] Creating DSA Param file for $DOMAIN..."
      if ! $OPENSSL dsaparam -out $DOMAIN.dsaparam.pem $BITS; then
         echo "ERROR : Generating DSA param file"
         exit $E_DSA_PARAMFILE;
      fi
   fi
   echo "[*] Creating DSA Key..."
   if ! $OPENSSL gendsa -out $DOMAIN.key $DOMAIN.dsaparam.pem; then
      echo "ERROR : Generating key"
      exit $E_DSA_KEY;
   fi
   echo "[*] Encrypt DSA Key with AES 256 CBC..."
   if ! $OPENSSL dsa -aes256 -in $DOMAIN.key -out $DOMAIN.key.enc; then
      echo "ERROR : Encrypting key"
      exit $E_DSA_ENCKEY;
   fi

elif [ "$KEYALG" == 'rsa' ]; then

   echo "[*] Creating RSA Key..."
   if ! $OPENSSL genrsa -out $DOMAIN.key $BITS; then
      echo "ERROR : Generating key"
      exit $E_RSA_KEY;
   fi
   echo "[*] Encrypt RSA Key with AES 256 CBC..."
   if ! $OPENSSL rsa -aes256 -in $DOMAIN.key -out $DOMAIN.key.enc; then
      echo "ERROR : Encrypting key"
      exit $E_RSA_ENCKEY;
   fi
fi

echo "[*] Creating CSR..."
args=""
if [ -z "$SUBJECT" ]; then
    SUBJECT="/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/OU=$ORGUNIT/CN=$DOMAIN"
fi
if [ -f $OPENSSL_FILE ]; then
    args="-config $OPENSSL_FILE"
else
    args="-subj $SUBJECT"
fi
if ! $OPENSSL req $args -new -key $DOMAIN.key -out $DOMAIN.csr -${SIGNALG}; then
    echo "ERROR : Generating csr"
    exit $E_CSR;
fi

echo "OK - Certificate CSR created successfully"
$CHMOD 600 $DOMAIN.key $DOMAIN.csr
$OPENSSL req -text -noout -verify -in $DOMAIN.csr | $LESS

echo
echo "In order to decrypt private key in destination server, execute:"
echo "# openssl $KEYALG -in $DOMAIN.key.enc -out $DOMAIN.key"
echo
echo "The passphrase will be requested, so keep it in mind ;)"

