# Swagger Codegen for Julia

## Overview
This is a Julia plugin and code generator to generate your own client library with Swagger.

## What's Swagger?
The goal of Swagger™ is to define a standard, language-agnostic interface to REST APIs which allows both humans and computers to discover and understand the capabilities of the service without access to source code, documentation, or through network traffic inspection. When properly defined via Swagger, a consumer can understand and interact with the remote service with a minimal amount of implementation logic. Similar to what interfaces have done for lower-level programming, Swagger removes the guesswork in calling the service.


Check out [OpenAPI-Spec](https://github.com/OAI/OpenAPI-Specification) for additional information about the Swagger project, including additional libraries with support for other languages and more. 

## How do I use this?
To build the project, run this:

```
plugin/build.sh
```

A single jar file (julia-swagger-codegen-0.0.2.jar) will be produced in `plugin/target`.  You can now use that with codegen:

```
java -cp /path/to/swagger-codegen-cli.jar:/path/to/julia-swagger-codegen-0.0.2.jar io.swagger.codegen.Codegen -l julia -i /path/to/swagger.yaml -o ./test -c config.json
```

The configuration file (`config.json`) can have the following options:

- `packageName`: the Julia package to generate (`SwaggerClient` by default)
