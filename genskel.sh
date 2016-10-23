#!/usr/bin/env sh

# Generate skeleton code for Julia Swagger code generator
# Do not run this unless upgrading to a Swagger version/interface
java -jar modules/swagger-codegen-cli/target/swagger-codegen-cli.jar meta -o ./plugin -n julia -p com.juliacomputing.swagger.codegen
