# android directory structure

An Android project follows a standardized Gradle-based **directory structure** separating app logic, platform resources, and configuration files.

## Core Project Directories

+ app/src/main/`java`/ (or `kotlin`/): Contains your app's source code, written in Kotlin or Java, organized into standard package structures.
+ app/src/main/`res`/: Stores non-code resources divided into subdirectories:
  + layout/: XML-based UI design files.
  + values/: Strings (strings.xml), colors, styles, and dimensions.
  + drawable/ & mipmap/: Vector assets, icons, and bitmap images.
  + navigation/: Jetpack Navigation graphs (if used).
+ app/src/main/`AndroidManifest.xml`: The core configuration file declaring app components, permissions, and minimum API requirements.
+ `build.gradle.kts` (Project & Module levels): Build scripts defining dependencies, compilation SDK versions, and build variants.
+ `settings.gradle.kts`: Defines global repositories and registers all sub-modules included in the workspace.

## Package Organization Strategies

How you structure packages inside your source directory dictates the scalability and maintainability of your app.  
Modern Android development favors modular or feature-driven approaches over traditional flat structures.

+ Layer-First Architecture (Traditional): Classes are grouped by their technical role. This works well for small or simple applications.
  + com.example.app.ui/ (Activities, Fragments, Adapters, ViewModels)
  + com.example.app.model/ (Data classes, DTOs, database entities)
  + com.example.app.network/ (API client configuration, Retrofit interfaces)
+ Feature-First / Clean Architecture (Modern): Code is split by business functionality,  
  isolating features from one another to improve scalability and team collaboration.
  + com.example.app.core/ (Shared utilities, design system, network base modules)
  + com.example.app.feature.login/ (Login-specific UI, ViewModels, and local data logic)
  + com.example.app.feature.profile/ (User profile UI, state management, and local models)
