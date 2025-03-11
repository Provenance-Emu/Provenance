import Foundation

public protocol DomainConvertibleType {
    associatedtype DomainType: Codable

    func asDomain() -> DomainType
}

// MARK: - Default implimentations

public extension LocalFileProvider where Self: DomainConvertibleType {
    func asDomain() -> LocalFile {
        guard let url = url else { return .default }
        return LocalFile(url: url) ?? .default
    }
}

public extension DomainConvertibleType where Self: LocalFileInfoProvider {
    func asDomain() -> LocalFile {
        guard let url = url else { return .default }
        return LocalFile(url: url) ?? .default
    }
}
