import PVMacros

final class SomeClass: Sendable {
  func someAsyncFunction() async{
    print("Hi from async function")
  }

  func someSyncFunction() {
      #DetachedWeakSelf(self)
          someAsyncFunction()
  }

}

let someInstance = SomeClass()
someInstance.someSyncFunction()
