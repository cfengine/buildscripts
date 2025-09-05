if ! command -v shfmt >/dev/null; then
  echo "shfmt must be installed"
  exit 1
fi
grep -Erl '^(#!/(bin|usr/bin)/(env )?(sh|bash))' build-scripts/ | while read -r file; do
    if shfmt --diff --indent 4 "$file"; then
        echo "No formatting needed for file '$file'"
    else
        echo "Formatting file '$file'..."
        shfmt --write --indent 4 "$file"
        git add "$file"
        git commit -m "$(basename "$file"): formatted script with shfmt"
    fi
done
