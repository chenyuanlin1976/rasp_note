# Mermaid intro

Mermaid is a popular diagramming and charting tool that uses text-based markdown-inspired code to generate dynamic diagrams visually.  
Instead of dragging and dropping shapes in a GUI editor, you write simple text descriptions, and Mermaid renders them in real-time.

Here is a quick, practical guide to getting started with Mermaid syntax.

## 1. Basic Structure (Flowcharts)

To create a flowchart, you first declare the orientation using **graph** or flowchart, followed by a direction:

+ **TD** or **TB** = Top to Bottom
+ **LR** = Left to Right
+ **BT** = Bottom to Top
+ **RL** = Right to Left

```Mermaid
graph LR
    A[Start] --> B{Is it working?}
    B -- Yes --> C[Great!]
    B -- No --> D[Debug]
```

## 2. Node Shapes & Brackets

The shape of a node depends on the type of brackets you use:

+ A[Rectangle] : Standard rectangular box
+ A(Rounded) : Box with rounded corners
+ A{Decision} : Diamond shape (often used for conditions)
+ A([Stadium]) : Pill/stadium shape (good for start/end)
+ A[(Database)] : Cylinder shape (database)
+ A((Circle)) : Circular node

## 3. Connecting Lines (Edges)

Arrows and lines define the relationship and data flow between nodes:

+ A --> B : Arrowhead line
+ A --- B : Open line (no arrows)
+ A -.-> B : Dotted line
+ A ==> B : Thick/bold arrow
+ A -- "Text" --> B : Line with text/labels in the middle

## 4. Other Popular Diagram Types

Mermaid supports many diagram types beyond flowcharts. You just change the keyword at the top:

+ Sequence Diagrams: sequenceDiagram (for visualizing system interactions/API calls over time)
+ Gantt Charts: gantt (for project management and timelines)
+ Class Diagrams: classDiagram (for object-oriented programming structures)
+ Git Graphs: gitGraph (for visualizing branching and commits)

## Reference

+ [Draw-Diagrams](https://support.typora.io/Draw-Diagrams-With-Markdown/)
