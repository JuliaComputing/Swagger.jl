#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKG_DIR=`readlink -e ${DIR}/..`
source ${DIR}/ver.sh

BUILD_DIR=${PKG_DIR}/swagger-codegen-${VER_CODEGEN}
LIBSRC=${BUILD_DIR}/modules/swagger-codegen-cli/target/lib
LIBDST=${PKG_DIR}/plugin/lib/io/swagger
MODELS=${LIBDST}/swagger-models/${VER_MODELS}/swagger-models-${VER_MODELS}.jar
CODEGEN=${LIBDST}/swagger-codegen/${VER_CODEGEN}/swagger-codegen-${VER_CODEGEN}.jar

if [ ! -d "${BUILD_DIR}" ] || [ ! -f "${MODELS}" ] || [ ! -f "${CODEGEN}" ]
then
    echo "Cleaning stale folders..."
    rm -rf "${BUILD_DIR}"
    echo "Downloading swagger-codegen..."
    curl -s -L https://github.com/swagger-api/swagger-codegen/archive/v${VER_CODEGEN}.tar.gz | tar -C "${PKG_DIR}" -x -z -f -
    echo "Building swagger-codegen..."
    cd "${BUILD_DIR}" && mvn clean package
fi

mkdir -p ${LIBDST}/swagger-models/${VER_MODELS}
mkdir -p ${LIBDST}/swagger-codegen/${VER_CODEGEN}

[ ! -f "${MODELS}" ] && echo "Copying swagger-models jar..." && cp ${LIBSRC}/swagger-models-${VER_MODELS}.jar ${MODELS}
[ ! -f "${CODEGEN}" ] && echo "Copying swagger-codegen jar..." && cp ${LIBSRC}/swagger-codegen-${VER_CODEGEN}.jar ${CODEGEN}

cd ${PKG_DIR}/plugin
echo "Building Julia plugin..."
mvn package
echo "Done"
