import Foundation

public protocol DomainConvertibleType {
    associatedtype DomainType: Codable

    func asDomain() -> DomainType
}

// MARK: - Default implimentations

public extension LocalFileProvider where Self: DomainConvertibleType {
    func asDomain() -> LocalFile {
        return LocalFile(url: url)!
    }
}

public extension DomainConvertibleType where Self: LocalFileInfoProvider {
    func asDomain() -> LocalFile {
        return LocalFile(url: url)!
    }
}
