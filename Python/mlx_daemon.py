#!/usr/bin/env python3
"""
MLX Persistent Daemon
Keeps model loaded in memory for instant inference.
"""

import sys
import json
import signal
from pathlib import Path
from typing import Optional

try:
    import mlx.core as mx
    from mlx_lm import load, generate
    MLX_AVAILABLE = True
except ImportError as e:
    MLX_AVAILABLE = False
    print(json.dumps({
        "error": f"MLX not installed: {str(e)}",
        "type": "import_error"
    }), flush=True)
    sys.exit(1)


class MLXDaemon:
    """Persistent MLX inference daemon."""

    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_path = None
        self.running = True

        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._handle_shutdown)
        signal.signal(signal.SIGTERM, self._handle_shutdown)

    def _handle_shutdown(self, signum, frame):
        """Handle shutdown signals gracefully."""
        self.running = False
        print(json.dumps({
            "type": "shutdown",
            "message": "Daemon shutting down"
        }), flush=True)
        sys.exit(0)

    def load_model(self, model_path: str) -> dict:
        """Load model into memory (with caching)."""
        try:
            model_path = Path(model_path).expanduser()

            if not model_path.exists():
                return {
                    "success": False,
                    "error": f"Model path does not exist: {model_path}",
                    "type": "path_error"
                }

            # Check if already loaded (CACHE)
            if self.model is not None and self.model_path == model_path:
                return {
                    "success": True,
                    "path": str(model_path),
                    "name": model_path.name,
                    "cached": True,
                    "message": "Model already loaded in daemon"
                }

            # Load model
            self.model, self.tokenizer = load(str(model_path))
            self.model_path = model_path

            return {
                "success": True,
                "path": str(model_path),
                "name": model_path.name,
                "cached": False,
                "message": "Model loaded successfully"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "load_error"
            }

    def generate(
        self,
        prompt: str,
        max_tokens: int = 2048,
        temperature: float = 0.7,
        top_p: float = 0.9,
        repetition_penalty: float = 1.0
    ):
        """Generate text from prompt (streaming)."""
        if self.model is None:
            yield {
                "type": "error",
                "error": "No model loaded"
            }
            return

        try:
            # Generate with mlx_lm.generate() which returns a generator
            # Note: generate() only accepts model, tokenizer, prompt, max_tokens, verbose
            response = generate(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                verbose=False
            )

            # Stream tokens from generator
            for token in response:
                if not self.running:
                    break

                yield {
                    "type": "token",
                    "token": token
                }

            # Generation complete
            yield {
                "type": "complete",
                "message": "Generation finished"
            }

        except Exception as e:
            yield {
                "type": "error",
                "error": str(e)
            }

    def run(self):
        """Main daemon loop - process commands from stdin."""
        # Send ready message
        print(json.dumps({
            "type": "ready",
            "message": "Daemon started and ready"
        }), flush=True)

        while self.running:
            try:
                # Read command from stdin
                line = sys.stdin.readline()

                if not line:
                    # EOF reached
                    break

                command = json.loads(line.strip())
                command_type = command.get("type")

                if command_type == "load_model":
                    result = self.load_model(command["model_path"])
                    print(json.dumps(result), flush=True)

                elif command_type == "generate":
                    # Stream tokens
                    for response in self.generate(
                        prompt=command["prompt"],
                        max_tokens=command.get("max_tokens", 2048),
                        temperature=command.get("temperature", 0.7),
                        top_p=command.get("top_p", 0.9),
                        repetition_penalty=command.get("repetition_penalty", 1.0)
                    ):
                        print(json.dumps(response), flush=True)

                elif command_type == "status":
                    # Health check
                    print(json.dumps({
                        "type": "status",
                        "running": True,
                        "model_loaded": self.model is not None,
                        "model_path": str(self.model_path) if self.model_path else None
                    }), flush=True)

                elif command_type == "shutdown":
                    self.running = False
                    print(json.dumps({
                        "type": "shutdown",
                        "message": "Daemon shutting down"
                    }), flush=True)
                    break

                else:
                    print(json.dumps({
                        "type": "error",
                        "error": f"Unknown command type: {command_type}"
                    }), flush=True)

            except json.JSONDecodeError as e:
                print(json.dumps({
                    "type": "error",
                    "error": f"Invalid JSON: {str(e)}"
                }), flush=True)

            except Exception as e:
                print(json.dumps({
                    "type": "error",
                    "error": f"Unexpected error: {str(e)}"
                }), flush=True)


if __name__ == "__main__":
    daemon = MLXDaemon()
    daemon.run()
