# Kotlin extension functions

An **extension function** adds a function to an existing type without inheriting from it or changing its source.
It is called with the same dot syntax as a member function.
Many Android APIs are extensions, for example Compose's `ComponentActivity.setContent { }`
([../Android/App/compose_intro.md](../Android/App/compose_intro.md#2-setcontent-from-the-activity-to-compose)) and most of `androidx.core:core-ktx`.

## 1. Syntax

```kotlin
fun ReceiverType.functionName(parameters): ReturnType {
    // `this` is the receiver object; `this.` can usually be omitted
}
```

+ **Receiver type**: the type being extended, e.g. `String`, `Int`, `ComponentActivity`.
+ **`this`**: the instance the function was called on.

```kotlin
fun String.shout(): String = uppercase() + "!"

fun main() {
    println("hello".shout())   // HELLO!
}
```

## 2. How it compiles

Extensions don't change the receiver class.
The compiler turns a top-level extension into a **static method** whose first parameter is the receiver,
in a class named after the file (`StringUtils.kt` → `StringUtilsKt`):

```java
// Roughly what the bytecode corresponds to
public final class StringUtilsKt {
    public static final String shout(String $this$shout) {
        return $this$shout.toUpperCase() + "!";
    }
}
```

So `"hello".shout()` is a static call with `"hello"` as the argument. From Java it is called as `StringUtilsKt.shout("hello")`.

## 3. Rules and gotchas

+ **Visibility**: an extension sees only what any outside code at that location sees: `public` members,
  and `internal` members in the same module. It can't access the receiver's `private` or `protected` members.
+ **Resolved statically**: which extension is called depends on the **declared (compile-time) type** of the expression,
  not the runtime type. Extensions are not virtual and can't be overridden.

```kotlin
open class Shape
class Circle : Shape()

fun Shape.name() = "Shape"
fun Circle.name() = "Circle"

val s: Shape = Circle()
println(s.name())   // "Shape": chosen by the declared type
```

+ **Members win**: if the class has a member with the same name and applicable parameters, the member is called and the extension is ignored (the IDE warns "extension is shadowed by a member").
+ **Nullable receivers**: an extension on `String?` can be called on `null`; check `this == null` inside.

```kotlin
fun String?.orDash(): String = if (this.isNullOrEmpty()) "-" else this
```

+ **Extension properties** exist too (`val String.lastChar: Char get() = this[length - 1]`), but they can't have a backing field, so no initializer.
+ **Scope**: an extension must be imported where it's used if it is declared in another package
  (e.g. `import androidx.activity.compose.setContent`). Android Studio's auto-import may not find it at first.

## 4. Function types with receiver

A lambda can also have a receiver: `T.() -> R`. Inside it, `this` is the receiver.
This is how `apply { }`, `buildString { }` and DSL builders (Gradle Kotlin DSL, Compose's `Column { }` scopes) work.

```kotlin
val sb = buildString {        // StringBuilder.() -> Unit
    append("duty=")
    append(50)
}
```

## Related notes

+ [deprecation_kotlin.md](deprecation_kotlin.md): deprecating Kotlin APIs
+ [../Android/App/compose_intro.md](../Android/App/compose_intro.md): `setContent { }` in an activity
+ [../Android/App/Groovy_kotlin_DSL.md](../Android/App/Groovy_kotlin_DSL.md): Gradle Kotlin DSL, built on lambdas with receivers

## Reference

+ [Extensions (Kotlin docs)](https://kotlinlang.org/docs/extensions.html)
+ [Function literals with receiver (Kotlin docs)](https://kotlinlang.org/docs/lambdas.html#function-literals-with-receiver)
+ [Calling Kotlin from Java (Kotlin docs)](https://kotlinlang.org/docs/java-to-kotlin-interop.html)
