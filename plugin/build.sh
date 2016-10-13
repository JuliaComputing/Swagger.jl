#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/..`

if [ ! -d "${PKGDIR}/swagger-codegen" ]; then
    cd ${PKGDIR}
    echo "Cloning swagger-codegen..."
    git clone https://github.com/swagger-api/swagger-codegen.git
    cd ${PKGDIR}/swagger-codegen
    pwd
    echo "Building swagger-codegen..."
    mvn clean package
fi

LIBSRC=${PKGDIR}/swagger-codegen/modules/swagger-codegen-cli/target/lib
LIBDST=${PKGDIR}/plugin/lib/io/swagger
VER_MODELS=1.5.9
VER_CODEGEN=2.2.2
MODELS=${LIBDST}/swagger-models/${VER_MODELS}/swagger-models-${VER_MODELS}.jar
CODEGEN=${LIBDST}/swagger-codegen/${VER_CODEGEN}-SNAPSHOT/swagger-codegen-${VER_CODEGEN}-SNAPSHOT.jar

[ ! -f "${MODELS}" ] && echo "Copying swagger-models jar..." && cp ${LIBSRC}/swagger-models-${VER_MODELS}.jar ${MODELS}
[ ! -f "${CODEGEN}" ] && echo "Copying swagger-codegen jar..." && cp ${LIBSRC}/swagger-codegen-${VER_CODEGEN}-SNAPSHOT.jar ${CODEGEN}

cd ${PKGDIR}/plugin
echo "Building Julia plugin..."
mvn package
echo "Done"
