# Types in Julia need to be loaded in correct order for dependencies to be resolved.
# This utility script determines the correct order for including generated models.
#
# It parses each model and keeps a table of the other models it refers to.
# At the end it walks through the dependency tree and outputs include statements in the correct order.

function typedeps(file::String)
    modulename = split(basename(file), ".")[1]
    contents = readstring(file)
    wrapped = """module $modulename
        $contents
    end"""
    typedeps(parse(wrapped))
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
        issubtype(T, Number) || issubtype(T, String)
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
        info("    depends on ", DT)
        push!(deps, DT)
    end
end

function typedeps(M::Expr)
    mod = findtype(M, :module)
    modblock = findtype(mod, :block)
    typ = findtype(modblock, :type)
    typedecl = findtype(typ, :<:)
    typeblock = findtype(typ, :block)

    typename = typedecl.args[1]
    @assert typedecl.args[2] === :SwaggerModel

    deps = Vector{Symbol}()
    for d in typeblock.args
        if d.head === :(::)
            nullable_type = d.args[2]
            if nullable_type.head === :curly && nullable_type.args[1] === :Nullable
                pushdeps(deps, nullable_type.args[2])
            end
        end
    end
    (typename, deps)
end

srcdir(folder) = joinpath(folder, "src")
fullsrcpath(folder, file) = joinpath(srcdir(folder), file)

function gentypetree(folder::String)
    info("reading $folder/src/model_*.jl")
    TT = Dict{Symbol, Vector{Symbol}}()
    TF = Dict{Symbol,String}()
    for file in readdir(srcdir(folder))
        if startswith(file, "model_")
            info("parsing ", file)
            typename, deps = typedeps(fullsrcpath(folder, file))
            TT[typename] = deps
            TF[typename] = file
        end
    end
    TT, TF
end

satisfied(typename, TT, generated) = (isempty(TT[typename]) || (typename in generated))

function gen(typename, TT, TF, generated, io=STDOUT)
    (typename in generated) && return
    if !satisfied(typename, TT, generated)
        for T in TT[typename]
            gen(T, TT, TF, generated, io)
        end
    end
    println(io, "include(\"", TF[typename], "\")")
    push!(generated, typename)
    nothing
end

function genincludes(folder::String)
    generated = Set{Symbol}()
    TT, TF = gentypetree(folder)

    open(fullsrcpath(folder, "modelincludes.jl"), "w") do inclfile
        for typename in keys(TT)
            gen(typename, TT, TF, generated, inclfile)
        end
    end

    nothing
end
