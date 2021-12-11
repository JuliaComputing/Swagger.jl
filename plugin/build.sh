#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}/../plugin
echo "Building Julia plugin..."
mvn package
mvn dependency:resolve dependency:build-classpath -Dmdep.outputFile=classpath.tmp
echo "`cat classpath.tmp`:$DIR/target/julia-swagger-codegen-0.0.6.jar" > classpath
rm -f ./classpath.tmp
echo "Build successful"
echo "---------------------------------------"
echo "CLASSPATH=`cat classpath`"
echo "---------------------------------------"
echo "Done"
