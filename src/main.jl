include("./IRC.jl")
include("./Kokoro_cpp.jl")

using .IRC
using .Kokoro_cpp
using Accessors

CONF = nothing
MODEL_PATH = nothing
VOICE_PATH = nothing

include("../config.jl")

params = KokoroCentextDefaultParams()
params = @set params.length_scale = 1.2
ctx = KokoroInit(MODEL_PATH, params)
KokoroLoadVoicePack(ctx, VOICE_PATH)

cnt = irc_connect(CONF)

rlock = ReentrantLock()
message_channel = Channel{IRCMessage}(10)

function handler(cnt, conf, msg, handler_context, rlock)
    if msg.command == "PRIVMSG"
        @info "TTS doing job" msg.trailing
        audio = KokoroGetAudio(ctx, msg.trailing)
        if !isnothing(audio)
            cmd = `paplay --raw --rate=$(audio.sample_rate) --channels=1 --format=float32le`
            open(cmd, "w") do io
                write(io, audio.sample)
            end
        else
            @warn "Audio is empty"
        end
    end
end

listener_t = Threads.@spawn irc_listener_start(cnt, CONF, message_channel, rlock)
handler_t = Threads.@spawn irc_handler_start(cnt, CONF, message_channel, [handler], rlock)

wait(handler_t)