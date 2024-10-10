# DEVELOPER.md

__Developers should start here first for breif instructions for building and working with the source code__

## Documentation

## Building

### Setup Code Signing

- Copy `CodeSigning.xcconfig.sample` to `CodeSigning.xcconfig` and edit your relevent developer account details
- Accept any XCode / Swift Packagage Manager plugins (this will be presented to you by XCode at first build)
- Select scheme to build
    - I suggest building `Lite` first and working your way up to `XL` as you resolve any issues you may encouter in less time with the `Lite` app target.
    - Most users will want wither `Provenance-Release` or `Provenacne-XL (Release)`. The XL build includes more `RetroArch` and native local cores. See the build target and `./CoresRetro/RetroArch/Scripts/` build file lists for the most accurate list of cores for each target.
- If initial build fails, try again, as some source code files are generated lazily at compile time and sometimes XCode doesn't get the build order corrct 

### Realm Threading

When working with Realm and Swift Concurrency, it's important to remember that Realm objects are thread-confined, meaning they can only be accessed on the thread where they were created. Here's the recommended approach:

1. Use Object IDs or Primary Keys:
   Instead of passing the managed object directly, pass the object's ID or primary key to the other thread. This is safe because IDs and primary keys are simple value types.

   ```swift
   let objectId = managedObject.id // Assuming your object has an id property
   Task {
       await someAsyncFunction(objectId)
   }
   ```

2. Fetch the Object on the New Thread:
   In the async function, use the ID to fetch a new instance of the object from the Realm on that thread.

   ```swift
   func someAsyncFunction(_ objectId: ObjectId) async {
       let realm = try! await Realm()
       if let object = realm.object(ofType: YourObject.self, forPrimaryKey: objectId) {
           // Use the object here
       }
   }
   ```

3. Use Unmanaged Objects:
   If you need to pass actual data between threads, you can create an unmanaged copy of the object. This is useful when you don't need to update the object in the database.

   ```swift
   let unmanagedCopy = YourObject(value: managedObject)
   Task {
       await someAsyncFunction(unmanagedCopy)
   }
   ```

4. Use Realm's Built-in Threading Support:
   Realm provides some built-in support for working across threads. You can use `Realm.asyncOpen()` to open a Realm asynchronously:

   ```swift
   Task {
       do {
           let realm = try await Realm.asyncOpen()
           // Use realm here
       } catch {
           print("Failed to open realm: \(error.localizedDescription)")
       }
   }
   ```

5. Freeze Objects:
   Realm allows you to create a frozen copy of an object, which can be safely passed between threads:

   ```swift
   let frozenObject = managedObject.freeze()
   Task {
       await someAsyncFunction(frozenObject)
   }

   func someAsyncFunction(_ frozenObject: YourObject) async {
       // Use frozenObject here. It's immutable but can be safely accessed across threads.
   }
   ```

6. Use ThreadSafeReference:
   For more complex scenarios, you can use `ThreadSafeReference`:

   ```swift
   let reference = ThreadSafeReference(to: managedObject)
   Task {
       let realm = try! await Realm()
       guard let resolvedObject = realm.resolve(reference) else {
           return // The object has been deleted
       }
       // Use resolvedObject here
   }
   ```

Remember, when using Swift Concurrency with Realm:
- Always access Realm and its objects on the same thread they were created on.
- Use `@MainActor` for UI updates involving Realm objects.
- Be cautious with long-running transactions in async contexts to avoid blocking the thread.

By following these guidelines, you can safely work with Realm objects across different threads when using Swift Concurrency.
