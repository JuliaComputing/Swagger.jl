#!/usr/bin/env sh

java -jar modules/swagger-codegen-cli/target/swagger-codegen-cli.jar meta -o ./plugin -n julia -p com.juliacomputing.swagger.codegen
