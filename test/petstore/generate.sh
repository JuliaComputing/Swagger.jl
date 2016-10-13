#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/../..`

${PKGDIR}/plugin/generate.sh -Dmodels=User,Pet -Dapis -DsupportingFiles -i http://petstore.swagger.io/v2/swagger.json -o ${DIR}/MyPetStore -c ${DIR}/config.json
