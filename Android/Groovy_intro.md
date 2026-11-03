# Groovy for reading Gradle scripts

Groovy is a JVM language with optional typing. Most Java source is also valid Groovy, but not all of it:
for example, Java array initializers `int[] a = {1, 2}` aren't, and `==` means `equals()` in Groovy.
Android projects meet Groovy in `build.gradle` / `settings.gradle`.
New Android Studio projects use the Kotlin DSL (`.gradle.kts`) since Android Studio Giraffe (2023),
so Groovy matters mainly for older projects and tutorials.
The side-by-side comparison is in [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md).

## 1. Syntax you need for build scripts

### 1.1 Semicolons, parentheses, `return`

Semicolons are optional. Parentheses are optional for a top-level method call with arguments.
The last expression of a method or closure is its return value.

```groovy
println("hi")
println "hi"                  // same call

String greeting() { "Hello" } // implicit return
```

So `implementation 'androidx.core:core-ktx:1.13.1'` in Gradle is just the method call `implementation('androidx.core:core-ktx:1.13.1')`.

### 1.2 `def` is dynamic typing

```groovy
def version = 34          // static type is Object; the value is an Integer at run time
version = "thirty-four"   // allowed: the variable has no fixed type
int sdk = 34              // explicit type, checked when assigned
```

`def` doesn't infer a static type (that's Kotlin's `val`). Groovy resolves the type at run time.

### 1.3 Strings: single vs double quotes

```groovy
def name = "Alice"
println 'Hi $name'        // Hi $name     : single quotes are plain java.lang.String
println "Hi $name"        // Hi Alice     : double quotes are a GString (interpolation)
println "Next: ${34 + 1}" // Next: 35     : ${} for expressions
println '''multi
line'''                   // triple quotes: multi-line strings
```

In Gradle, `"$rootDir/keys"` works but `'$rootDir/keys'` doesn't.

### 1.4 Lists, maps, named arguments

```groovy
def abis = ['arm64-v8a', 'x86_64']                // java.util.ArrayList
def sdk  = [min: 24, target: 34]                  // LinkedHashMap; keys are strings
println abis[0]                                   // arm64-v8a
println sdk.min                                   // 24 (same as sdk['min'])

// A map literal as the first argument can be written as named arguments:
implementation group: 'androidx.core', name: 'core-ktx', version: '1.13.1'
```

### 1.5 Closures and delegates (how Gradle blocks work)

A closure is a block of code `{ params -> body }`. A single parameter is available as `it`.

```groovy
def twice = { x -> x * 2 }
[1, 2, 3].each { println twice(it) }
```

`android { ... }` is a method call whose last argument is a closure.
Gradle sets the closure's **delegate** to the `android` extension object,
so `compileSdk = 34` inside the closure sets a property of that object.
This is the Groovy counterpart of Kotlin's "lambda with receiver".

### 1.6 Null safety and Groovy truth

```groovy
String user = null
println user?.toUpperCase()     // null instead of NullPointerException
println user ?: 'guest'         // Elvis operator: guest
if ('') println 'never'         // "Groovy truth": null, 0, '', [] and [:] are false
```

## 2. Property assignment in Gradle

```groovy
android {
    namespace = 'com.example.myapp'   // preferred: explicit assignment
    compileSdk = 34

    defaultConfig {
        applicationId = 'com.example.myapp'
        minSdk = 24
        targetSdk = 34
    }
}
```

Older scripts write `compileSdk 34` (the "space assignment").
That isn't Groovy syntax: Gradle generates a method `compileSdk(value)` at run time.
Gradle 8.12 deprecated these generated methods, and they will be removed in Gradle 10, so use `name = value`.

## Related notes

+ [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md): the same build script in Groovy and Kotlin DSL
+ [Kotlin_DSL.md](Kotlin_DSL.md), [building_note.md](building_note.md)

## Reference

+ [Groovy documentation: syntax, differences with Java](https://groovy-lang.org/documentation.html)
+ [Gradle: Groovy DSL primer](https://docs.gradle.org/current/userguide/groovy_build_script_primer.html)
+ [Gradle 8 upgrade guide: "space assignment" deprecation](https://docs.gradle.org/current/userguide/upgrading_version_8.html)
