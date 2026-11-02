# Rust , Cargo
# Rust
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Ollama & AI
export OLLAMA_CONTEXT_LENGTH=8192
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_FLASH_ATTENTION=true
export OLLAMA_KEEP_ALIVE=2h
