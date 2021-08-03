import Foundation

public protocol DomainConvertibleType {
    associatedtype DomainType: Codable

    func asDomain() -> DomainType
}

// MARK: - Default implimentations

extension LocalFileProvider where Self: DomainConvertibleType {
    public func asDomain() -> LocalFile {
        return LocalFile(url: url)!
    }
}

extension DomainConvertibleType where Self: LocalFileInfoProvider {
    public func asDomain() -> LocalFile {
        return LocalFile(url: url)!
    }
}
