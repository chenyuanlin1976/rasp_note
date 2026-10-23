# Groovy introduction

Groovy is a powerful, dynamically typed language for the Java Virtual Machine (JVM).  
Because it is built on top of Java, any valid Java code is technically valid Groovy code.  
However, Groovy adds a lot of **syntactic sugar** to make code shorter, cleaner, and much more expressive.

Groovy is widely known in the Android ecosystem  
because it has historically been the primary language used for Gradle build scripts (`build.gradle`).

## Key Groovy Syntax Features

### 1. Optional Semicolons and return

In Groovy, semicolons at the end of lines are completely optional.  
Furthermore, the `return` keyword is optional for the last expression in a method or closure.

```groovy
// Java style (also works in Groovy)
String getGreeting() {
    return "Hello, World!";
}

// Groovy style
String getGreeting() {
    "Hello, World!"
}
```

### 2. Dynamic Typing with `def`

While Groovy supports static typing (like Java),  
you can use the `def` keyword to let the compiler figure out the data type automatically.

```groovy
def name = "Android"   // Inferred as String
def version = 34       // Inferred as Integer
def isCool = true      // Inferred as Boolean
```

### 3. String Interpolation (GString)

Groovy introduces double-quoted strings called GStrings,  
which allow you to embed variables and expressions directly into text using `$`.

```groovy
def developer = "Alice"
def message = "Welcome back, $developer!" 
println(message) // Output: Welcome back, Alice!

// For expressions, wrap in curly braces:
println("Next version: ${version + 1}") // Output: Next version: 35
```

### 4. Closures

A closure is an anonymous block of code that can take arguments, return values, and be assigned to variables or passed to methods.  
They are heavily used in Groovy and Gradle.

+ If a closure takes a single parameter, Groovy provides an implicit variable named `it`.

```groovy
// Defining a closure
def sayHello = { name -> "Hello, $name" }
println(sayHello("Bob")) // Output: Hello, Bob

// Using a closure with a list
def numbers = [1, 2, 3, 4]
numbers.each { println(it * 2) } // 'it' represents the current element
```

### 5. Simplified Collections (Lists and Maps)

Groovy provides native, concise literal syntax for creating lists and maps without cumbersome factory methods.

```groovy
// List
def fruits = ['Apple', 'Banana', 'Orange']
println fruits[1] // Output: Banana

// Map (Dictionary)
def config = [compileSdk: 34, targetSdk: 34, minSdk: 24]
println config['compileSdk'] // Output: 34
println config.minSdk        // Property-style access also works!
```

### 6. Safe Navigation Operator (`?.`)

To avoid pesky `NullPointerExceptions` when checking if an object is null, Groovy provides the safe navigation operator.  
If the object before `?.` is null, it simply returns null instead of crashing.

```groovy
String user = null
println(user?.toUpperCase()) // Output: null (instead of crashing)
```

## Example: Groovy in Action (Gradle Style)

If you look at an older Android `build.gradle` file,  
you are looking at Groovy syntax leveraging blocks (closures) and implicit method calls:

```groovy
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.example.myapp"
        minSdk 24
        targetSdk 34
    }
}
```

Note: While **Android has been transitioning toward Kotlin DSL** (`build.gradle.kts`) for modern projects,  
understanding Groovy syntax remains essential for maintaining legacy codebases and reading community tutorials.
