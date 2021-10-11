# collection formats
const COLL_MULTI = "multi"  # aliased to CSV, as multi is not supported by Requests.jl (https://github.com/JuliaWeb/Requests.jl/issues/140)
const COLL_PIPES = "pipes"
const COLL_SSV = "ssv"
const COLL_TSV = "tsv"
const COLL_CSV = "csv"
const COLL_DLM = Dict{String,String}([COLL_PIPES=>"|", COLL_SSV=>" ", COLL_TSV=>"\t", COLL_CSV=>",", COLL_MULTI=>","])

const DATETIME_FORMATS = (Dates.DateFormat("yyyy-mm-dd HH:MM:SS.sss"), Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.sss"), Dates.DateFormat("yyyy-mm-ddTHH:MM:SSZ"))
const DATE_FORMATS = (Dates.DateFormat("yyyy-mm-dd"),)

const DEFAULT_TIMEOUT_SECS = 5*60

function convert(::Type{DateTime}, str::String)
    # strip off timezone, as Julia DateTime does not parse it
    if '+' in str
        str = split(str, '+')[1]
    end
    # truncate micro/nano seconds to milliseconds, as Julia DateTime does not parse it
    if '.' in str
        uptosec,subsec = split(str, '.')
        if length(subsec) > 3
            str = uptosec * "." * subsec[1:3]
        end
    end
    for fmt in DATETIME_FORMATS
        try
            return DateTime(str, fmt)
        catch
            # try next format
        end
    end
    throw(SwaggerException("Unsupported DateTime format: $str"))
end

function convert(::Type{Date}, str::String)
    for fmt in DATETIME_FORMATS
        try
            return Date(str, fmt)
        catch
            # try next format
        end
    end
    throw(SwaggerException("Unsupported Date format: $str"))
end

struct SwaggerException <: Exception
    reason::String
end

struct ApiException <: Exception
    status::Int
    reason::String
    resp::HTTP.Response

    function ApiException(resp::HTTP.Response; reason::String="")
        isempty(reason) && (reason = get(HTTP.Messages.STATUS_MESSAGES, resp.status, reason))
        new(resp.status, reason, resp)
    end
end

struct Client
    root::String
    headers::Dict{String,String}
    get_return_type::Function   # user provided hook to get return type from response data
    clntoptions::Dict

    function Client(root::String; headers::Dict{String,String}=Dict{String,String}(), get_return_type::Function=(default,data)->default, sslconfig=nothing, require_ssl_verification=true)
        endswith(root, '/') && @warn("Root URI ($root) terminates with '/'. Ensure that resource paths do not begin with '/'. This is unconventional.")
        clntoptions = Dict{Symbol,Any}(:status_exception=>false, :retries=>0, :require_ssl_verification=>require_ssl_verification)
        (sslconfig === nothing) || (clntoptions[:sslconfig] = sslconfig)
        new(root, headers, get_return_type, clntoptions)
    end
end

set_user_agent(client::Client, ua::String) = set_header(client, "User-Agent", ua)
set_cookie(client::Client, ck::String) = set_header(client, "Cookie", ck)
set_header(client::Client, name::String, value::String) = (client.headers[name] = value)

struct Ctx
    client::Client
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
    timeout::Int

    function Ctx(client::Client, method::String, return_type, resource::String, auth, body=nothing; timeout::Int=DEFAULT_TIMEOUT_SECS)
        resource = client.root * resource
        headers = copy(client.headers)
        new(client, method, return_type, resource, auth, Dict{String,String}(), Dict{String,String}(), headers, Dict{String,String}(), Dict{String,String}(), body, timeout)
    end
end

is_json_mime(mime::T) where {T <: AbstractString} = ("*/*" == mime) || occursin(r"(?i)application/json(;.*)?", mime) || occursin(r"(?i)application/(.*)-patch\+json(;.*)?", mime)

function select_header_accept(accepts::Vector{String})
    isempty(accepts) && (return "application/json")
    for accept in accepts
        is_json_mime(accept) && (return accept)
    end
    return join(accepts, ", ")
end

function select_header_content_type(ctypes::Vector{String})
    isempty(ctypes) && (return "application/json")
    for ctype in ctypes
        is_json_mime(ctype) && (return (("*/*" == ctype) ? "application/json" : ctype))
    end
    return ctypes[1]
end

set_header_accept(ctx::Ctx, accepts::Vector{T}) where {T} = set_header_accept(ctx, convert(Vector{String}, accepts))
function set_header_accept(ctx::Ctx, accepts::Vector{String})
    accept = select_header_accept(accepts)
    !isempty(accept) && (ctx.header["Accept"] = accept)
    return nothing
end

set_header_content_type(ctx::Ctx, ctypes::Vector{T}) where {T} = set_header_content_type(ctx, convert(Vector{String}, ctypes))
function set_header_content_type(ctx::Ctx, ctypes::Vector{String})
    ctx.header["Content-Type"] = select_header_content_type(ctypes)
    return nothing
end

set_param(params::Dict{String,String}, name::String, value::Nothing; collection_format=nothing) = nothing

function set_param(params::Dict{String,String}, name::String, value::Union{Nothing,T}; collection_format=nothing) where {T}
    (value === nothing) && return

    if !isa(value, Vector) || isempty(collection_format)
        params[name] = string(value)
    else
        dlm = get(COLL_DLM, collection_format, "")
        isempty(dlm) && throw(SwaggerException("Unsupported collection format $collection_format"))
        params[name] = join(map((x)->string(x), value), dlm)
    end
end

function prep_args(ctx::Ctx)
    kwargs = copy(ctx.client.clntoptions)
    isempty(ctx.file) && (ctx.body === nothing) && isempty(ctx.form) && !("Content-Length" in keys(ctx.header)) && (ctx.header["Content-Length"] = "0")
    isempty(ctx.query) || (kwargs[:query] = ctx.query)
    headers = ctx.header
    body = nothing
    if !isempty(ctx.form)
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        body = HTTP.URIs.escapeuri(ctx.form)
    end
    if !isempty(ctx.file)
        (body === nothing) && (body = Dict())
        idx = 1
        for (_k,_v) in ctx.file
            body["multi$idx"] = HTTP.Multipart(_k, open(_v))
            idx += 1
        end
    end
    if ctx.body !== nothing
        (isempty(ctx.form) && isempty(ctx.file)) || throw(SwaggerException("Can not send both form-encoded data and a request body"))
        if is_json_mime(get(ctx.header, "Content-Type", "application/json"))
            body = to_json(ctx.body)
        elseif ("application/x-www-form-urlencoded" == ctx.header["Content-Type"]) && isa(ctx.body, Dict)
            body = HTTP.URIs.escapeuri(ctx.body)
        elseif isa(ctx.boody, SwaggerModel) && isempty(get(ctx.header, "Content-Type", ""))
            headers["Content-Type"] = "application/json"
            body = to_json(ctx.body)
        else
            body = ctx.body
        end
    end
    # set the timeout
    kwargs[:readtimeout] = ctx.timeout
    return body, kwargs
end

response(::Type{Nothing}, resp::HTTP.Response, body=resp.body) = nothing::Nothing
response(::Type{T}, resp::HTTP.Response, body=resp.body) where {T <: Real} = response(T, body)::T
response(::Type{T}, resp::HTTP.Response, body=resp.body) where {T <: String} = response(T, body)::T
function response(::Type{T}, resp::HTTP.Response, body=resp.body) where {T}
    ctype = HTTP.header(resp, "Content-Type", "application/json")
    (length(body) == 0) && return T()
    v = response(T, is_json_mime(ctype) ? JSON.parse(String(body)) : body)
    v::T
end
response(::Type{T}, data::Vector{UInt8}) where {T<:Real} = parse(T, String(data))
response(::Type{T}, data::Vector{UInt8}) where {T<:String} = String(data)::T
response(::Type{T}, data::T) where {T} = data
response(::Type{T}, data) where {T} = convert(T, data)
response(::Type{T}, data::Dict{String,Any}) where {T} = from_json(T, data)::T
response(::Type{T}, data::Dict{String,Any}) where {T<:Dict} = convert(T, data)
response(::Type{Vector{T}}, data::Vector{V}) where {T,V} = [response(T, v) for v in data]

struct ChunkReader
    http
    buffered_input::Base.BufferStream
    buffer_task::Task

    function ChunkReader(http)
        buffered_input = Base.BufferStream()
        buffer_task = @async try
            write(buffered_input, http)
        catch ex
            if !isa(ex, EOFError)
                @error("exception reading http stream", exception=(ex, catch_backtrace()))
                rethrow(ex)
            end
        finally
            close(buffered_input)
        end
        new(http, buffered_input, buffer_task)
    end
end

function Base.iterate(iter::ChunkReader, _state=nothing)
    if eof(iter.buffered_input)
        return nothing
    else
        out = IOBuffer()
        while !eof(iter.buffered_input)
            byte = read(iter.buffered_input, UInt8)
            (byte == codepoint('\n')) && break
            write(out, byte)
        end
        return (take!(out), iter)
    end
end

function do_request(ctx::Ctx, stream::Bool=false; stream_to::Union{Channel,Nothing}=nothing)
    resource_path = replace(ctx.resource, "{format}"=>"json")
    for (k,v) in ctx.path
        resource_path = replace(resource_path, "{$k}"=>v)
    end

    # TODO: use auth_settings for authentication
    body, kwargs = prep_args(ctx)
    if stream
        @assert stream_to !== nothing
    end

    resp = nothing

    function process_stream(http)
        if body !== nothing
            write(http, body)
        end
        resp = startread(http)
        for chunk in ChunkReader(http)
            return_type = ctx.client.get_return_type(ctx.return_type, String(copy(chunk)))
            data = response(return_type, resp, chunk)
            put!(stream_to, data)
        end
    end

    if stream
        HTTP.open(process_stream, uppercase(ctx.method), HTTP.URIs.URI(resource_path), ctx.header; kwargs...)
        close(stream_to)
    else
        if body !== nothing
            resp = HTTP.request(uppercase(ctx.method), HTTP.URIs.URI(resource_path), ctx.header, body; kwargs...)
        else
            resp = HTTP.request(uppercase(ctx.method), HTTP.URIs.URI(resource_path), ctx.header; kwargs...)
        end
    end

    return resp
end

function exec(ctx::Ctx, stream_to::Union{Channel,Nothing}=nothing)
    stream = stream_to !== nothing
    resp = do_request(ctx, stream; stream_to=stream_to)

    (200 <= resp.status <= 206) || throw(ApiException(resp))

    return stream ? resp : response(ctx.client.get_return_type(ctx.return_type, resp), resp)
end

property_type(::Type{T}, name::Symbol) where {T<:SwaggerModel} = error("invalid type $T")
field_name(::Type{T}, name::Symbol) where {T<:SwaggerModel} = error("invalid type $T")

getproperty(o::T, name::Symbol) where {T<:SwaggerModel} = getfield(o, field_name(T,name))
hasproperty(o::T, name::Symbol) where {T<:SwaggerModel} = ((name in propertynames(T)) && (getproperty(o, name) !== nothing))
function setproperty!(o::T, name::Symbol, val) where {T<:SwaggerModel}
    validate_property(T, name, val)
    fieldtype = property_type(T, name)
    fieldname = field_name(T, name)

    if isa(val, fieldtype)
        return setfield!(o, fieldname, val)
    else
        ftval = try
            convert(fieldtype, val)
        catch
            fieldtype(val)
        end
        return setfield!(o, fieldname, ftval)
    end
end

function getpropertyat(o::T, path...) where {T<:SwaggerModel}
    val = getproperty(o, Symbol(path[1]))
    rempath = path[2:end]
    (length(rempath) == 0) && (return val)

    if isa(val, Vector)
        if isa(rempath[1], Integer)
            val = val[rempath[1]]
            rempath = rempath[2:end]
        else
            return [getpropertyat(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return val)
    getpropertyat(val, rempath...)
end

function haspropertyat(o::T, path...) where {T<:SwaggerModel}
    p1 = Symbol(path[1])
    ret = hasproperty(o, p1)
    rempath = path[2:end]
    (length(rempath) == 0) && (return ret)

    val = getproperty(o, p1)
    if isa(val, Vector)
        if isa(rempath[1], Integer)
            ret = length(val) >= rempath[1]
            if ret
                val = val[rempath[1]]
                rempath = rempath[2:end]
            end
        else
            return [haspropertyat(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return ret)
    haspropertyat(val, rempath...)
end

convert(::Type{T}, json::Dict{String,Any}) where {T<:SwaggerModel} = from_json(T, json)
convert(::Type{T}, v::Nothing) where {T<:SwaggerModel} = T()

show(io::IO, model::T) where {T<:SwaggerModel} = print(io, JSON.json(model, 2))
summary(model::T) where {T<:SwaggerModel} = print(io, T)
