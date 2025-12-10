#!/usr/bin/env python3
"""
HuggingFace Model Downloader
Downloads and converts models from HuggingFace to MLX format.
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional
import shutil

try:
    from huggingface_hub import snapshot_download, list_repo_files, hf_hub_download
    from huggingface_hub.utils import HfHubHTTPError
    HF_AVAILABLE = True
except ImportError:
    HF_AVAILABLE = False
    print(json.dumps({
        "error": "huggingface_hub not installed. Install with: pip install huggingface-hub",
        "type": "import_error"
    }), flush=True)
    sys.exit(1)

# Note: mlx_lm.convert is NOT imported here to avoid xcrun calls in App Sandbox
# It will be imported lazily only if conversion is actually needed
MLX_CONVERT_AVAILABLE = False  # Disabled to prevent sandbox issues


class HuggingFaceDownloader:
    """Handles downloading models from HuggingFace."""

    def __init__(self, cache_dir: Optional[str] = None):
        """
        Initialize downloader.

        Args:
            cache_dir: Directory to cache downloads (default: ~/.cache/huggingface)
        """
        self.cache_dir = Path(cache_dir).expanduser() if cache_dir else None

    def download_model(
        self,
        repo_id: str,
        output_dir: str,
        convert_to_mlx: bool = True,
        quantize: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Download model from HuggingFace.

        Args:
            repo_id: HuggingFace repo ID (e.g., "mlx-community/Llama-3.2-3B-Instruct-4bit")
            output_dir: Directory to save model
            convert_to_mlx: Whether to convert to MLX format
            quantize: Quantization level (None, "4bit", "8bit")

        Returns:
            Status dict with download info
        """
        try:
            output_path = Path(output_dir).expanduser()
            output_path.mkdir(parents=True, exist_ok=True)

            # Check if model already exists
            if (output_path / "config.json").exists():
                return {
                    "success": True,
                    "path": str(output_path),
                    "message": "Model already exists",
                    "skipped": True
                }

            # Download model
            print(json.dumps({
                "type": "progress",
                "stage": "downloading",
                "message": f"Downloading {repo_id}..."
            }), flush=True)

            # Download with progress
            downloaded_path = snapshot_download(
                repo_id=repo_id,
                cache_dir=self.cache_dir,
                local_dir=output_path,
                local_dir_use_symlinks=False
            )

            # Convert to MLX if requested
            # Note: Conversion is disabled to prevent xcrun calls in App Sandbox
            # All models should be from mlx-community (already in MLX format)
            if convert_to_mlx:
                print(json.dumps({
                    "type": "warning",
                    "message": "Conversion skipped - use mlx-community models (already in MLX format)"
                }), flush=True)

            # Get model size
            model_size = sum(f.stat().st_size for f in output_path.rglob('*') if f.is_file())
            model_size_gb = model_size / (1024 ** 3)

            return {
                "success": True,
                "path": str(output_path),
                "repo_id": repo_id,
                "size_bytes": model_size,
                "size_gb": round(model_size_gb, 2),
                "quantization": quantize,
                "converted_to_mlx": convert_to_mlx and MLX_CONVERT_AVAILABLE
            }

        except HfHubHTTPError as e:
            if e.response.status_code == 404:
                return {
                    "success": False,
                    "error": f"Model not found: {repo_id}",
                    "type": "not_found_error"
                }
            else:
                return {
                    "success": False,
                    "error": str(e),
                    "type": "http_error"
                }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "download_error"
            }

    def list_files(self, repo_id: str) -> Dict[str, Any]:
        """
        List files in a HuggingFace repository.

        Args:
            repo_id: HuggingFace repo ID

        Returns:
            Dict with file list
        """
        try:
            files = list_repo_files(repo_id=repo_id)

            return {
                "success": True,
                "repo_id": repo_id,
                "files": files,
                "count": len(files)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "list_error"
            }

    def get_model_info(self, repo_id: str) -> Dict[str, Any]:
        """
        Get information about a model.

        Args:
            repo_id: HuggingFace repo ID

        Returns:
            Dict with model info
        """
        try:
            from huggingface_hub import model_info

            info = model_info(repo_id=repo_id)

            return {
                "success": True,
                "repo_id": repo_id,
                "author": info.author,
                "model_id": info.modelId,
                "downloads": info.downloads,
                "likes": info.likes,
                "tags": info.tags,
                "pipeline_tag": info.pipeline_tag,
                "library_name": info.library_name
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "info_error"
            }

    def delete_model(self, model_path: str) -> Dict[str, Any]:
        """
        Delete a downloaded model.

        Args:
            model_path: Path to model directory

        Returns:
            Status dict
        """
        try:
            model_path = Path(model_path).expanduser()

            if not model_path.exists():
                return {
                    "success": False,
                    "error": f"Model path does not exist: {model_path}",
                    "type": "path_error"
                }

            # Delete directory
            shutil.rmtree(model_path)

            return {
                "success": True,
                "message": f"Deleted model at {model_path}"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "delete_error"
            }


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(description="HuggingFace Model Downloader")

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Download command
    download_parser = subparsers.add_parser("download", help="Download a model")
    download_parser.add_argument("repo_id", type=str, help="HuggingFace repo ID")
    download_parser.add_argument("--output", type=str, required=True, help="Output directory")
    download_parser.add_argument("--no-convert", action="store_true", help="Don't convert to MLX")
    download_parser.add_argument("--quantize", choices=["4bit", "8bit"], help="Quantization level")
    download_parser.add_argument("--cache-dir", type=str, help="Cache directory")

    # List command
    list_parser = subparsers.add_parser("list", help="List files in a model repo")
    list_parser.add_argument("repo_id", type=str, help="HuggingFace repo ID")

    # Info command
    info_parser = subparsers.add_parser("info", help="Get model information")
    info_parser.add_argument("repo_id", type=str, help="HuggingFace repo ID")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Delete a downloaded model")
    delete_parser.add_argument("model_path", type=str, help="Path to model directory")

    args = parser.parse_args()

    downloader = HuggingFaceDownloader(cache_dir=getattr(args, 'cache_dir', None))

    if args.command == "download":
        result = downloader.download_model(
            repo_id=args.repo_id,
            output_dir=args.output,
            convert_to_mlx=not args.no_convert,
            quantize=args.quantize
        )
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "list":
        result = downloader.list_files(repo_id=args.repo_id)
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "info":
        result = downloader.get_model_info(repo_id=args.repo_id)
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "delete":
        result = downloader.delete_model(model_path=args.model_path)
        print(json.dumps(result, indent=2), flush=True)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
