import Foundation
import RealmSwift
import RxSwift

extension RealmSwift.Object {
    static func build<O: RealmSwift.Object>(_ builder: (O) -> Void) async -> O {
        let object = O()
        builder(object)
        return object
    }
    
    static func build<O: RealmSwift.Object>(_ builder: (O) async -> Void) async -> O {
        let object = O()
        await builder(object)
        return object
    }
}

// extension SortDescriptor {
//    init(sortDescriptor: NSSortDescriptor) {
//        self.init(keyPath: sortDescriptor.key ?? "", ascending: sortDescriptor.ascending)
//    }
// }

extension Reactive where Base == Realm {
    @MainActor
    func save<R: RealmRepresentable>(entity: R, update: Bool = true) -> Observable<()> where R.RealmType: Object {
        return Observable.create { observer in
            do {
                try self.base.write {
                    Task {
                        await self.base.add(entity.asRealm(), update: update ? .all : .error)
                    }
                }
                observer.onNext(())
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }

    @MainActor
    func delete<R: RealmRepresentable>(entity: R) -> Observable<()> where R.RealmType: Object {
        return Observable.create { observer in
            do {
                guard let object = self.base.object(ofType: R.RealmType.self, forPrimaryKey: entity.uid) else { fatalError() }

                try self.base.write {
                    self.base.delete(object)
                }

                observer.onNext(())
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
}
