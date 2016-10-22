
AssociativeWrapper{T<:SwaggerModel}(o::T) = AssociativeWrapper(o, filter(n->isset_field(o,n), fieldnames(T)))

to_json(o) = JSON.json(o)

from_json{T}(::Type{Nullable{T}}, json::Dict{String,Any}) = from_json(T, json)
from_json{T}(::Type{T}, json::Dict{String,Any}) = from_json(T(), json)
from_json{T<:Dict}(::Type{T}, json::Dict{String,Any}) = convert(T, json)

function from_json{T<:SwaggerModel}(o::T, json::Dict{String,Any})
    nmap = name_map(o)
    for name in intersect(keys(nmap), keys(json))
        from_json(o, nmap[name], json[name])
    end
    o
end

function from_json{T<:SwaggerModel}(o::T, name::Symbol, json::Dict{String,Any})
    ftype = fieldtype(T, name)
    fval = from_json(ftype, json)
    setfield!(o, name, convert(ftype, fval))
    o
end
from_json{T}(o::T, name::Symbol, v) = (setfield!(o, name, convert(fieldtype(T, name), v)); o)
