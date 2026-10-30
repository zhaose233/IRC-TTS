# Simple julia program for reading out IRC messages

Reads out every message received in IRC channels. To use it, you need to
```bash
git clone --recurse-submodules https://github.com/zhaose233/IRC-TTS.git
cd IRC-TTS

cd kokoro.cpp
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DKOKORO_STATIC=OFF \
         -DKOKORO_BUILD_TESTS=OFF \
         -DKOKORO_BUILD_CLI=OFF
cmake --build . -j$(nproc)

cd ../models
./download-model.sh
```
then come back to the project root directory, run
```
julia --threads=2 --project=./ src/main.jl
```

You can config it in `config.jl`.