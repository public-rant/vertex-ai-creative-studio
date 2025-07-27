#!/bin/bash

# Demo script for MCP Genmedia servers
# This script demonstrates how to use each MCP server with sample requests

# Source the environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MCP Genmedia Demo ===${NC}"
echo
echo "This demo shows how to use each MCP server with sample requests."
echo "Make sure you have sourced the .env file first!"
echo

# Helper function to make MCP requests
make_request() {
    local server=$1
    local method=$2
    local params=$3
    local id=$4

    echo -e "${YELLOW}Request to $server:${NC}"
    echo "Method: $method"
    echo "Params: $params"
    echo

    local request="{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":$id}"
    echo "$request" | $HOME/go/bin/$server 2>&1 | grep -A 50 '"result"' || echo "No result found"
    echo
    echo "---"
    echo
}

# Demo 1: List tools from Imagen server
echo -e "${GREEN}Demo 1: List Imagen tools${NC}"
make_request "mcp-imagen-go" "tools/list" "{}" 1

# Demo 2: Generate an image with Imagen
echo -e "${GREEN}Demo 2: Generate an image with Imagen${NC}"
echo "This will generate an image of a sunset over mountains"
read -p "Press Enter to continue..."
make_request "mcp-imagen-go" "tools/call" \
    "{\"name\":\"imagen_t2i\",\"arguments\":{\"prompt\":\"A beautiful sunset over mountain peaks with vibrant orange and purple colors\",\"output_directory\":\"./generated_images\",\"num_images\":1}}" 2

# Demo 3: List Chirp voices
echo -e "${GREEN}Demo 3: List available Chirp voices${NC}"
make_request "mcp-chirp3-go" "tools/call" \
    "{\"name\":\"list_chirp_voices\",\"arguments\":{}}" 3

# Demo 4: Generate speech with Chirp
echo -e "${GREEN}Demo 4: Generate speech with Chirp${NC}"
echo "This will generate speech saying 'Hello from MCP Genmedia!'"
read -p "Press Enter to continue..."
make_request "mcp-chirp3-go" "tools/call" \
    "{\"name\":\"chirp_tts\",\"arguments\":{\"text\":\"Hello from MCP Genmedia! This is a test of the text to speech capabilities.\",\"voice\":\"en-US-Standard-A\",\"output_directory\":\"./generated_audio\"}}" 4

# Demo 5: Generate music with Lyria
echo -e "${GREEN}Demo 5: Generate music with Lyria${NC}"
echo "This will generate a short musical piece"
read -p "Press Enter to continue..."
make_request "mcp-lyria-go" "tools/call" \
    "{\"name\":\"lyria_generate_music\",\"arguments\":{\"prompt\":\"Upbeat electronic dance music with synthesizers\",\"output_directory\":\"./generated_music\",\"seconds\":10}}" 5

# Demo 6: Get media info with AVTool
echo -e "${GREEN}Demo 6: Get media info with AVTool${NC}"
echo "First, let's create a test audio file..."
# Create a simple test file using Chirp first
make_request "mcp-chirp3-go" "tools/call" \
    "{\"name\":\"chirp_tts\",\"arguments\":{\"text\":\"Test audio for AVTool demo\",\"voice\":\"en-US-Standard-A\",\"output_directory\":\"./test_media\"}}" 6

echo "Now let's get info about the generated audio file:"
# Note: You'll need to update the path based on actual output
make_request "mcp-avtool-go" "tools/call" \
    "{\"name\":\"get_media_info\",\"arguments\":{\"source\":\"./test_media/chirp_output.wav\"}}" 7

# Demo 7: Generate video with Veo
echo -e "${GREEN}Demo 7: Generate video with Veo${NC}"
echo "This will generate a short video (Note: Veo may take longer to process)"
read -p "Press Enter to continue..."
make_request "mcp-veo-go" "tools/call" \
    "{\"name\":\"veo_t2v\",\"arguments\":{\"prompt\":\"A serene beach scene with gentle waves\",\"output_directory\":\"./generated_videos\",\"seconds\":5}}" 8

echo -e "${BLUE}=== Demo Complete ===${NC}"
echo
echo "Generated files should be in the following directories:"
echo "  - ./generated_images/"
echo "  - ./generated_audio/"
echo "  - ./generated_music/"
echo "  - ./generated_videos/"
echo "  - ./test_media/"
echo
echo "You can also run MCP servers in HTTP mode for use with other clients:"
echo "  $HOME/go/bin/mcp-imagen-go --transport http"
echo
