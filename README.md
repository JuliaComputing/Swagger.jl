# Swagger

[![Build Status](https://travis-ci.org/JuliaComputing/Swagger.jl.svg?branch=master)](https://travis-ci.org/JuliaComputing/Swagger.jl)
[![Coverage Status](https://coveralls.io/repos/JuliaComputing/Swagger.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/JuliaComputing/Swagger.jl?branch=master)
[![codecov.io](http://codecov.io/github/JuliaComputing/Swagger.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaComputing/Swagger.jl?branch=master)

This is a Julia plugin and code generator to generate your own client library with Swagger.

The goal of Swagger™ is to define a standard, language-agnostic interface to REST APIs which allows both humans and computers to discover and understand the capabilities of the service without access to source code, documentation, or through network traffic inspection. When properly defined via Swagger, a consumer can understand and interact with the remote service with a minimal amount of implementation logic. Similar to what interfaces have done for lower-level programming, Swagger removes the guesswork in calling the service.

Check out [OpenAPI-Spec](https://github.com/OAI/OpenAPI-Specification) for additional information about the Swagger project, including additional libraries with support for other languages and more.

## How do I use this?

The code generation step required by this package is best done on linux. Generated julia code can of course be run on any platform. 

### Building

First, you need to build the Swagger Java libraries. Ensure you have Java and maven installed, and the `java` and `mvn` commands available on the path. Then, from the directory where Swagger.jl has been downloads, run this:

```
plugin/build.sh
```

A single jar file (julia-swagger-codegen-0.0.2.jar) will be produced in `plugin/target`.

You can now use that for codegen.

Note: problems have been reported while building with JDK 9 on MacOS likely because of [this issue](https://bugs.eclipse.org/bugs/show_bug.cgi?id=534460)

### Code Generation:

Use the supplied script `plugin/generate.sh` and point it to the specification file and a configuration file. E.g.:

```
${SWAGGERDIR}/plugin/generate.sh config-i ${SPECDIR}/${SPECFILE} -o ${GENDIR} -c config.json
```
_where_
`SWAGGERDIR` is the location of this package
`SPECDIR` is the directory where the openapi specification file resides
`SPECFILE` the name of the openapi specification file from which you are generating Julia code
`GENDIR` the directory where the generated Julia code will be written

Typically, you would generate the files into a `src` directory for a package. The generated code is ready to be used as a Julia package directly (So long as the package name is passed correctly -- see below)

The configuration file (`.json`) can have the following options:

- `packageName`: the Julia package to generate (`SwaggerClient` by default)
