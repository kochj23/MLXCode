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

    def _read_context_window(self, model_path: Path) -> int:
        """Read context window size from model config.json."""
        config_path = model_path / "config.json"
        context_window = 8192  # conservative default
        if config_path.exists():
            try:
                import json as json_mod
                with open(config_path) as f:
                    config = json_mod.load(f)
                context_window = config.get("max_position_embeddings",
                                config.get("max_seq_len",
                                config.get("seq_length",
                                config.get("sliding_window", 8192))))
                if isinstance(context_window, str):
                    context_window = int(context_window)
            except Exception:
                pass
        return context_window

    def load_model(self, model_path: str) -> dict:
        """Load model into memory (with caching)."""
        try:
            print(json.dumps({
                "type": "debug",
                "message": f"load_model() called with: {model_path}"
            }), flush=True)

            model_path = Path(model_path).expanduser()

            print(json.dumps({
                "type": "debug",
                "message": f"Expanded to: {model_path}"
            }), flush=True)

            print(json.dumps({
                "type": "debug",
                "message": f"Path exists: {model_path.exists()}"
            }), flush=True)

            if not model_path.exists():
                return {
                    "success": False,
                    "error": f"Model path does not exist: {model_path}",
                    "type": "path_error"
                }

            # Read context window from config
            context_window = self._read_context_window(model_path)

            # Check if already loaded (CACHE)
            if self.model is not None and self.model_path == model_path:
                return {
                    "success": True,
                    "path": str(model_path),
                    "name": model_path.name,
                    "cached": True,
                    "context_window": context_window,
                    "message": "Model already loaded in daemon"
                }

            # Load model
            print(json.dumps({
                "type": "debug",
                "message": f"Calling mlx_lm.load() with: {str(model_path)}"
            }), flush=True)

            self.model, self.tokenizer = load(str(model_path))
            self.model_path = model_path

            print(json.dumps({
                "type": "debug",
                "message": "mlx_lm.load() completed successfully"
            }), flush=True)

            # Check if tokenizer supports chat templates
            has_chat_template = hasattr(self.tokenizer, 'apply_chat_template')
            print(json.dumps({
                "type": "debug",
                "message": f"Chat template support: {has_chat_template}, context_window: {context_window}"
            }), flush=True)

            return {
                "success": True,
                "path": str(model_path),
                "name": model_path.name,
                "cached": False,
                "context_window": context_window,
                "has_chat_template": has_chat_template,
                "message": "Model loaded successfully"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "load_error"
            }

    def _format_chatml(self, messages: list) -> str:
        """Fallback ChatML formatting for models without chat templates."""
        prompt = ""
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            prompt += f"<|im_start|>{role}\n{content}<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"
        return prompt

    def chat_generate(
        self,
        messages: list,
        max_tokens: int = 2048,
        temperature: float = 0.7,
        top_p: float = 0.9,
        repetition_penalty: float = 1.0
    ):
        """Generate from structured messages using tokenizer's chat template."""
        if self.model is None or self.tokenizer is None:
            yield {
                "type": "error",
                "error": "No model loaded"
            }
            return

        try:
            # Use tokenizer's built-in chat template if available
            if hasattr(self.tokenizer, 'apply_chat_template'):
                try:
                    prompt = self.tokenizer.apply_chat_template(
                        messages,
                        tokenize=False,
                        add_generation_prompt=True
                    )
                    print(json.dumps({
                        "type": "debug",
                        "message": f"Applied tokenizer chat template, prompt length: {len(prompt)}"
                    }), flush=True)
                except Exception as e:
                    print(json.dumps({
                        "type": "debug",
                        "message": f"Chat template failed ({e}), falling back to ChatML"
                    }), flush=True)
                    prompt = self._format_chatml(messages)
            else:
                prompt = self._format_chatml(messages)
                print(json.dumps({
                    "type": "debug",
                    "message": f"No chat template, using ChatML fallback, prompt length: {len(prompt)}"
                }), flush=True)

            # Generate with same streaming approach as generate()
            response = generate(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                verbose=False
            )

            # Stream tokens
            for token in response:
                if not self.running:
                    break
                yield {
                    "type": "token",
                    "token": token
                }

            yield {
                "type": "complete",
                "message": "Generation finished"
            }

        except Exception as e:
            yield {
                "type": "error",
                "error": str(e)
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

                elif command_type == "chat_generate":
                    # Structured message generation with chat template
                    for response in self.chat_generate(
                        messages=command["messages"],
                        max_tokens=command.get("max_tokens", 2048),
                        temperature=command.get("temperature", 0.7),
                        top_p=command.get("top_p", 0.9),
                        repetition_penalty=command.get("repetition_penalty", 1.0)
                    ):
                        print(json.dumps(response), flush=True)

                elif command_type == "generate":
                    # Stream tokens (legacy raw prompt mode)
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
