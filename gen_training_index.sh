#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRAINING_DIR="$SCRIPT_DIR/YBTraining"
OUTPUT="$SCRIPT_DIR/training.html"

echo "Generating $OUTPUT..."

cat > "$OUTPUT" <<'HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>YB Training Materials</title>
  <style>
    body {
      font-family: monospace;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 20px;
      background: #1a1a1a;
      color: #d4d4d4;
    }
    h1 {
      font-size: 1.2em;
      color: #9cdcfe;
      border-bottom: 1px solid #444;
      padding-bottom: 8px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th {
      text-align: left;
      color: #888;
      font-weight: normal;
      padding: 4px 12px 4px 0;
      border-bottom: 1px solid #333;
    }
    td {
      padding: 5px 12px 5px 0;
      border-bottom: 1px solid #2a2a2a;
    }
    a {
      color: #ce9178;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
    .size { color: #888; text-align: right; padding-right: 0; }
    .date { color: #888; }
    .empty { color: #666; margin-top: 20px; }
  </style>
</head>
<body>
  <h1>Index of /YBTraining</h1>
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Last Modified</th>
        <th class="size">Size</th>
      </tr>
    </thead>
    <tbody>
HEADER

# List files in YBTraining, sorted by name
files=("$TRAINING_DIR"/*)

if [ ! -e "${files[0]}" ]; then
  echo '      <tr><td colspan="3" class="empty">No files yet.</td></tr>' >> "$OUTPUT"
else
  for filepath in $(ls -1 "$TRAINING_DIR" | sort); do
    fullpath="$TRAINING_DIR/$filepath"
    [ -f "$fullpath" ] || continue

    mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$fullpath")
    size_bytes=$(stat -f "%z" "$fullpath")

    if [ "$size_bytes" -ge 1048576 ]; then
      size_human=$(echo "scale=1; $size_bytes/1048576" | bc)" MB"
    elif [ "$size_bytes" -ge 1024 ]; then
      size_human=$(echo "scale=1; $size_bytes/1024" | bc)" KB"
    else
      size_human="${size_bytes} B"
    fi

    cat >> "$OUTPUT" <<ROW
      <tr>
        <td><a href="YBTraining/$filepath">$filepath</a></td>
        <td class="date">$mod_date</td>
        <td class="size">$size_human</td>
      </tr>
ROW
  done
fi

# Get current timestamp
GENERATED=$(date "+%Y-%m-%d %H:%M")

cat >> "$OUTPUT" <<FOOTER
    </tbody>
  </table>
  <p style="color:#555; font-size:0.85em; margin-top:24px;">Generated $GENERATED</p>
</body>
</html>
FOOTER

echo "Done: $OUTPUT"
