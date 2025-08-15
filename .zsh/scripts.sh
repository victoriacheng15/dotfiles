create_workflow_folder() {
  mkdir -p .github/workflows
  echo "✅ Created .github/workflows directory"
}

first_commit() {
  git add .
  git commit -m "Initial commit"
  echo "✅ Initial commit created"
}

ignore_files() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "📄 Supported .gitignore types:"
    npx gitignore -types
    return 0
  fi

  if [[ "$#" -eq 0 ]]; then
    echo "❌ Please provide at least one language/framework (e.g., node, python)"
    echo "ℹ️ Use 'ignore_files --help' to list available types"
    return 1
  fi

  npx gitignore "$@"
  echo "✅ .gitignore generated for: $*"
}
