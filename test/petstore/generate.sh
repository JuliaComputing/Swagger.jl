#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/../..`

${PKGDIR}/plugin/generate.sh -i http://127.0.0.1/v2/swagger.json -o ${DIR}/MyPetStore -c ${DIR}/config.json
