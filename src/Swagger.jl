module Swagger

using Requests
using HttpCommon
using Compat
using JSON

# collection formats
const COLL_MULTI = "multi"
const COLL_PIPES = "pipes"
const COLL_SSV = "ssv"
const COLL_TSV = "tsv"
const COLL_CSV = "csv"
const COLL_DLM = Dict{String,String}([COLL_PIPES=>"|", COLL_SSV=>" ", COLL_TSV=>"\t", COLL_CSV=>","])

immutable SwaggerException <: Exception
    reason::String
end

immutable ApiException <: Exception
    status::Int
    reason::String
    resp::Response

    function ApiException(resp::Response; reason::String="")
        isempty(reason) && (reason = get(STATUS_CODES, resp.status, reason))
        new(resp.status, reason, resp)
    end
end

immutable Client
    root::String
    headers::Dict{String,String}

    function Client(root::String, headers::Dict{String,String}=Dict{String,String}())
        new(root, headers)
    end
end

set_user_agent(client::Client, ua::String) = set_header("User-Agent", ua)
set_cookie(client::Client, ck::String) = set_header("Cookie", ck)
set_header(client::Client, name::String, value::String) = (client.headers[name] = value)

immutable Ctx
    method::String
    return_type::Type
    resource::String
    auth::Vector{String}

    path::Dict{String,String}
    query::Dict{String,String}
    header::Dict{String,String}
    form::Dict{String,String}
    file::Dict{String,String}
    body::Any

    function Ctx(client::Client, method::String, return_type, resource::String, auth::Vector{String})
        resource = joinpath(client.root, resource)
        headers = copy(client.headers)
        new(method, return_type, resource, auth, Dict{String,String}(), Dict{String,String}(), headers, Dict{String,String}(), Dict{String,String}(), nothing)
    end
end

is_json_mime(mime::String) = ismatch(r"(?i)application/json(;.*)?", mime)

function select_header_accept(accepts::Vector{String})
    isempty(accepts) && (return "")
    for accept in accepts
        is_json_mime(accept) && (return accept)
    end
    return join(accepts, ", ")
end

function select_header_content_type(ctypes::Vector{String})
    isempty(ctypes) && (return "application/json")
    for ctype in ctypes
        is_json_mime(ctype) && (return ctype)
    end
    return ctypes[1]
end

function set_header_accept(ctx::Ctx, accepts::Vector{String})
    accept = select_header_accept(accepts)
    !isempty(accept) && (ctx.header["Accept"] = accept)
    return nothing
end

function set_header_content_type(ctx::Ctx, ctypes::Vector{String})
    ctx.header["Content-Type"] = select_header_content_type(ctypes)
    return nothing
end

function set_param{T}(params::Dict{String,String}, name::String, value::Nullable{T}; collection_format=nothing)
    isnull(value) && return
    set_param(params, name, get(value); collection_format=collection_format)
end

function set_param(params::Dict{String,String}, name::String, value; collection_format::String="")
    if !isa(Vector, value) || isempty(collection_format)
        params[name] = string(value)
    else
        dlm = get(COLL_DLM, collection_format, "")
        isempty(dlm) && throw(SwaggerException("Unsupported collection format $collection_format"))
        params[name] = join(map((x)->string(x)), dlm)
    end
end

function prep_args(ctx::Ctx)
    kwargs = Dict{Symbol,Any}()
    isempty(ctx.query) || (kwargs[:query] = ctx.query)
    isempty(ctx.header) || (kwargs[:headers] = ctx.header)
    isempty(ctx.form) || (kwargs[:data] = ctx.form)
    if !isempty(ctx.file)
        kwargs[:files] = FileParam[]
        for (_k,_v) in ctx.file
            push!(kwargs[:files], FileParam(readall(_v), "", _k))
        end
    end
    if ctx.body !== nothing
        isempty(ctx.form) || throw(SwaggerException("Can not send both form-encoded data and body data"))
        kwargs[:data] = is_json_mime(get(ctx.header, "Content-Type", "application/json")) ? to_json(ctx.body) : ctx.body
    end
    return kwargs
end

response(::Type{Void}, resp::Response) = nothing
function response{T}(::Type{T}, resp::Response)
    ctype = get(resp.headers, "Content-Type", "application/json")
    response(T, is_json_mime(ctype) ? JSON.parse(Compat.String(resp.data)) : resp.data)
end
response{T<:Real}(::Type{T}, data::Vector{UInt8}) = parse(T, Compat.String(data))
response{T<:Compat.String}(::Type{T}, data::Vector{UInt8}) = Compat.String(data)
response{T}(::Type{T}, data::T) = data
response{T}(::Type{T}, data) = convert(T, data)
response{T}(::Type{T}, data::Dict{String,Any}) = from_json(T, data)
response{T,V}(::Type{Vector{T}}, data::Vector{V}) = map((v)->response(T, v), data)

function exec(ctx::Ctx)
    resource_path = replace(ctx.resource, "{format}", "json")
    for (k,v) in ctx.path
        resource_path = replace(resource_path, "{$k}", v)
    end

    # TODO: use auth_settings for authentication
    kwargs = prep_args(ctx)
    httpmethod = getfield(Requests, Symbol(lowercase(http_method)))
    resp = httpmethod(resource_path; kwargs...)

    (200 <= resp.status <= 206) || throw(ApiException(resp))

    response(response_type, resp)
end

from_json{T}(::Type{T}, json::Dict{String,Any}) = from_json(T(), json)

function from_json(o, json::Dict{String,Any})
    nmap = name_map(o)
    for name in intersect(keys(nmap), keys(json))
        from_json(o, nmap[name], json[name])
    end
    nothing
end

to_json(o) = JSON.json(o)

name_map{T}(o::T) = name_map(T)

end # module Swagger
