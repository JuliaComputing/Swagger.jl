#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/..`
source ${DIR}/ver.sh

PLUGINDIR=${PKGDIR}/plugin
SWAGGERDIR=${PKGDIR}/swagger-codegen-${VER_CODEGEN}
CLASSPATH=${PLUGINDIR}/target/julia-swagger-codegen-0.0.2.jar:${SWAGGERDIR}/modules/swagger-codegen-cli/target/swagger-codegen-cli.jar:${CLASSPATH}
#SWAGGERDEBUG="-DdebugModels -DdebugSwagger -DdebugOperations -DdebugSupportingFiles"

echo "java ${SWAGGERDEBUG} -cp ${CLASSPATH} io.swagger.codegen.SwaggerCodegen generate -l julia $*"
java ${SWAGGERDEBUG} -cp ${CLASSPATH} io.swagger.codegen.SwaggerCodegen generate -l julia $*

#if [ -z "$JULIA" ]
#then
#    JULIA=julia
#fi
#
#while getopts "i:c:o:" arg; do
#    case $arg in
#    o)
#        echo "resolving model order in ${OPTARG}"
#        $JULIA -e "include(joinpath("\""$DIR"\"", "\""resolve.jl"\"")); genincludes("\""$OPTARG"\"")"
#        ;;
#    esac
#done
