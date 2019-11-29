#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$TRAVIS_OS_NAME" = "linux" ]
then
    ${DIR}/../../plugin/generate.sh -i http://127.0.0.1/v2/swagger.json -o ${DIR}/MyPetStore -c ${DIR}/config.json
else
    ${DIR}/../../plugin/generate.sh -i https://petstore.swagger.io/v2/swagger.json -o ${DIR}/MyPetStore -c ${DIR}/config.json
fi
