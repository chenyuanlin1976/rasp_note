# Compare Markdown, YAML, and JSON

Comparing Markdown, YAML, and JSON is essentially comparing 3 completely different tools designed for entirely different jobs.  
While all 3 are text-based formats read by humans and machines alike,  
their primary purposes set them apart:  

+ **Markdown** is for styling and writing text,  
+ **YAML** is for human-readable configuration,  
+ **JSON** is for data interchange.

## Detailed Breakdown

### Markdown (.md)

+ What it is: A lightweight markup language with *plain-text-formatting syntax*.
+ Best Used For: README files, blogs, documentation, note-taking, and writing content that can be easily converted to HTML.
+ Key Characteristic: It prioritizes the human reader above all else. A raw Markdown file is completely readable as-is without rendering.
+ Note: It can be combined with YAML at the top of a file (called Frontmatter) to store metadata for static site generators.

### YAML (.yaml / .yml)

+ What it is: A human-friendly data serialization language designed to be easily readable and writeable.
+ Best Used For: Configuration files (e.g., Docker Compose, GitHub Actions, Kubernetes, CI/CD pipelines).
+ Key Characteristic: It relies heavily on *indentation (spaces, never tabs)* and  
  whitespace rather than brackets or braces to define structure, making it very clean for humans to edit.

### JSON (JavaScript Object Notation)

+ What it is: A standardized format built on **key-value pairs** and ordered lists (**arrays**).
+ Best Used For: Web APIs, transmitting data between a server and a web application, and NoSQL databases.
+ Key Characteristic: It is strict, unambiguous, and universally supported by almost every programming language natively.  
  Unlike YAML, syntax errors (like a missing comma or quote) will cause a JSON parser to fail immediately.

## Key Comparison

### Markdown

1. Primary Purpose: Documentation & text formatting
2. Human Readability: Extremely high (looks like plain text)
3. Machine Parsability: Low (parsers extract text/links/headers)
4. Data Types Supported: Text, lists, links (limited metadata via Frontmatter)
5. Syntax Style: Plain text + symbols (#, *, -)

### YAML

1. Primary Purpose: Configuration files & metadata
2. Human Readability: High (clean, minimalist, indentation-based)
3. Machine Parsability: High
4. Data Types Supported: Scalars, lists, nested maps, booleans, null
5. Syntax Style: Indentation & colons (no brackets)

### JSON

1. Primary Purpose: Data interchange & APIs
2. Human Readability: Moderate (can get cluttered with brackets/quotes)
3. Machine Parsability: Extremely high (natively supported by most languages)
4. Data Types Supported: Strings, numbers, booleans, null, arrays, objects
5. Syntax Style: Braces ({}), brackets ([]), double quotes ("")

## Side-by-Example Comparison

```markdown
# User Profile: John Doe

* **Age:** 30
* **Active:** True
* **Skills:**
  * Python
  * JavaScript
  * Docker
```

```yaml
user:
  name: John Doe
  age: 30
  active: true
  skills:
    - Python
    - JavaScript
    - Docker
```

```json
{
  "user": {
    "name": "John Doe",
    "age": 30,
    "active": true,
    "skills": [
      "Python",
      "JavaScript",
      "Docker"
    ]
  }
}
```
