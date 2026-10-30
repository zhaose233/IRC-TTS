module IRC

using Sockets
using OpenSSL

export IRC_config, IRCMessage, irc_send, irc_parse, irc_connect, irc_handler_start, irc_listener_start

struct IRC_config
    server::String
    ssl::Bool
    port::Int
    nick::String
    passwd::Union{String,Nothing}
    realname::String
    channels::Vector{String}
end

struct IRCMessage
    prefix::Union{String,Nothing}
    command::String
    params::Vector{String}
    trailing::Union{String,Nothing}
end

"""
Send command
"""
function irc_send(cnt, cmd::String, rlock::ReentrantLock)
    lock(rlock) do
        write(cnt, "$cmd\r\n")
        flush(cnt)
    end
end

"""
Message Parser
"""
function irc_parse(raw::String)
    @debug "Paring raw message" raw
    line = rstrip(raw, ['\r', '\n'])
    prefix = nothing
    rest = line

    if startswith(rest, ":")
        parts = split(rest[2:end], " ", limit=2)
        prefix = parts[1]
        rest = length(parts) > 1 ? parts[2] : ""
    end

    trailing = nothing
    if occursin(" :", rest)
        parts = split(rest, " :", limit=2)
        rest = parts[1]
        trailing = parts[2]
    end

    tokens = split(rest)
    command = isempty(tokens) ? "" : tokens[1]
    params = length(tokens) > 1 ? tokens[2:end] : String[]

    return IRCMessage(prefix, command, params, trailing)
end

"""
Connect to IRC server
"""
function Base.read(ssl::OpenSSL.SSLStream, ::Type{UInt8})
    buf = Ref{UInt8}()
    unsafe_read(ssl, Base.unsafe_convert(Ptr{UInt8}, buf), 1)
    return buf[]
end
function irc_connect(irc_conf::IRC_config)
    server = irc_conf.server
    port = irc_conf.port
    @info "Connecting" server port
    try
        tcp = connect(server, port)
        if !irc_conf.ssl
            return tcp
        end
        ssl = SSLStream(tcp)
        OpenSSL.hostname!(ssl, server)
        OpenSSL.connect(ssl)
        return ssl
    catch e
        @error "Connection fail" e
        return nothing
    end
end


"""
Start listener
"""
function irc_listener_start(cnt, conf::IRC_config, msg_channel::Channel{IRCMessage}, rlock::ReentrantLock)
    @info "Initializing listener"
    nick = conf.nick
    rn = conf.realname
    passwd = conf.passwd
    irc_send(cnt, "NICK $nick", rlock)
    irc_send(cnt, "USER $nick 0 * :$rn", rlock)

    try
        @info "Starting listener"
        while isopen(cnt)
            line = readline(cnt)
            isempty(line) && continue

            msg = irc_parse(line)

            if msg.command == "PING"
                context = msg.trailing
                irc_send(cnt, "PONG :$context", rlock)
                continue
            elseif msg.command == "433"
                nick = nick * "_"
                irc_send(cnt, "USER $nick 0 * :$rn", rlock)
                continue
            elseif msg.command == "001"
                if !isnothing(passwd)
                    @info "Logging in"
                    irc_send(cnt, "PRIVMSG NickServ :IDENTIFY $passwd", rlock)
                end
                @info "Joining channels"
                for chnl in conf.channels
                    irc_send(cnt, "JOIN #$chnl", rlock)
                end
                continue
            end

            put!(msg_channel, msg)
        end
    catch e
        @warn "Error" e
    finally
        @info "Stop listener, closing message channel"
        close(msg_channel)
    end
end

"""
Handler
"""
function irc_handler_start(cnt, conf::IRC_config, msg_channel::Channel{IRCMessage}, handlers, rlock::ReentrantLock)
    @info "Starting handler"
    handler_context = ()

    for msg in msg_channel
        @info "Message processing" msg
        try
            for handler in handlers
                handler(cnt, conf, msg, handler_context, rlock)
            end
        catch e
            @warn "Handler error" e
        end
    end

    @info "Handler stopped"
end

end