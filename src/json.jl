# JSONWrapper for Swagger models handles
# - null fields
# - field names that are Julia keywords
struct JSONWrapper{T<:SwaggerModel} <: AbstractDict{Symbol, Any}
    wrapped::T
    flds::Vector{Symbol}
end

JSONWrapper(o::T) where {T<:SwaggerModel} = JSONWrapper(o, filter(n->hasproperty(o,n), propertynames(T)))

getindex(w::JSONWrapper, s::Symbol) = getproperty(w.wrapped, s)
keys(w::JSONWrapper) = w.flds
length(w::JSONWrapper) = length(w.flds)

function iterate(w::JSONWrapper, state...)
    result = iterate(w.flds, state...)
    if result === nothing
        return result
    else
        name,nextstate = result
        val = getproperty(w.wrapped, name)
        return (name=>val, nextstate)
    end
end

lower(o::T) where {T<:SwaggerModel} = JSONWrapper(o)

to_json(o) = JSON.json(o)

from_json(::Type{Union{Nothing,T}}, json::Dict{String,Any}) where {T} = from_json(T, json)
from_json(::Type{T}, json::Dict{String,Any}) where {T} = from_json(T(), json)
from_json(::Type{T}, json::Dict{String,Any}) where {T <: Dict} = convert(T, json)
from_json(::Type{T}, j::Dict{String,Any}) where {T <: String} = to_json(j)
from_json(::Type{Any}, j::Dict{String,Any}) = j

function from_json(o::T, json::Dict{String,Any}) where {T <: SwaggerModel}
    jsonkeys = [Symbol(k) for k in keys(json)]
    for name in intersect(propertynames(T), jsonkeys)
        from_json(o, name, json[String(name)])
    end
    o
end

function from_json(o::T, name::Symbol, json::Dict{String,Any}) where {T <: SwaggerModel}
    ftype = property_type(T, name)
    fval = from_json(ftype, json)
    setfield!(o, field_name(T,name), convert(ftype, fval))
    o
end
from_json(o::T, name::Symbol, v) where {T} = (setfield!(o, field_name(T,name), convert(property_type(T, name), v)); o)
function from_json(o::T, name::Symbol, v::Vector) where {T}
    # in Julia we can not support JSON null unless the element type is explicitly set to support it
    ftype = property_type(T, name)
    vtype = isa(ftype, Union) ? ((ftype.a === Nothing) ? ftype.b : ftype.a) : isa(ftype, Vector) ? ftype : Union{}
    (Nothing <: eltype(vtype)) || filter!(x->x!==nothing, v)
    setfield!(o, field_name(T,name), convert(property_type(T, name), v))
    o
end
from_json(o::T, name::Symbol, v::Nothing) where {T} = o
