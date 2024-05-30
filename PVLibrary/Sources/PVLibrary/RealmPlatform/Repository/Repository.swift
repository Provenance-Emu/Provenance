import Foundation
import RealmSwift
import RxRealm
import RxSwift

protocol AbstractRepository {
    associatedtype T
    func queryAll() -> Observable<[T]>
    func query(with predicate: NSPredicate,
               sortDescriptors: [NSSortDescriptor]) -> Observable<[T]>
//    func save(entity: T) -> Observable<()>
//    func delete(entity: T) -> Observable<()>
}

final class Repository<T: RealmRepresentable>: AbstractRepository where T == T.RealmType.DomainType, T.RealmType: Object {
    private let configuration: Realm.Configuration
    private let scheduler: RunLoopThreadScheduler

    private var realm: Realm {
        return try! Realm(configuration: configuration)
    }

    init(configuration: Realm.Configuration) {
        self.configuration = configuration
        let name = "com.CleanArchitectureRxSwift.RealmPlatform.Repository"
        scheduler = RunLoopThreadScheduler(threadName: name)
//        print("File 📁 url: \(RLMRealmPathForFile("default.realm"))")
    }

    func queryAll() -> Observable<[T]> {
        return Observable.deferred {
            let realm = self.realm
            let objects = realm.objects(T.RealmType.self)

            return Observable.array(from: objects)
                .mapToDomain()
        }
        .subscribe(on: scheduler)
    }

    func query(with _: NSPredicate,
               sortDescriptors _: [NSSortDescriptor] = []) -> Observable<[T]> {
        return Observable.deferred {
            let realm = self.realm
            let objects = realm.objects(T.RealmType.self)
//            The implementation is broken since we are not using predicate and sortDescriptors
//            but it cause compiler to crash with xcode 8.3 ¯\_(ツ)_/¯
//                            .filter(predicate)
//                            .sorted(by: sortDescriptors.map(SortDescriptor.init))

            return Observable.array(from: objects)
                .mapToDomain()
        }
        .subscribe(on: scheduler)
    }

//    func save(entity: T) -> Observable<()> {
//        return Observable.deferred {
//            self.realm.rx.save(entity: entity)
//        }.subscribe(on:scheduler)
//    }
//
//    func delete(entity: T) -> Observable<()> {
//        return Observable.deferred {
//            self.realm.rx.delete()
//        }.subscribe(on:scheduler)
//    }
}
