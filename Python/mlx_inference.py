#!/usr/bin/env python3
"""
MLX Inference Bridge
Handles real MLX model loading and inference for MLX Code app.
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, Iterator
import threading
import queue

try:
    import mlx.core as mx
    import mlx.nn as nn
    from mlx_lm import load, generate, stream_generate
    MLX_AVAILABLE = True
except ImportError as e:
    MLX_AVAILABLE = False
    print(json.dumps({
        "error": f"MLX not installed: {str(e)}. Install with: pip install mlx mlx-lm",
        "type": "import_error"
    }), flush=True)
    sys.exit(1)


class MLXInferenceEngine:
    """Handles MLX model loading and inference with caching."""

    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_path = None
        self.config = {}

    def load_model(self, model_path: str) -> Dict[str, Any]:
        """
        Load MLX model from path with caching.

        Args:
            model_path: Path to model directory

        Returns:
            Status dict with success/error info
        """
        try:
            model_path = Path(model_path).expanduser()

            if not model_path.exists():
                return {
                    "success": False,
                    "error": f"Model path does not exist: {model_path}",
                    "type": "path_error"
                }

            # Check if model is already loaded (CACHE CHECK)
            if self.model is not None and self.model_path == model_path:
                return {
                    "success": True,
                    "path": str(model_path),
                    "name": model_path.name,
                    "type": "mlx",
                    "cached": True,
                    "message": "Model already loaded (cached)"
                }

            # Load model and tokenizer
            self.model, self.tokenizer = load(str(model_path))
            self.model_path = model_path

            # Get model info
            model_info = {
                "success": True,
                "path": str(model_path),
                "name": model_path.name,
                "type": "mlx",
                "cached": False,
                "message": "Model loaded from disk"
            }

            return model_info

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
        repetition_penalty: float = 1.0,
        stream: bool = True
    ) -> Iterator[Dict[str, Any]]:
        """
        Generate text from prompt using loaded model.

        Args:
            prompt: Input prompt
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0.0-2.0)
            top_p: Nucleus sampling parameter
            repetition_penalty: Penalty for repeating tokens
            stream: Whether to stream tokens

        Yields:
            Dicts with generated tokens or completion status
        """
        if self.model is None or self.tokenizer is None:
            yield {
                "error": "No model loaded. Call load_model first.",
                "type": "model_error"
            }
            return

        try:
            # Generate with streaming
            # Note: mlx_lm.generate() returns a generator that yields strings
            response = generate(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                verbose=False
            )

            if stream:
                # Stream token by token
                for token in response:
                    yield {
                        "token": token,
                        "type": "token"
                    }
            else:
                # Return complete response
                full_response = "".join(response)
                yield {
                    "text": full_response,
                    "type": "complete"
                }

            # Send completion signal
            yield {
                "type": "done",
                "success": True
            }

        except Exception as e:
            yield {
                "error": str(e),
                "type": "generation_error"
            }

    def unload_model(self) -> Dict[str, Any]:
        """Unload current model from memory."""
        try:
            self.model = None
            self.tokenizer = None
            self.model_path = None

            # Force garbage collection
            import gc
            gc.collect()

            return {
                "success": True,
                "message": "Model unloaded successfully"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "unload_error"
            }


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(description="MLX Inference Bridge")
    parser.add_argument("--mode", choices=["interactive", "single"], default="interactive",
                       help="Interaction mode")
    parser.add_argument("--model", type=str, help="Model path to load")
    parser.add_argument("--prompt", type=str, help="Prompt for single mode")
    parser.add_argument("--max-tokens", type=int, default=2048, help="Max tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    parser.add_argument("--top-p", type=float, default=0.9, help="Nucleus sampling parameter")
    parser.add_argument("--stream", action="store_true", default=True, help="Stream tokens")

    args = parser.parse_args()

    engine = MLXInferenceEngine()

    if args.mode == "single":
        # Single inference mode
        if not args.model or not args.prompt:
            print(json.dumps({
                "error": "Both --model and --prompt required for single mode",
                "type": "argument_error"
            }), flush=True)
            sys.exit(1)

        # Load model
        result = engine.load_model(args.model)
        print(json.dumps(result), flush=True)

        if not result.get("success"):
            sys.exit(1)

        # Generate
        for output in engine.generate(
            prompt=args.prompt,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
            top_p=args.top_p,
            stream=args.stream
        ):
            print(json.dumps(output), flush=True)

    else:
        # Interactive mode - read commands from stdin
        print(json.dumps({"type": "ready", "message": "MLX Inference Engine ready"}), flush=True)

        for line in sys.stdin:
            try:
                command = json.loads(line.strip())
                cmd_type = command.get("type")

                if cmd_type == "load_model":
                    result = engine.load_model(command["model_path"])
                    print(json.dumps(result), flush=True)

                elif cmd_type == "generate":
                    for output in engine.generate(
                        prompt=command["prompt"],
                        max_tokens=command.get("max_tokens", 2048),
                        temperature=command.get("temperature", 0.7),
                        top_p=command.get("top_p", 0.9),
                        repetition_penalty=command.get("repetition_penalty", 1.0),
                        stream=command.get("stream", True)
                    ):
                        print(json.dumps(output), flush=True)

                elif cmd_type == "unload_model":
                    result = engine.unload_model()
                    print(json.dumps(result), flush=True)

                elif cmd_type == "exit":
                    print(json.dumps({"type": "exit", "message": "Shutting down"}), flush=True)
                    break

                else:
                    print(json.dumps({
                        "error": f"Unknown command type: {cmd_type}",
                        "type": "command_error"
                    }), flush=True)

            except json.JSONDecodeError as e:
                print(json.dumps({
                    "error": f"Invalid JSON: {e}",
                    "type": "json_error"
                }), flush=True)

            except Exception as e:
                print(json.dumps({
                    "error": str(e),
                    "type": "error"
                }), flush=True)


if __name__ == "__main__":
    main()
