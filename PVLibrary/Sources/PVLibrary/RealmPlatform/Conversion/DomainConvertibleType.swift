import Foundation

public protocol DomainConvertibleType {
    associatedtype DomainType: Codable

    func asDomain() async -> DomainType
}

// MARK: - Default implimentations

extension LocalFileProvider where Self: DomainConvertibleType {
    public func asDomain() async -> LocalFile {
        return await LocalFile(url: url)!
    }
}

extension DomainConvertibleType where Self: LocalFileInfoProvider {
    public func asDomain() async -> LocalFile {
        return await LocalFile(url: url)!
    }
}
