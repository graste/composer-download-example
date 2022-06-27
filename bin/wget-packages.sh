#!/usr/bin/env bash
set -eo pipefail
[ "$DEBUG" ] && set -x

# determine application dir if necessary
if [ -z "${APP_DIR}" ] ; then
    APP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
fi

# default packackes file
if [ -z "${WGET_PACKAGES_FILE}" ] ; then
    WGET_PACKAGES_FILE="${APP_DIR}/package.txt"
fi

if [ "$1" = "-v" ]; then
    DEBUG=1
fi

[ "$DEBUG" ] && echo "[INFO] Downloading packages listed in: ${WGET_PACKAGES_FILE}"

if [ -f "${WGET_PACKAGES_FILE}" ] ; then
    [ "$DEBUG" ] && echo "[INFO] Downloading packages listed in: ${WGET_PACKAGES_FILE}"
fi
# remove lines with comments from the packages file
TEMPFILE=$(mktemp)
grep -v -e"^$" -e"^\s*#" ${WGET_PACKAGES_FILE} > ${TEMPFILE}

# number of errors during script execution
errors=0

# per line: download file to target path and check sha1 checksum
while read LINE
do
    URL=$(echo "$LINE" | cut -d' ' -f1)
    FILE=$(echo "$LINE" | cut -d' ' -f2)
    SHA1=$(echo "$LINE" | cut -d' ' -f3)

    # validation (haha)
    if [ $URL = $FILE ] ; then
        [ "$DEBUG" ] && echo "[ERROR] Invalid wget download instruction. URL and filename are the same:" $LINE
        ((error+=1))
        continue
    fi
    if [ $FILE = $SHA1 ] ; then
        [ "$DEBUG" ] && echo "[ERROR] Invalid wget download instruction. Filename and checksum are the same:" $LINE
        ((error+=1))
        continue
    fi
    if [ $URL = $SHA1 ] ; then
        [ "$DEBUG" ] && echo "[ERROR] Invalid wget download instruction. Sha1 value the same as the URL:" $LINE
        ((error+=1))
        continue
    fi

    # check if local file already exists and has the correct checksum
    if [ -f $FILE ] ; then
        CHECKSUM=$(sha1sum $FILE)
        CHECKSUM=$(echo "$CHECKSUM" | cut -d' ' -f1)
        if [ "$CHECKSUM" = "$SHA1" ] ; then
            [ "$DEBUG" ] && echo "[SUCCESS] File already downloaded correctly:" $FILE
            continue
        else
            [ "$DEBUG" ] && echo "[INFO] File checksum mismatch. Fetching file:" $FILE
        fi
    fi

    # download file
    wget --continue -O $FILE -- $URL
    if [ $? -ne 0 ]; then
        [ "$DEBUG" ] && echo "[ERROR] Download failed from:" $URL
        ((error+=1))
    fi

    # verify downloaded file
    echo "[INFO] Calculating checksum for file:" $FILE
    CHECKSUM=$(sha1sum $FILE)
    CHECKSUM=$(echo "$CHECKSUM" | cut -d' ' -f1)
    if [ "$CHECKSUM" = "$SHA1" ] ; then
        [ "$DEBUG" ] && echo "[SUCCESS] Download successful:" $FILE
    else
        [ "$DEBUG" ] && echo "[ERROR] Checksum error for downloaded file:" $FILE
        [ "$DEBUG" ] && echo "[ERROR] Expected   =>" $SHA1
        [ "$DEBUG" ] && echo "[ERROR] Calculated =>" $CHECKSUM
        ((error+=1))
    fi

    #if [ "${error}" -gt 0 ]; then
    #    rm $FILE
    #fi
done < $TEMPFILE

if [[ ${error} -gt 0 ]]; then
    [ "$DEBUG" ] && echo "[ERROR] Errors while downloading and verifying packages from ${WGET_PACKAGES_FILE}"
    exit 1
fi

rm $TEMPFILE
