#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/..`
PLUGINDIR=${PKGDIR}/plugin
SWAGGERDIR=${PKGDIR}/swagger-codegen
CLASSPATH=${PLUGINDIR}/target/julia-swagger-codegen-0.0.1.jar:${SWAGGERDIR}/modules/swagger-codegen-cli/target/swagger-codegen-cli.jar:${CLASSPATH}
#SWAGGERDEBUG="-DdebugModels -DdebugSwagger -DdebugOperations -DdebugSupportingFiles"

java ${SWAGGERDEBUG} -cp ${CLASSPATH} io.swagger.codegen.SwaggerCodegen generate -l julia $*

while getopts "i:c:o:" arg; do
    case $arg in
    o)
        echo "resolving model order in ${OPTARG}"
        julia -e "include(joinpath("\""$DIR"\"", "\""resolve.jl"\"")); genincludes("\""$OPTARG"\"")"
        ;;
    esac
done
