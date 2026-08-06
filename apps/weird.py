#!/usr/bin/env python3
# app.py - Flask web UI for the file archive
# Run: python3 app.py
# Open: http://localhost:8080

import os
import sys
import sqlite3
import json
from flask import Flask, render_template, request, jsonify

# ----------------------------------------------------------------------------
# 1. CONFIGURATION
# ----------------------------------------------------------------------------
# Database path: assumes app.py is in apps/ and DB is in the parent folder
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB_PATH = os.path.join(BASE_DIR, 'file_archive.db')

DB_PATH = os.environ.get('DB_PATH', DEFAULT_DB_PATH)
TEMPLATE_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates')
STATIC_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')

app = Flask(
    __name__,
    template_folder=TEMPLATE_FOLDER,
    static_folder=STATIC_FOLDER
)

# ----------------------------------------------------------------------------
# 2. DATABASE HELPERS
# ----------------------------------------------------------------------------
def get_db():
    """Return a SQLite connection with row factory (dict-like rows)."""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        print(f"Database connection error: {e}", file=sys.stderr)
        return None

def format_size(bytes_val):
    """Convert bytes to a human-readable string."""
    if bytes_val is None:
        return "0 B"
    try:
        bytes_val = int(bytes_val)
    except (ValueError, TypeError):
        return "0 B"
    if bytes_val == 0:
        return "0 B"
    k = 1024
    sizes = ['B', 'KB', 'MB', 'GB', 'TB']
    i = 0
    while bytes_val >= k and i < len(sizes) - 1:
        bytes_val /= k
        i += 1
    return f"{bytes_val:.2f} {sizes[i]}"

# ----------------------------------------------------------------------------
# 3. ROUTES
# ----------------------------------------------------------------------------
@app.route('/')
def index():
    """Serve the main search page."""
    return render_template('index.html')

@app.route('/browse')
def browse():
    """Serve the hierarchy browser page."""
    return render_template('browse.html')

# ----------------------------------------------------------------------------
# 3.1. API: Statistics
# ----------------------------------------------------------------------------
@app.route('/api/stats')
def api_stats():
    """Return summary statistics for the dashboard."""
    conn = get_db()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor()
    stats = {}

    try:
        # Total files
        cursor.execute("SELECT COUNT(*) FROM files")
        stats['total_files'] = cursor.fetchone()[0]

        # Total size
        cursor.execute("SELECT SUM(size_bytes) FROM files")
        total_bytes = cursor.fetchone()[0] or 0
        stats['total_bytes'] = total_bytes
        stats['total_size_str'] = format_size(total_bytes)

        # By file type
        cursor.execute("SELECT file_type, COUNT(*) FROM files GROUP BY file_type")
        stats['by_type'] = [{'type': row[0] or 'unknown', 'count': row[1]} for row in cursor.fetchall()]

        # By device type
        cursor.execute("""
            SELECT device_type, COUNT(*) 
            FROM v_files_full 
            GROUP BY device_type
        """)
        stats['by_device'] = [{'type': row[0] or 'unknown', 'count': row[1]} for row in cursor.fetchall()]

        return jsonify(stats)
    except sqlite3.Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 3.2. API: Search
# ----------------------------------------------------------------------------
@app.route('/api/search')
def api_search():
    """
    Search for files based on query type.
    Query params:
        q  : search string
        type: md5 | filename | type | tag | category
    """
    q = request.args.get('q', '').strip()
    search_type = request.args.get('type', 'filename')

    if not q:
        return jsonify([])

    conn = get_db()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    cursor = conn.cursor()

    try:
        if search_type == 'md5':
            cursor.execute(
                "SELECT * FROM v_files_full WHERE md5 LIKE ?",
                (f'%{q}%',)
            )
        elif search_type == 'filename':
            cursor.execute(
                "SELECT * FROM v_files_full WHERE filename LIKE ?",
                (f'%{q}%',)
            )
        elif search_type == 'type':
            cursor.execute(
                "SELECT * FROM v_files_full WHERE file_type = ?",
                (q,)
            )
        elif search_type == 'tag':
            cursor.execute(
                "SELECT * FROM v_files_full WHERE tags LIKE ?",
                (f'%{q}%',)
            )
        elif search_type == 'category':
            cursor.execute("""
                SELECT f.* 
                FROM v_files_full f
                JOIN file_hierarchy fh ON f.file_id = fh.file_id
                JOIN hierarchy h ON fh.category_id = h.category_id
                WHERE h.path LIKE ?
            """, (f'%{q}%',))
        else:
            return jsonify({'error': f'Unknown search type: {search_type}'}), 400

        rows = cursor.fetchall()
        results = []
        for row in rows:
            item = dict(row)
            item['size_str'] = format_size(item.get('size_bytes'))
            results.append(item)

        return jsonify(results)
    except sqlite3.Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 3.3. API: File Details (by MD5)
# ----------------------------------------------------------------------------
@app.route('/api/files/<md5>')
def api_file_details(md5):
    """Return full details for a specific file by MD5."""
    conn = get_db()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM v_files_full WHERE md5 = ?", (md5,))
        row = cursor.fetchone()

        if not row:
            return jsonify({'error': 'File not found'}), 404

        result = dict(row)
        result['size_str'] = format_size(result.get('size_bytes'))

        # Parse metadata JSON if present
        if result.get('metadata'):
            try:
                result['metadata'] = json.loads(result['metadata'])
            except (json.JSONDecodeError, TypeError):
                pass  # leave as string

        if result.get('media_assets'):
            try:
                result['media_assets'] = json.loads(result['media_assets'])
            except (json.JSONDecodeError, TypeError):
                pass

        return jsonify(result)
    except sqlite3.Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 3.4. API: Hierarchy (Flat List)
# ----------------------------------------------------------------------------
@app.route('/api/hierarchy')
def api_hierarchy():
    """Return the full hierarchy as a flat list (for browse.html)."""
    conn = get_db()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT 
                category_id,
                parent_id,
                name,
                icon,
                path,
                description
            FROM hierarchy
            ORDER BY path
        """)
        rows = cursor.fetchall()
        results = [dict(row) for row in rows]
        return jsonify(results)
    except sqlite3.Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 3.5. API: Hierarchy (Nested Tree)
# ----------------------------------------------------------------------------
@app.route('/api/hierarchy/tree')
def api_hierarchy_tree():
    """
    Return the hierarchy as a nested tree structure.
    Useful for advanced UI components (e.g., collapsible tree views).
    """
    conn = get_db()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT 
                category_id,
                parent_id,
                name,
                icon,
                path
            FROM hierarchy
        """)
        rows = cursor.fetchall()

        # Build a map of nodes
        nodes = {}
        for row in rows:
            node = dict(row)
            node['children'] = []
            nodes[node['category_id']] = node

        # Link children to parents
        roots = []
        for node_id, node in nodes.items():
            parent_id = node.get('parent_id')
            if parent_id and parent_id in nodes:
                nodes[parent_id]['children'].append(node)
            else:
                roots.append(node)

        return jsonify(roots)
    except sqlite3.Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# ----------------------------------------------------------------------------
# 4. ERROR HANDLERS
# ----------------------------------------------------------------------------
@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Internal server error'}), 500

# ----------------------------------------------------------------------------
# 5. MAIN
# ----------------------------------------------------------------------------
if __name__ == '__main__':
    # Verify database exists before starting
    if not os.path.exists(DB_PATH):
        print(f"⚠️  Database not found at: {DB_PATH}")
        print("   Please run: ./scripts/installer/db_init.sh")
        print("   Or set DB_PATH environment variable.")
    else:
        print(f"✅ Database found: {DB_PATH}")

    print(f"🌐 Starting web server at http://localhost:8080")
    print(f"   Search:  http://localhost:8080")
    print(f"   Browse:  http://localhost:8080/browse")
    print("")
    app.run(host='0.0.0.0', port=8080, debug=True)
