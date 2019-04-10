# Types in Julia need to be loaded in correct order for dependencies to be resolved.
# This utility script determines the correct order for including generated models.
#
# It parses each model and keeps a table of the other models it refers to.
# At the end it walks through the dependency tree and outputs include statements in the correct order.

using Dates

function typedeps(file::String)
    modulename = split(basename(file), ".")[1]
    contents = read(file, String)
    wrapped = """module $modulename
        $contents
    end"""
    typedeps(Meta.parse(wrapped))
end

function findtype(X::Expr, what::Symbol)
    (X.head === what) && (return X)
    for x in X.args
        isa(x, Expr) && (x.head === what) && return x
    end
    error("no $what in expression")
end

function isbasetype(DT)
    try
        T = eval(DT)
        (T <: Number) || (T <: String) || (T === Any) || (T === DateTime)
    catch
        false
    end
end

function pushdeps(deps, DT)
    if isa(DT, Expr) && DT.args[1] === :Vector
        pushdeps(deps, DT.args[2])
    elseif isa(DT, Expr) && DT.args[1] === :Dict
        pushdeps(deps, DT.args[2])
        pushdeps(deps, DT.args[3])
    elseif !isbasetype(DT)
        @info("    depends on $DT")
        push!(deps, DT)
    end
end

function typedeps(M::Expr)
    mod = findtype(M, :module)
    modblock = findtype(mod, :block)
    deps = Vector{Symbol}()

    try
        # attempt to parse as a regular struct
        typ = findtype(modblock, :struct)
        typedecl = findtype(typ, :<:)
        typeblock = findtype(typ, :block)

        typename = typedecl.args[1]
        @assert typedecl.args[2] === :SwaggerModel

        for d in typeblock.args
            if isa(d, Expr) && (d.head === :(::))
                nullable_type = d.args[2]
                if (nullable_type.head === :curly) && (nullable_type.args[1] === :Union) && (length(nullable_type.args) === 3) && (:Nothing in nullable_type.args)
                    pushdeps(deps, first(filter(x->(x !== :Nothing) && (x !== :Union), nullable_type.args)))
                end
            end
        end
        (typename, deps)
    catch
        # else it might be an alias
        const_decl = findtype(modblock, :const)
        const_args = const_decl.args[1]
        @assert const_args.head == :(=)
        typename = const_args.args[1]
        pushdeps(deps, const_args.args[2])
        (typename, deps)
    end
end

srcdir(folder) = joinpath(folder, "src")
fullsrcpath(folder, file) = joinpath(srcdir(folder), file)

function gentypetree(folder::String)
    @info("reading $folder/src/model_*.jl")
    TT = Dict{Symbol, Vector{Symbol}}()
    TF = Dict{Symbol,String}()
    for file in readdir(srcdir(folder))
        if startswith(file, "model_")
            @info("parsing $file")
            typename, deps = typedeps(fullsrcpath(folder, file))
            TT[typename] = deps
            TF[typename] = file
        end
    end
    TT, TF
end

satisfied(typename, TT, generated) = (isempty(TT[typename]) || (typename in generated))

function gen(typename, TT, TF, generated, genstack, io=STDOUT)
    (typename in generated) && return
    if !satisfied(typename, TT, generated)
        push!(genstack, typename)
        for T in TT[typename]
            if T == typename
                @info("found recursive type use in $T")
            else
                if T in genstack
                    error("circular type references are not supported, found $T and $typename")
                end
                gen(T, TT, TF, generated, genstack, io)
            end
        end
    end
    println(io, "include(\"", TF[typename], "\")")
    push!(generated, typename)
    (typename in genstack) && delete!(genstack, typename)
    nothing
end

function genincludes(folder::String)
    generated = Set{Symbol}()
    genstack = Set{Symbol}()
    TT, TF = gentypetree(folder)

    open(fullsrcpath(folder, "modelincludes.jl"), "w") do inclfile
        for typename in keys(TT)
            gen(typename, TT, TF, generated, genstack, inclfile)
        end
    end

    nothing
end
