#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGINDIR=${DIR}/../plugin
export CLASSPATH=`cat ${PLUGINDIR}/classpath`

echo "java ${SWAGGERDEBUG} -cp ${CLASSPATH} io.swagger.codegen.SwaggerCodegen generate -l julia $*"
java ${SWAGGERDEBUG} -cp ${CLASSPATH} io.swagger.codegen.SwaggerCodegen generate -l julia $*
