# Swagger Codegen for the julia library

## Overview
This is a Julia plugin and code generator to generate your own client library with Swagger.

## What's Swagger?
The goal of Swagger™ is to define a standard, language-agnostic interface to REST APIs which allows both humans and computers to discover and understand the capabilities of the service without access to source code, documentation, or through network traffic inspection. When properly defined via Swagger, a consumer can understand and interact with the remote service with a minimal amount of implementation logic. Similar to what interfaces have done for lower-level programming, Swagger removes the guesswork in calling the service.


Check out [OpenAPI-Spec](https://github.com/OAI/OpenAPI-Specification) for additional information about the Swagger project, including additional libraries with support for other languages and more. 

## How do I use this?
The folder structure of this project is something along these lines:

```
.
|- README.md    // this file
|- pom.xml      // build script
|-- src
|--- main
|---- java
|----- com.juliacomputing.swagger.codegen.JuliaGenerator.java // generator file
|---- resources
|----- julia // template files
|----- META-INF
|------ services
|------- io.swagger.codegen.CodegenConfig
```

Install or build `swagger-codegen` (https://github.com/swagger-api/swagger-codegen).

```
git clone https://github.com/swagger-api/swagger-codegen.git
cd swagger-codegen
mvn clean package
```

Provision the correct version of `swagger-codegen` and `swagger-models` libraries and update `pom.xml` if required.
You should have the libraries placed somewhere like this:

```
lib/io/swagger/swagger-codegen/2.2.2-SNAPSHOT/swagger-codegen-2.2.2-SNAPSHOT.jar
lib/io/swagger/swagger-models/1.5.9/swagger-models-1.5.9.jar
```

To build the project, run this:

```
mvn package
```

A single jar file will be produced in `target`.  You can now use that with codegen:

```
java -cp /path/to/swagger-codegen-cli.jar:/path/to/your.jar io.swagger.codegen.Codegen -l julia -i /path/to/swagger.yaml -o ./test
```
