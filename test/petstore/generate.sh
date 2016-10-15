#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/../..`

${PKGDIR}/plugin/generate.sh -i http://petstore.swagger.io/v2/swagger.json -o ${DIR}/MyPetStore -c ${DIR}/config.json
