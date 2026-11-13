# Android framework and app architecture

"The framework" in Android development usually means one of two things:

+ the **Android framework**: the system layer of Java/Kotlin APIs that apps call (section 1), or
+ the **app architecture**: how an app's own code is split into layers (section 2).

## 1. The Android framework (system level)

The Android platform is a stack of layers:

```text
+--------------------------------------------------+
| System apps and your apps                        |
+--------------------------------------------------+
| Java API framework (android.*)                   |
+------------------------+-------------------------+
| Native C/C++ libraries | Android Runtime (ART)   |
+------------------------+-------------------------+
| Hardware abstraction layer (HAL)                 |
+--------------------------------------------------+
| Linux kernel (drivers, Binder, power management) |
+--------------------------------------------------+
```

The **Java API framework** sits on top of ART and the native libraries.
App code calls these APIs instead of talking to drivers or C++ libraries directly.
Main parts:

| Part | What it does |
| --- | --- |
| View system | UI elements: buttons, lists, text fields, layouts |
| Activity manager | Activity lifecycles and the back stack (tasks) |
| Resource manager | Non-code resources: localized strings, drawables, layout XML |
| Notification manager | Status bar notifications |
| Package manager | Installed apps, their components and permissions |
| Content providers | Shared data such as contacts and media |

Most of these managers are system services running in the `system_server` process.
The `android.*` classes in the app are client-side proxies that call them over **Binder**; see [../IPC/Binder_intro.md](../IPC/Binder_intro.md).

## 2. App architecture (code level)

Google's architecture guide recommends splitting an app into layers by responsibility:

```text
[ UI layer ]  --->  [ Domain layer (optional) ]  --->  [ Data layer ]
 shows state          reusable business logic           repositories,
 handles input        (use cases)                       databases, network
```

Dependencies point one way: the UI layer uses the domain or data layer, never the other way round.
Data flows back up as state, and events flow down (**unidirectional data flow**).

| Layer | What it does | Typical classes |
| --- | --- | --- |
| UI | Renders the app state on screen and turns user input into events | Composables or Views (XML layouts), **ViewModels** |
| Domain (optional) | Holds complex or reused business logic, so ViewModels stay small | Use cases (`GetLatestNewsUseCase`), usually plain Kotlin |
| Data | Owns the app data and the rules for it: caching, network, local storage | Repositories, data sources (Room DAOs, Retrofit services) |

+ A **ViewModel** holds UI state and survives configuration changes such as rotation.
  It does **not** survive process death; use `SavedStateHandle` or persistent storage for that.
+ A **repository** exposes data to the rest of the app and hides where it comes from (for example, Room cache first, then a REST API).
+ Use the domain layer only when logic is shared between several ViewModels or is too complex for one.
  It usually doesn't depend on Android classes, which makes it easy to unit-test.

How to lay these layers out in packages and Gradle modules: [app_project_structure.md](app_project_structure.md).

## Related notes

+ [app_components.md](app_components.md), [android_class_hierarchy.md](android_class_hierarchy.md)
+ [app_project_structure.md](app_project_structure.md), [View_binding.md](View_binding.md)
+ [../IPC/Binder_intro.md](../IPC/Binder_intro.md), [../../DevTools/layered_arch_blueprint.md](../../DevTools/layered_arch_blueprint.md)

## Reference

+ [Platform architecture](https://developer.android.com/guide/platform)
+ [Guide to app architecture](https://developer.android.com/topic/architecture)
+ [UI layer](https://developer.android.com/topic/architecture/ui-layer)
+ [Domain layer](https://developer.android.com/topic/architecture/domain-layer)
+ [Data layer](https://developer.android.com/topic/architecture/data-layer)
+ [ViewModel overview](https://developer.android.com/topic/libraries/architecture/viewmodel)
