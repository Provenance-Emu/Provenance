// The Swift Programming Language
// https://docs.swift.org/swift-book

/// Macro to wrap an async function in a detached weak self.
/// Example:
/// ```swift
/// somesyncFunction() async{
///         Task.detached { [weak self] in
///               guard let self = self else { return }
///
///               // do stuff
///         }
/// }
/// ```
/// Usage:
/// ```swift
/// someSyncFunction() {    // this is an async function
///     #detachedWeakSelf
///     someAsyncFunction()
/// }
/// ```
/// - Parameters:
///     - expression: The expression to be wrapped in a detached weak self.
/// - Returns: A tuple containing the original expression and the string representation of the expression.

@freestanding(expression)
public macro DetachedWeakSelf<T>(_ value: T) -> (T) = #externalMacro(module: "PVMacrosMacros", type: "DetachedWeakSelfMacro")
