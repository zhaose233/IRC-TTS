using Random

CONF = IRC_config(
    "irc.chat.twitch.tv",
    true,
    6697, 
    "justinfan$(rand(10000:99999))", 
    nothing, 
    "justinfan$(rand(10000:99999))", 
    ["asairo233"])

MODEL_PATH = "kokoro.cpp/models/kokoro-82m-f16.gguf"
VOICE_PATH = "kokoro.cpp/models/kokoro-voice-af_heart.gguf"
