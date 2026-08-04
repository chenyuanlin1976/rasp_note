# Fallbacks

In programming and software development, a fallback is a designated alternative mechanism, value, or behavior  
that is automatically triggered when the primary system, process, or value fails, is unavailable, or encounters an error.

Fallbacks are essential for building fault-tolerant, robust, and user-friendly applications.

## Common Use Cases & Examples

1. Default Values (Variables and Functions): If a variable or function parameter is not provided or evaluates to null/undefined,  
   a fallback value ensures the program doesn't crash.
2. Error Handling (Try-Catch / Exceptions): When a primary operation fails (like a database query or network request),  
   a fallback code block catches the exception and executes a safe alternative.
3. UI/UX Design (Graceful Degradation): In frontend development, fallbacks ensure that if a browser doesn't support a modern feature,  
   an older or simpler styling/functionality is used instead.
4. API Gateways and Microservices: In distributed systems, if a primary microservice goes down or times out,  
   a circuit breaker pattern redirects traffic to a fallback service or returns a cached response.

## Key Benefits

+ Improved Reliability: Prevents catastrophic crashes (Unhandled Exceptions).
+ Better User Experience: Keeps the application functional even when ideal conditions aren't met.
+ Easier Maintenance: Centralizes default behaviors rather than scattering error-check conditionals throughout the codebase.

## In C language

In the C programming language, because it lacks modern high-level features like built-in exception handling (try-catch) or nullish coalescing operators (??),  
fallbacks are typically implemented using conditional statements, preprocessor directives, or function pointers.

1. Default Values Using Ternary Operators or if-else:  
   When a function argument or configuration value might be invalid, zero, or uninitialized, a conditional check acts as the fallback.
2. Macro Fallbacks Using Conditional Compilation (`#ifdef`):  
   The preprocessor can check if a macro or constant is defined.  
   If it isn't, a fallback definition is provided. This is widely used for cross-platform compatibility or configuration headers.
3. Error Handling and Return Code Fallbacks:  
   Because C functions return status codes (like NULL for pointers or -1 for integers)  
   rather than throwing exceptions, developers use if statements to trigger fallback behavior upon failure.
4. Function Pointers as Dynamic Fallbacks:  
   You can use function pointers to swap out behavior dynamically.  
   If a primary hardware driver or algorithm fails to initialize, you can fallback to a software-emulated routine.
