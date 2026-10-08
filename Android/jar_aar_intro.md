# JAR, AAR intro

When packaging code for Android developers, JAR and AAR are the 2 standard library formats.  
While both contain compiled Java/Kotlin code, they differ significantly in what else they can bundle.

## 1. JAR (Java Archive)

A JAR file is a standard, cross-platform Java format containing zipped, compiled .class files (bytecode).

+ What it can contain: Compiled code (Java/Kotlin classes, including generated AIDL stub classes) and metadata.
+ What it CANNOT contain: Android-specific resources like layouts, drawables, strings, or an AndroidManifest.xml.
+ When to use it: Perfect if your library is purely logic-based, data processing, or contains pure Java interfaces  
  (like raw AIDL binder stubs and basic data classes) that do NOT interact with Android UI elements, resources, or application contexts.

## 2. AAR (Android Archive)

An AAR file is an Android-specific package format.  
It looks like a ZIP file and is essentially the Android equivalent of a JAR file on steroids.

+ What it can contain:
  + Compiled Java/Kotlin code (and AIDL stubs).
  + Android Resources (layouts, values, drawables, raw assets).
  + An AndroidManifest.xml (which can declare permissions, components like services/receivers, or hardware features).
  + Native libraries (.so files if your service includes C/C++ JNI code).
+ When to use it: Ideal if your GPIO SDK needs to bundle its own internal UI components, manifest permissions,  
  native .so drivers, or context-aware helper classes.

## Comparison Summary

| Feature                         | JAR (Java Archive)     | AAR (Android Archive) |
| ------------------------------- | ---------------------- | --------------------- |
| Platform                        | Standard Java/ Android | Android Only          |
| Compiled Code (.class)          | Yes                    | Yes                   |
| Android Resources (XML, images) | No                     | Yes                   |
| AndroidManifest.xml             | No                     | Yes                   |
| Native Libraries (.so)          | No                     | Yes                   |
| Best for your GPIO project	  | note1                  | note2                 |

note1: Raw AIDL stubs + basic helper logic
note2: A full SDK wrapper with custom logic, context handling, or resources
