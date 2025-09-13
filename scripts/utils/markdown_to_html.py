#!/usr/bin/env python3
"""
Markdown to HTML Converter Utility
Converts markdown content to HTML with support for Dart syntax highlighting
"""

import re
import sys
import argparse

def convert_markdown_to_html(content):
    """
    Convert markdown content to HTML with enhanced code block handling
    
    Args:
        content (str): Markdown content to convert
        
    Returns:
        str: HTML content
    """
    # Handle code blocks first (multiline)
    content = re.sub(
        r'```dart\n?([\s\S]*?)```',
        r'<pre class="language-dart line-numbers"><code class="language-dart">\1</code></pre>',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    content = re.sub(
        r'```([a-zA-Z]*)\n?([\s\S]*?)```',
        r'<pre class="language-\1 line-numbers"><code class="language-\1">\2</code></pre>',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    content = re.sub(
        r'```\n?([\s\S]*?)```',
        r'<pre class="language-dart line-numbers"><code class="language-dart">\1</code></pre>',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Handle inline code
    content = re.sub(r'`([^`\n]+)`', r'<code>\1</code>', content)
    
    # Handle headers
    content = re.sub(r'^# (.+)$', r'<h1>\1</h1>', content, flags=re.MULTILINE)
    content = re.sub(r'^## (.+)$', r'<h2>\1</h2>', content, flags=re.MULTILINE)
    content = re.sub(r'^### (.+)$', r'<h3>\1</h3>', content, flags=re.MULTILINE)
    content = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', content, flags=re.MULTILINE)
    
    # Handle lists
    lines = content.split('\n')
    result = []
    in_ul = False
    in_ol = False
    
    for line in lines:
        if re.match(r'^- ', line):
            if not in_ul:
                result.append('<ul>')
                in_ul = True
            if in_ol:
                result.append('</ol>')
                in_ol = False
            result.append(f'<li>{line[2:]}</li>')
        elif re.match(r'^[0-9]+\\. ', line):
            if not in_ol:
                result.append('<ol>')
                in_ol = True
            if in_ul:
                result.append('</ul>')
                in_ul = False
            pattern = r'^[0-9]+\\. '
            cleaned_line = re.sub(pattern, '', line)
            result.append(f'<li>{cleaned_line}</li>')
        else:
            if in_ul:
                result.append('</ul>')
                in_ul = False
            if in_ol:
                result.append('</ol>')
                in_ol = False
            result.append(line)
    
    if in_ul:
        result.append('</ul>')
    if in_ol:
        result.append('</ol>')
    
    content = '\n'.join(result)
    
    # Handle bold and italic
    content = re.sub(r'\*\*([^\*]+)\*\*', r'<strong>\1</strong>', content)
    content = re.sub(r'\*([^\*]+)\*', r'<em>\1</em>', content)
    
    # Handle links
    content = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2">\1</a>', content)
    
    # Wrap paragraphs
    lines = content.split('\n')
    result = []
    for line in lines:
        if line.strip() and not line.startswith('<') and not line == '<br>':
            result.append(f'<p>{line}</p>')
        else:
            result.append(line)
    
    return '\n'.join(result)

def convert_file(input_file, output_file=None, template_file=None, title="Document"):
    """
    Convert a markdown file to HTML
    
    Args:
        input_file (str): Path to input markdown file
        output_file (str, optional): Path to output HTML file. If None, prints to stdout
        template_file (str, optional): Path to HTML template file
        title (str): Title for the HTML document
    """
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        html_content = convert_markdown_to_html(content)
        
        # Use template if provided
        if template_file and output_file:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    template = f.read()
                
                # Replace placeholders in template
                final_html = template.replace('{{TITLE}}', title)
                final_html = final_html.replace('{{CONTENT}}', html_content)
                
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(final_html)
                print(f"Converted {input_file} to {output_file} using template {template_file}")
                return
            except FileNotFoundError:
                print(f"Warning: Template file '{template_file}' not found, using basic HTML", file=sys.stderr)
        
        # Fallback to basic HTML
        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(html_content)
            print(f"Converted {input_file} to {output_file}")
        else:
            print(html_content)
            
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error converting file: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    """
    Main function for command-line usage
    """
    parser = argparse.ArgumentParser(
        description='Convert markdown to HTML with Dart syntax highlighting support'
    )
    parser.add_argument('input_file', help='Input markdown file')
    parser.add_argument('-o', '--output', help='Output HTML file (default: stdout)')
    parser.add_argument('-t', '--template', help='HTML template file')
    parser.add_argument('--title', default='Document', help='Title for the HTML document')
    
    args = parser.parse_args()
    
    convert_file(args.input_file, args.output, args.template, args.title)

if __name__ == '__main__':
    if len(sys.argv) == 2 and not sys.argv[1].startswith('-'):
        # Legacy mode: just convert and print to stdout
        convert_file(sys.argv[1])
    else:
        main()