#!/usr/bin/env python3
"""
RAG (Retrieval-Augmented Generation) System
Handles codebase indexing, embeddings, and semantic search.
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, List, Optional
import hashlib

try:
    from sentence_transformers import SentenceTransformer
    import chromadb
    from chromadb.config import Settings
    import numpy as np
    DEPENDENCIES_AVAILABLE = True
except ImportError:
    DEPENDENCIES_AVAILABLE = False
    print(json.dumps({
        "error": "RAG dependencies not installed. Install with: pip install sentence-transformers chromadb",
        "type": "import_error"
    }), flush=True)
    sys.exit(1)


class RAGSystem:
    """Manages codebase indexing and semantic search."""

    def __init__(self, db_path: str = "~/.mlx/chroma_db", model_name: str = "all-MiniLM-L6-v2"):
        """
        Initialize RAG system.

        Args:
            db_path: Path to ChromaDB database
            model_name: Sentence transformer model name
        """
        self.db_path = Path(db_path).expanduser()
        self.db_path.mkdir(parents=True, exist_ok=True)

        # Initialize embedding model
        self.embedding_model = SentenceTransformer(model_name)

        # Initialize ChromaDB
        self.client = chromadb.PersistentClient(
            path=str(self.db_path),
            settings=Settings(anonymized_telemetry=False)
        )

        # Get or create collection
        self.collection = self.client.get_or_create_collection(
            name="codebase",
            metadata={"description": "Code files and documentation"}
        )

    def index_directory(
        self,
        directory_path: str,
        extensions: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Index all code files in a directory.

        Args:
            directory_path: Path to directory to index
            extensions: File extensions to include (e.g., [".swift", ".py"])
            exclude_patterns: Patterns to exclude (e.g., ["test", "build"])

        Returns:
            Dict with indexing statistics
        """
        try:
            directory = Path(directory_path).expanduser()

            if not directory.exists():
                return {
                    "success": False,
                    "error": f"Directory does not exist: {directory}",
                    "type": "path_error"
                }

            # Default extensions if none provided
            if extensions is None:
                extensions = [".swift", ".m", ".h", ".py", ".js", ".ts", ".json", ".md"]

            # Default exclude patterns
            if exclude_patterns is None:
                exclude_patterns = [
                    "build", "Build", "DerivedData", ".build",
                    "node_modules", ".git", "__pycache__",
                    "test", "Test", "tests", "Tests"
                ]

            indexed_count = 0
            skipped_count = 0
            error_count = 0

            # Find all files
            for file_path in directory.rglob("*"):
                # Skip directories
                if not file_path.is_file():
                    continue

                # Check extension
                if file_path.suffix not in extensions:
                    skipped_count += 1
                    continue

                # Check exclude patterns
                if any(pattern in str(file_path) for pattern in exclude_patterns):
                    skipped_count += 1
                    continue

                # Index file
                try:
                    self.index_file(str(file_path))
                    indexed_count += 1

                    # Progress update every 10 files
                    if indexed_count % 10 == 0:
                        print(json.dumps({
                            "type": "progress",
                            "indexed": indexed_count,
                            "current_file": str(file_path.name)
                        }), flush=True)

                except Exception as e:
                    error_count += 1
                    print(json.dumps({
                        "type": "warning",
                        "message": f"Failed to index {file_path}: {e}"
                    }), flush=True)

            return {
                "success": True,
                "indexed": indexed_count,
                "skipped": skipped_count,
                "errors": error_count,
                "directory": str(directory)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "indexing_error"
            }

    def index_file(self, file_path: str) -> Dict[str, Any]:
        """
        Index a single file.

        Args:
            file_path: Path to file

        Returns:
            Dict with indexing result
        """
        try:
            file_path = Path(file_path).expanduser()

            if not file_path.exists():
                return {
                    "success": False,
                    "error": f"File does not exist: {file_path}",
                    "type": "path_error"
                }

            # Read file content
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                # Skip binary files
                return {
                    "success": False,
                    "error": "Binary file, skipped",
                    "type": "encoding_error"
                }

            # Skip empty files
            if not content.strip():
                return {
                    "success": False,
                    "error": "Empty file, skipped",
                    "type": "empty_file"
                }

            # Generate file ID from path hash
            file_id = hashlib.md5(str(file_path).encode()).hexdigest()

            # Split into chunks for large files
            chunks = self._split_into_chunks(content, max_chunk_size=1000)

            # Generate embeddings
            embeddings = self.embedding_model.encode(chunks, show_progress_bar=False)

            # Store in ChromaDB
            for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
                chunk_id = f"{file_id}_{i}"

                self.collection.add(
                    ids=[chunk_id],
                    embeddings=[embedding.tolist()],
                    documents=[chunk],
                    metadatas=[{
                        "file_path": str(file_path),
                        "file_name": file_path.name,
                        "file_extension": file_path.suffix,
                        "chunk_index": i,
                        "total_chunks": len(chunks)
                    }]
                )

            return {
                "success": True,
                "file_path": str(file_path),
                "chunks": len(chunks)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "indexing_error"
            }

    def search(
        self,
        query: str,
        n_results: int = 5,
        file_extensions: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Search for relevant code snippets.

        Args:
            query: Search query
            n_results: Number of results to return
            file_extensions: Filter by file extensions

        Returns:
            Dict with search results
        """
        try:
            # Generate query embedding
            query_embedding = self.embedding_model.encode([query], show_progress_bar=False)[0]

            # Build where filter
            where_filter = None
            if file_extensions:
                where_filter = {
                    "file_extension": {"$in": file_extensions}
                }

            # Search ChromaDB
            results = self.collection.query(
                query_embeddings=[query_embedding.tolist()],
                n_results=n_results,
                where=where_filter
            )

            # Format results
            formatted_results = []
            for i in range(len(results['ids'][0])):
                formatted_results.append({
                    "id": results['ids'][0][i],
                    "document": results['documents'][0][i],
                    "metadata": results['metadatas'][0][i],
                    "distance": results['distances'][0][i] if 'distances' in results else None
                })

            return {
                "success": True,
                "query": query,
                "results": formatted_results,
                "count": len(formatted_results)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "search_error"
            }

    def get_context_for_query(
        self,
        query: str,
        n_results: int = 3,
        max_context_length: int = 4000
    ) -> str:
        """
        Get relevant context for a query to inject into prompts.

        Args:
            query: User query
            n_results: Number of code snippets to retrieve
            max_context_length: Maximum context length in characters

        Returns:
            Formatted context string
        """
        search_result = self.search(query, n_results=n_results)

        if not search_result["success"]:
            return ""

        context_parts = []
        current_length = 0

        for result in search_result["results"]:
            metadata = result["metadata"]
            document = result["document"]

            # Format context entry
            entry = f"\n# From {metadata['file_name']} ({metadata['file_extension']})\n```\n{document}\n```\n"

            # Check if adding this would exceed max length
            if current_length + len(entry) > max_context_length:
                break

            context_parts.append(entry)
            current_length += len(entry)

        return "\n".join(context_parts)

    def clear_collection(self) -> Dict[str, Any]:
        """Clear all indexed data."""
        try:
            self.client.delete_collection("codebase")
            self.collection = self.client.get_or_create_collection(
                name="codebase",
                metadata={"description": "Code files and documentation"}
            )

            return {
                "success": True,
                "message": "Collection cleared successfully"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "clear_error"
            }

    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about indexed data."""
        try:
            count = self.collection.count()

            # Get unique files
            all_metadata = self.collection.get()
            unique_files = set()
            if all_metadata and all_metadata['metadatas']:
                unique_files = {m['file_path'] for m in all_metadata['metadatas']}

            return {
                "success": True,
                "total_chunks": count,
                "unique_files": len(unique_files),
                "db_path": str(self.db_path)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "type": "stats_error"
            }

    def _split_into_chunks(self, text: str, max_chunk_size: int = 1000) -> List[str]:
        """
        Split text into chunks for embedding.

        Args:
            text: Text to split
            max_chunk_size: Maximum chunk size in characters

        Returns:
            List of text chunks
        """
        # Split by lines first
        lines = text.split('\n')

        chunks = []
        current_chunk = []
        current_size = 0

        for line in lines:
            line_size = len(line)

            # If single line exceeds max size, split it
            if line_size > max_chunk_size:
                # Save current chunk if any
                if current_chunk:
                    chunks.append('\n'.join(current_chunk))
                    current_chunk = []
                    current_size = 0

                # Split long line by words
                words = line.split()
                word_chunk = []
                word_size = 0

                for word in words:
                    if word_size + len(word) + 1 > max_chunk_size:
                        chunks.append(' '.join(word_chunk))
                        word_chunk = [word]
                        word_size = len(word)
                    else:
                        word_chunk.append(word)
                        word_size += len(word) + 1

                if word_chunk:
                    chunks.append(' '.join(word_chunk))

            # Normal line processing
            elif current_size + line_size + 1 > max_chunk_size:
                # Save current chunk
                chunks.append('\n'.join(current_chunk))
                current_chunk = [line]
                current_size = line_size
            else:
                current_chunk.append(line)
                current_size += line_size + 1

        # Add remaining chunk
        if current_chunk:
            chunks.append('\n'.join(current_chunk))

        return chunks


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(description="RAG System for Code")

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Index command
    index_parser = subparsers.add_parser("index", help="Index a directory")
    index_parser.add_argument("directory", type=str, help="Directory to index")
    index_parser.add_argument("--extensions", type=str, nargs="+", help="File extensions to include")
    index_parser.add_argument("--exclude", type=str, nargs="+", help="Patterns to exclude")

    # Search command
    search_parser = subparsers.add_parser("search", help="Search indexed code")
    search_parser.add_argument("query", type=str, help="Search query")
    search_parser.add_argument("--n-results", type=int, default=5, help="Number of results")
    search_parser.add_argument("--extensions", type=str, nargs="+", help="Filter by extensions")

    # Context command
    context_parser = subparsers.add_parser("context", help="Get context for query")
    context_parser.add_argument("query", type=str, help="Query")
    context_parser.add_argument("--n-results", type=int, default=3, help="Number of results")
    context_parser.add_argument("--max-length", type=int, default=4000, help="Max context length")

    # Stats command
    stats_parser = subparsers.add_parser("stats", help="Get statistics")

    # Clear command
    clear_parser = subparsers.add_parser("clear", help="Clear all indexed data")

    args = parser.parse_args()

    # Initialize RAG system
    rag = RAGSystem()

    if args.command == "index":
        result = rag.index_directory(
            directory_path=args.directory,
            extensions=args.extensions,
            exclude_patterns=args.exclude
        )
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "search":
        result = rag.search(
            query=args.query,
            n_results=args.n_results,
            file_extensions=args.extensions
        )
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "context":
        context = rag.get_context_for_query(
            query=args.query,
            n_results=args.n_results,
            max_context_length=args.max_length
        )
        print(context, flush=True)

    elif args.command == "stats":
        result = rag.get_stats()
        print(json.dumps(result, indent=2), flush=True)

    elif args.command == "clear":
        result = rag.clear_collection()
        print(json.dumps(result, indent=2), flush=True)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
