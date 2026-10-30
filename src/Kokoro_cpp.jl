module Kokoro_cpp

using WAV

export KokoroCentextDefaultParams, KokoroContextParams, KokoroInit, KokoroLoadVoicePack, KokoroGetAudio

using Accessors
libkokoro_path = "lib/libkokoro.so"

@enum KokoroBackend::Cint begin
    KOKORO_BACKEND_AUTO   = 0
    KOKORO_BACKEND_CPU    = 1
    KOKORO_BACKEND_VULKAN = 2
    KOKORO_BACKEND_METAL  = 3
    KOKORO_BACKEND_CUDA   = 4
end

@enum KokoroStatus::Cint begin
    KOKORO_STATUS_OK             =  0
    KOKORO_STATUS_INVALID_PARAMS = -1
    KOKORO_STATUS_LOAD_FAILED    = -2
    KOKORO_STATUS_NO_VOICE       = -3
    KOKORO_STATUS_SYNTH_FAILED   = -4
end

@enum KokoroLogLevel::Cint begin
    KOKORO_LOG_DEBUG = 0
    KOKORO_LOG_INFO  = 1
    KOKORO_LOG_WARN  = 2
    KOKORO_LOG_ERROR = 3
end

struct KokoroContextParams
    abi_version::Cint
    n_threads::Cint
    verbosity::Cint
    length_scale::Cfloat
    espeak_lang::NTuple{32, Cchar}
    kokoro_backend::KokoroBackend
    device::Cint
end

struct KokoroAudio
    samples::Ptr{Cfloat}
    n_samples::Cint
    sample_rate::Cint
    channels::Cint
end

function KokoroCentextDefaultParams()
    params = ccall((:kokoro_context_default_params, libkokoro_path), KokoroContextParams, ())
    return params
end

function KokoroInit(path_model::String, kctx::KokoroContextParams)
    ctx = ccall((:kokoro_init_from_file, libkokoro_path), Ptr{Cvoid}, (Cstring, KokoroContextParams), path_model, kctx)
    return ctx
end

function KokoroLoadVoicePack(ctx, voice_path::String)
    status = ccall((:kokoro_load_voice_pack, libkokoro_path), KokoroStatus, (Ptr{Cvoid}, Cstring), ctx, voice_path)
    return status
end

function KokoroGetAudio(ctx, text::String)
    audio_ref = Ref{KokoroAudio}()
    status = ccall((:kokoro_synthesize_audio, libkokoro_path), KokoroStatus, (Ptr{Cvoid}, Cstring, Ref{KokoroAudio}), ctx, text, audio_ref)

    if status == KOKORO_STATUS_OK
        audio = audio_ref[]
        samples = unsafe_wrap(Array, audio.samples, audio.n_samples; own=false)

        sample_copy = copy(samples)
        sample_rate = audio.sample_rate

        ccall((:kokoro_audio_free, libkokoro_path), Cvoid, (Ref{KokoroAudio},), audio_ref)

        return(sample=sample_copy, sample_rate=sample_rate)
    end
    return nothing

end

end