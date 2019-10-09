#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKGDIR=`readlink -e ${DIR}/..`

PLUGINDIR=${PKGDIR}/plugin
export CLASSPATH=`cat ${PLUGINDIR}/classpath`
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
