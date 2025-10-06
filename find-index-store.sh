#!/bin/bash

# Helper script to find the IndexStore path for an Xcode project

set -e

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [PROJECT_NAME]

Find the IndexStore path for an Xcode project.

Arguments:
    PROJECT_NAME    The name of your Xcode project (optional)

Examples:
    $0                      # List all available projects
    $0 MyProject           # Find IndexStore for MyProject

EOF
    exit 1
}

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# Check if DerivedData exists
if [ ! -d "$DERIVED_DATA" ]; then
    echo "❌ DerivedData directory not found at: $DERIVED_DATA"
    exit 1
fi

# If no argument provided, list all projects
if [ $# -eq 0 ]; then
    echo "📁 Available Xcode projects in DerivedData:"
    echo ""
    
    count=0
    for dir in "$DERIVED_DATA"/*; do
        if [ -d "$dir" ]; then
            basename=$(basename "$dir")
            project_name="${basename%-*}"
            index_store="$dir/Index.noindex/DataStore"
            
            if [ -d "$index_store" ]; then
                count=$((count + 1))
                echo "[$count] $project_name"
                echo "    Path: $index_store"
                echo ""
            fi
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "❌ No projects with index stores found."
        echo "   Build your project in Xcode to generate the index."
    fi
    
    exit 0
fi

# Search for the specified project
PROJECT_NAME="$1"
echo "🔍 Searching for project: $PROJECT_NAME"
echo ""

found=false

for dir in "$DERIVED_DATA"/*; do
    if [ -d "$dir" ]; then
        basename=$(basename "$dir")
        
        # Check if the directory name starts with the project name
        if [[ "$basename" == "$PROJECT_NAME"-* ]]; then
            index_store="$dir/Index.noindex/DataStore"
            
            if [ -d "$index_store" ]; then
                echo "✅ Found IndexStore for $PROJECT_NAME"
                echo ""
                echo "📇 IndexStore Path:"
                echo "   $index_store"
                echo ""
                echo "📋 Full DerivedData Path:"
                echo "   $dir"
                echo ""
                
                # Check if there are any index files
                file_count=$(find "$index_store" -type f 2>/dev/null | wc -l)
                echo "📊 Index contains $file_count files"
                
                found=true
                break
            else
                echo "⚠️  Found project directory but no IndexStore."
                echo "   Build the project in Xcode to generate the index."
                echo "   Project directory: $dir"
            fi
        fi
    fi
done

if [ "$found" = false ]; then
    echo "❌ Could not find IndexStore for: $PROJECT_NAME"
    echo ""
    echo "Available projects:"
    for dir in "$DERIVED_DATA"/*; do
        if [ -d "$dir" ]; then
            basename=$(basename "$dir")
            project_name="${basename%-*}"
            echo "  - $project_name"
        fi
    done
fi
