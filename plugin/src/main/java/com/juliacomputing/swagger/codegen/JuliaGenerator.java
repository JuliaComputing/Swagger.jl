package com.juliacomputing.swagger.codegen;

import io.swagger.codegen.*;
import io.swagger.models.properties.*;
import io.swagger.models.parameters.*;

import java.util.*;
import java.io.File;

import org.apache.commons.lang3.StringUtils;

public class JuliaGenerator extends DefaultCodegen implements CodegenConfig {

    protected String packageName;

    // source folder where to write the files
    protected String sourceFolder = "src";
    protected String apiVersion = "1.0.0";

    /**
     * Configures the type of generator.
     * 
     * @return  the CodegenType for this generator
     * @see     io.swagger.codegen.CodegenType
     */
    public CodegenType getTag() {
        return CodegenType.CLIENT;
    }

    /**
     * Configures a friendly name for the generator.  This will be used by the generator
     * to select the library with the -l flag.
     * 
     * @return the friendly name for the generator
     */
    public String getName() {
        return "julia";
    }

    /**
     * Returns human-friendly help for the generator.  Provide the consumer with help
     * tips, parameters here
     * 
     * @return A string value for the help message
     */
    public String getHelp() {
        return "Generates a Julia client library.";
    }

    public JuliaGenerator() {
        super();

        supportsInheritance = true;
        supportsMixins = true;

        // set the output folder here
        outputFolder = "generated-code/julia";

        /**
         * Models.  You can write model files using the modelTemplateFiles map.
         * if you want to create one template for file, you can do so here.
         * for multiple files for model, just put another entry in the `modelTemplateFiles` with
         * a different extension
         */
        // models
        modelTemplateFiles.put("model.mustache", ".jl");

        /**
         * Api classes.  You can write classes for each Api file with the apiTemplateFiles map.
         * as with models, add multiple entries with different extensions for multiple files per
         * class
         */
        apiTemplateFiles.put("api.mustache", ".jl");

        supportingFiles.clear();
        supportingFiles.add(new SupportingFile("REQUIRE", "", "REQUIRE"));

        // Template Location: where templates will be read from. The generator will use the resource stream to attempt to read the templates.
        templateDir = "julia";

        // Reserved words.  Override this with reserved words specific to your language
        reservedWords = new HashSet<String> (
            Arrays.asList(
                "if", "else", "elseif", "while", "for", "begin", "end", "quote",
                "try", "catch", "return", "local", "function", "macro", "ccall", "finally", "break", "continue",
                "global", "module", "using", "import", "export", "const", "let", "do", "baremodule",
                "Type", "Enum", "Any", "DataType", "Base"
            )
        );

        // Additional Properties. These values can be passed to the templates and are available in models, apis, and supporting files
        additionalProperties.put("apiVersion", apiVersion);

        // Language Specific Primitives.  These types will not trigger imports by the client generator
        languageSpecificPrimitives = new HashSet<String>(
            Arrays.asList("Int128", "Int64", "Int32", "Int16", "Int8", "UInt128", "UInt64", "UInt32", "UInt16", "UInt8", "Float64", "Float32", "Float16", "Char", "Vector", "Array", "Bool", "String", "Integer", "Nothing")
        );

        typeMapping.clear();
        typeMapping.put("integer", "Int32");
        typeMapping.put("long", "Int64");
        typeMapping.put("float", "Float32");
        typeMapping.put("double", "Float64");
        typeMapping.put("string", "String");
        typeMapping.put("byte", "UInt8");
        typeMapping.put("binary", "Vector{UInt8}");
        typeMapping.put("boolean", "Bool");
        typeMapping.put("number", "Float32");
        typeMapping.put("array", "Vector");
        typeMapping.put("map", "Dict");
        typeMapping.put("date", "Date");
        typeMapping.put("Object", "Any");
        typeMapping.put("DateTime", "DateTime");
        typeMapping.put("File", "String");
        typeMapping.put("UUID", "String");
        typeMapping.put("ByteArray", "Vector{UInt8}");

        cliOptions.clear();
        cliOptions.add(new CliOption(CodegenConstants.PACKAGE_NAME, "Julia package name.").defaultValue("SwaggerClient"));
    }

    public void setPackageName(String packageName) {
        this.packageName = packageName;
    }

    @Override
    public void processOpts() {
        super.processOpts();

        if (additionalProperties.containsKey(CodegenConstants.PACKAGE_NAME)) {
            setPackageName((String) additionalProperties.get(CodegenConstants.PACKAGE_NAME));
        }
        else {
            setPackageName("SwaggerClient");
        }

        additionalProperties.put(CodegenConstants.PACKAGE_NAME, packageName);

        supportingFiles.add(new SupportingFile("client.mustache", "src", packageName + ".jl"));
        supportingFiles.add(new SupportingFile("modelincludes.mustache", "src", "modelincludes.jl"));
    }

    /**
     * Escapes a reserved word as defined in the `reservedWords` array. Handle escaping
     * those terms here.  This logic is only called if a variable matches the reseved words
     * 
     * @return the escaped term
     */
    @Override
    public String escapeReservedWord(String name) {
        if (reservedWords.contains(name)) {
            return "__" + name + "__";  // add underscores to reserved words, and also to obscure it to lessen chances of clashing with any other names
        } else {
            return name;
        }
    }

    /**
     * Location to write model files.
     */
    public String modelFileFolder() {
        return outputFolder + "/" + sourceFolder;
    }

    /**
     * Location to write api files.
     */
    @Override
    public String apiFileFolder() {
        return outputFolder + "/" + sourceFolder;
    }

    @Override
    public String toModelFilename(String name) {
        name = sanitizeName(name);
        name = name.replaceAll("$", "");
        return "model_" + camelize(dropDots(name));
    }

    private static String dropDots(String str) {
        return str.replaceAll("\\.", "_");
    }

    @Override
    public String toApiFilename(String name) {
        name = name.replaceAll("-", "_");
        return "api_" + camelize(name) + "Api";
    }

    @Override
    public String toApiName(String name) {
        if (name.length() == 0) {
            return "DefaultApi";
        }
        // e.g. phone_number_api => PhoneNumberApi
        return camelize(name) + "Api";
    }

    @Override
    public String toParamName(String name) {
        return escapeReservedWord(sanitizeName(name));
    }

    @Override
    public String toApiVarName(String name) {
        return escapeReservedWord(sanitizeName(name));
    }

    @Override
    public String toVarName(String name) {
        return escapeReservedWord(sanitizeName(name));
    }

    /**
     * Sanitize name (parameter, property, method, etc)
     *
     * @param name string to be sanitize
     * @return sanitized string
     */
    @Override
    @SuppressWarnings("static-method")
    public String sanitizeName(String name) {
        if (name == null) {
            LOGGER.error("String to be sanitized is null. Default to ERROR_UNKNOWN");
            return "ERROR_UNKNOWN";
        }

        // if the name is just '$', map it to 'value' for the time being.
        if ("$".equals(name)) {
            return "value";
        }

        name = name.replaceAll("\\[\\]", "");
        name = name.replaceAll("\\[", "_");
        name = name.replaceAll("\\]", "");
        name = name.replaceAll("\\(", "_");
        name = name.replaceAll("\\)", "");
        name = name.replaceAll("\\.", "_");
        name = name.replaceAll("-", "_");
        name = name.replaceAll(" ", "_");
        return name.replaceAll("[^a-zA-Z0-9_{}]", "");
    }

    /**
     * Sanitize tag
     *
     * @param tag Tag
     * @return Sanitized tag
     */
    public String sanitizeTag(String tag) {
        tag = camelize(sanitizeName(tag));

        // tag starts with numbers
        if (tag.matches("^\\d.*")) {
            tag = "Class" + tag;
        }

        return tag;
    }

    @Override
    public String toModelName(String name) {
        name = sanitizeName(name); // FIXME: a parameter should not be assigned. Also declare the methods parameters as 'final'.
        // remove dollar sign
        name = name.replaceAll("$", "");

        // model name cannot use reserved keyword, e.g. return
        if (isReservedWord(name)) {
            LOGGER.warn(name + " (reserved word) cannot be used as model name. Renamed to " + camelize("model_" + name));
            name = "model_" + name; // e.g. return => ModelReturn (after camelize)
        }

        // model name starts with number
        if (name.matches("^\\d.*")) {
            LOGGER.warn(name + " (model name starts with number) cannot be used as model name. Renamed to " + camelize("model_" + name));
            name = "model_" + name; // e.g. 200Response => Model200Response (after camelize)
        }

        if (!StringUtils.isEmpty(modelNamePrefix)) {
            name = modelNamePrefix + "_" + name;
        }

        if (!StringUtils.isEmpty(modelNameSuffix)) {
            name = name + "_" + modelNameSuffix;
        }

        // camelize the model name
        // phone_number => PhoneNumber
        name = camelize(name);

        return name;
    }

    /**
     * Optional - type declaration.  This is a String which is used by the templates to instantiate your
     * types.  There is typically special handling for different property types
     *
     * @return a string value used as the `dataType` field for model templates, `returnType` for api templates
     */
    @Override
    public String getTypeDeclaration(Property p) {
        if(p instanceof ArrayProperty) {
            ArrayProperty ap = (ArrayProperty) p;
            Property inner = ap.getItems();
            return getSwaggerType(p) + "{" + getTypeDeclaration(inner) + "}";
        }
        else if (p instanceof MapProperty) {
            MapProperty mp = (MapProperty) p;
            Property inner = mp.getAdditionalProperties();
            return getSwaggerType(p) + "{String, " + getTypeDeclaration(inner) + "}";
        }
        return super.getTypeDeclaration(p);
    }

    /**
     * Optional - swagger type conversion.  This is used to map swagger types in a `Property` into 
     * either language specific types via `typeMapping` or into complex models if there is not a mapping.
     *
     * @return a string value of the type or complex model for this property
     * @see io.swagger.models.properties.Property
     */
    @Override
    public String getSwaggerType(Property p) {
        String swaggerType = super.getSwaggerType(p);
        String type = null;
        if(typeMapping.containsKey(swaggerType)) {
            type = typeMapping.get(swaggerType);
            if(languageSpecificPrimitives.contains(type))
                return toModelName(type);
        }
        else {
            type = swaggerType;
        }

        if (type == null) {
            return "Object";
        }
        else {
            return toModelName(type);
        }
    }

    /**
     * Return the default value of the property
     *
     * @param p Swagger property object
     * @return string presentation of the default value of the property
     */
    @Override
    public String toDefaultValue(Property p) {
        if (p instanceof StringProperty) {
            StringProperty dp = (StringProperty) p;
            if (dp.getDefault() != null) {
                return "\"" + dp.getDefault() + "\"";
            }
        } else if (p instanceof BooleanProperty) {
            BooleanProperty dp = (BooleanProperty) p;
            if (dp.getDefault() != null) {
                return dp.getDefault().toString();
            }
        } else if (p instanceof DateProperty) {
            // TODO
        } else if (p instanceof DateTimeProperty) {
            // TODO
        } else if (p instanceof DoubleProperty) {
            DoubleProperty dp = (DoubleProperty) p;
            if (dp.getDefault() != null) {
                return dp.getDefault().toString();
            }
        } else if (p instanceof FloatProperty) {
            FloatProperty dp = (FloatProperty) p;
            if (dp.getDefault() != null) {
                return dp.getDefault().toString();
            }
        } else if (p instanceof IntegerProperty) {
            IntegerProperty dp = (IntegerProperty) p;
            if (dp.getDefault() != null) {
                return dp.getDefault().toString();
            }
        } else if (p instanceof LongProperty) {
            LongProperty dp = (LongProperty) p;
            if (dp.getDefault() != null) {
                return dp.getDefault().toString();
            }
        }

        return "nothing";
    }

    public String escapeUnsafeCharacters(String input) {
        return input;
    }

    /**
     * Escape single and/or double quote to avoid code injection 
     * @param input String to be cleaned up
     * @return string with quotation mark removed or escaped
     */
    public String escapeQuotationMark(String input) {
        return input.replace("\"", "\\\"");
    }

    private String escapeBaseName(String name) {
        name = name.replaceAll("\\$", "\\\\\\$");
        return name;
    }

    @Override
    public CodegenParameter fromParameter(Parameter param, Set<String> imports) {
        CodegenParameter parameter = super.fromParameter(param, imports);
        parameter.baseName = escapeBaseName(parameter.baseName);
        return parameter;
    }

    @Override
    public CodegenProperty fromProperty(String name, Property p) {
        CodegenProperty property = super.fromProperty(name, p);
        property.baseName = escapeBaseName(property.baseName);
        return property;
    }
}
