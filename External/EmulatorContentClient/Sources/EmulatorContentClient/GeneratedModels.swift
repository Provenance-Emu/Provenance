// Generated from packages/protocol/openapi/openapi.yaml. Do not edit.

import Foundation

public struct ServerUpdateSettings: Codable, Equatable, Sendable {
    public var channel: String
    public var mode: String

    public init(channel: String, mode: String) {
        self.channel = channel
        self.mode = mode
    }
}

public struct ServerUpdateDecision: Codable, Equatable, Sendable {
    public var action: String
    public var buildId: String?

    public init(action: String, buildId: String? = nil) {
        self.action = action
        self.buildId = buildId
    }
}

public struct ServerUpdateBuild: Codable, Equatable, Sendable {
    public var id: String
    public var version: String
    public var channel: String

    public init(id: String, version: String, channel: String) {
        self.id = id
        self.version = version
        self.channel = channel
    }
}

public struct ServerUpdateStatus: Codable, Equatable, Sendable {
    public var supported: Bool
    public var settings: ServerUpdateSettings
    public var current: ServerUpdateBuild?
    public var available: ServerUpdateBuild?
    public var phase: String
    public var prompt: Bool
    public var message: String?

    public init(supported: Bool, settings: ServerUpdateSettings, current: ServerUpdateBuild? = nil, available: ServerUpdateBuild? = nil, phase: String, prompt: Bool, message: String? = nil) {
        self.supported = supported
        self.settings = settings
        self.current = current
        self.available = available
        self.phase = phase
        self.prompt = prompt
        self.message = message
    }
}

public struct Problem: Codable, Equatable, Sendable {
    public var type: String
    public var title: String
    public var status: Int
    public var detail: String?
    public var instance: String?
    public var requestId: String?

    public init(type: String, title: String, status: Int, detail: String? = nil, instance: String? = nil, requestId: String? = nil) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
        self.requestId = requestId
    }
}

public struct Capabilities: Codable, Equatable, Sendable {
    public var `protocol`: ProtocolInfo
    public var minClientVersion: String
    public var features: FeatureFlags
    public var limits: Limits
    public var authentication: [String]
    public var bootstrapped: Bool?

    public init(`protocol`: ProtocolInfo, minClientVersion: String, features: FeatureFlags, limits: Limits, authentication: [String], bootstrapped: Bool? = nil) {
        self.`protocol` = `protocol`
        self.minClientVersion = minClientVersion
        self.features = features
        self.limits = limits
        self.authentication = authentication
        self.bootstrapped = bootstrapped
    }
}

public struct ProtocolInfo: Codable, Equatable, Sendable {
    public var major: Int
    public var minor: Int
    public var path: String

    public init(major: Int, minor: Int, path: String) {
        self.major = major
        self.minor = minor
        self.path = path
    }
}

public struct FeatureFlags: Codable, Equatable, Sendable {
    public var rangeRequests: Bool
    public var multiRange: Bool
    public var resumableUploads: Bool
    public var changeFeed: Bool
    public var guestGrants: Bool
    public var virtualFormats: [String]
    public var webdav: Bool
    public var natTraversal: Bool
    public var webPlayback: Bool?

    public init(rangeRequests: Bool, multiRange: Bool, resumableUploads: Bool, changeFeed: Bool, guestGrants: Bool, virtualFormats: [String], webdav: Bool, natTraversal: Bool, webPlayback: Bool? = nil) {
        self.rangeRequests = rangeRequests
        self.multiRange = multiRange
        self.resumableUploads = resumableUploads
        self.changeFeed = changeFeed
        self.guestGrants = guestGrants
        self.virtualFormats = virtualFormats
        self.webdav = webdav
        self.natTraversal = natTraversal
        self.webPlayback = webPlayback
    }
}

public struct PlayerCoreResource: Codable, Equatable, Sendable {
    public var url: String
    public var sha256: String
    public var sizeBytes: Int64

    public init(url: String, sha256: String, sizeBytes: Int64) {
        self.url = url
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

public struct PlayerCoreDescriptor: Codable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var name: String
    public var systems: [String]
    public var runtime: String
    public var threaded: Bool
    public var filesystem: String
    public var saveCompletion: String
    public var frontendCommit: String
    public var coreCommit: String
    public var emscriptenVersion: String
    public var contentExtension: String
    public var maxContentBytes: Int64
    public var loader: PlayerCoreResource
    public var wasm: PlayerCoreResource

    public init(version: Int, id: String, name: String, systems: [String], runtime: String, threaded: Bool, filesystem: String, saveCompletion: String, frontendCommit: String, coreCommit: String, emscriptenVersion: String, contentExtension: String, maxContentBytes: Int64, loader: PlayerCoreResource, wasm: PlayerCoreResource) {
        self.version = version
        self.id = id
        self.name = name
        self.systems = systems
        self.runtime = runtime
        self.threaded = threaded
        self.filesystem = filesystem
        self.saveCompletion = saveCompletion
        self.frontendCommit = frontendCommit
        self.coreCommit = coreCommit
        self.emscriptenVersion = emscriptenVersion
        self.contentExtension = contentExtension
        self.maxContentBytes = maxContentBytes
        self.loader = loader
        self.wasm = wasm
    }
}

public struct WebPlayerAsset: Codable, Equatable, Sendable {
    public var name: String
    public var url: String
    public var sha256: String
    public var sizeBytes: Int64

    public init(name: String, url: String, sha256: String, sizeBytes: Int64) {
        self.name = name
        self.url = url
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

public struct WebPlayerDescriptor: Codable, Equatable, Sendable {
    public var profileVersion: Int
    public var id: String
    public var name: String
    public var systems: [String]
    public var runtime: String
    public var filesystem: String
    public var systemFilesDirectory: String?
    public var defaultInputLayout: String?
    public var defaultCoreOptions: [String: String]?
    public var threaded: Bool
    public var saveCompletion: String
    public var contentExtensions: [String]
    public var maxContentBytes: Int64
    public var buildVersion: String
    public var loader: PlayerCoreResource
    public var wasm: PlayerCoreResource
    public var assets: [WebPlayerAsset]

    public init(profileVersion: Int, id: String, name: String, systems: [String], runtime: String, filesystem: String, systemFilesDirectory: String? = nil, defaultInputLayout: String? = nil, defaultCoreOptions: [String: String]? = nil, threaded: Bool, saveCompletion: String, contentExtensions: [String], maxContentBytes: Int64, buildVersion: String, loader: PlayerCoreResource, wasm: PlayerCoreResource, assets: [WebPlayerAsset]) {
        self.profileVersion = profileVersion
        self.id = id
        self.name = name
        self.systems = systems
        self.runtime = runtime
        self.filesystem = filesystem
        self.systemFilesDirectory = systemFilesDirectory
        self.defaultInputLayout = defaultInputLayout
        self.defaultCoreOptions = defaultCoreOptions
        self.threaded = threaded
        self.saveCompletion = saveCompletion
        self.contentExtensions = contentExtensions
        self.maxContentBytes = maxContentBytes
        self.buildVersion = buildVersion
        self.loader = loader
        self.wasm = wasm
        self.assets = assets
    }
}

public struct PlayerIsolationDraft: Codable, Equatable, Sendable {
    public var profileId: String

    public init(profileId: String) {
        self.profileId = profileId
    }
}

public struct PlayerIsolationSession: Codable, Equatable, Sendable {
    public var id: String
    public var url: String
    public var expiresAt: String

    public init(id: String, url: String, expiresAt: String) {
        self.id = id
        self.url = url
        self.expiresAt = expiresAt
    }
}

public struct PlayerConfiguration: Codable, Equatable, Sendable {
    public var enabled: Bool?
    public var `default`: Bool?

    public init(enabled: Bool? = nil, `default`: Bool? = nil) {
        self.enabled = enabled
        self.`default` = `default`
    }
}

public struct PlayerInstallation: Codable, Equatable, Sendable {
    public var profile: WebPlayerDescriptor
    public var enabled: Bool
    public var source: String
    public var removable: Bool

    public init(profile: WebPlayerDescriptor, enabled: Bool, source: String, removable: Bool) {
        self.profile = profile
        self.enabled = enabled
        self.source = source
        self.removable = removable
    }
}

public struct PlayerCatalogEntry: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var systems: [String]
    public var description: String
    public var available: Bool
    public var reason: String?
    public var downloadBytes: Int?

    public init(id: String, name: String, systems: [String], description: String, available: Bool, reason: String? = nil, downloadBytes: Int? = nil) {
        self.id = id
        self.name = name
        self.systems = systems
        self.description = description
        self.available = available
        self.reason = reason
        self.downloadBytes = downloadBytes
    }
}

public struct PlayerManagement: Codable, Equatable, Sendable {
    public var items: [PlayerInstallation]
    public var defaultProfileId: String?
    public var available: [PlayerCatalogEntry]

    public init(items: [PlayerInstallation], defaultProfileId: String? = nil, available: [PlayerCatalogEntry]) {
        self.items = items
        self.defaultProfileId = defaultProfileId
        self.available = available
    }
}

public struct WebPlayerCatalog: Codable, Equatable, Sendable {
    public var items: [WebPlayerDescriptor]
    public var defaultProfileId: String?

    public init(items: [WebPlayerDescriptor], defaultProfileId: String? = nil) {
        self.items = items
        self.defaultProfileId = defaultProfileId
    }
}

public struct Limits: Codable, Equatable, Sendable {
    public var maxUploadBytes: Int64
    public var maxPageSize: Int

    public init(maxUploadBytes: Int64, maxPageSize: Int) {
        self.maxUploadBytes = maxUploadBytes
        self.maxPageSize = maxPageSize
    }
}

public struct SystemSummary: Codable, Equatable, Sendable {
    public var identifier: String
    public var name: String

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public struct SystemList: Codable, Equatable, Sendable {
    public var systems: [SystemSummary]
    public var closed: Bool

    public init(systems: [SystemSummary], closed: Bool) {
        self.systems = systems
        self.closed = closed
    }
}

public struct Library: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var canCreateItems: Bool?
    public var ownerId: String
    public var revision: Int
    public var createdAt: String

    public init(id: String, name: String, canCreateItems: Bool? = nil, ownerId: String, revision: Int, createdAt: String) {
        self.id = id
        self.name = name
        self.canCreateItems = canCreateItems
        self.ownerId = ownerId
        self.revision = revision
        self.createdAt = createdAt
    }
}

public struct LibraryList: Codable, Equatable, Sendable {
    public var items: [Library]
    public var nextCursor: String?

    public init(items: [Library], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct LibraryDraft: Codable, Equatable, Sendable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public struct FolderEntry: Codable, Equatable, Sendable {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct FolderPlace: Codable, Equatable, Sendable {
    public var label: String
    public var path: String

    public init(label: String, path: String) {
        self.label = label
        self.path = path
    }
}

public struct FolderListing: Codable, Equatable, Sendable {
    public var path: String
    public var parent: String?
    public var entries: [FolderEntry]
    public var places: [FolderPlace]

    public init(path: String, parent: String? = nil, entries: [FolderEntry], places: [FolderPlace]) {
        self.path = path
        self.parent = parent
        self.entries = entries
        self.places = places
    }
}

public struct WebDavCredential: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var username: String
    public var createdAt: String
    public var expiresAt: String
    public var revokedAt: String?

    public init(id: String, name: String, username: String, createdAt: String, expiresAt: String, revokedAt: String? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
    }
}

public struct WebDavCredentialList: Codable, Equatable, Sendable {
    public var items: [WebDavCredential]

    public init(items: [WebDavCredential]) {
        self.items = items
    }
}

public struct WebDavCredentialDraft: Codable, Equatable, Sendable {
    public var name: String
    public var expiresInSeconds: Int?

    public init(name: String, expiresInSeconds: Int? = nil) {
        self.name = name
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct WebDavCredentialCreated: Codable, Equatable, Sendable {
    public var credential: WebDavCredential
    public var password: String

    public init(credential: WebDavCredential, password: String) {
        self.credential = credential
        self.password = password
    }
}

public struct StorageLocation: Codable, Equatable, Sendable {
    public var id: String
    public var path: String
    public var label: String
    public var createdAt: String
    public var online: Bool

    public init(id: String, path: String, label: String, createdAt: String, online: Bool) {
        self.id = id
        self.path = path
        self.label = label
        self.createdAt = createdAt
        self.online = online
    }
}

public struct StorageLocationList: Codable, Equatable, Sendable {
    public var items: [StorageLocation]
    public var writeLocationId: String?

    public init(items: [StorageLocation], writeLocationId: String? = nil) {
        self.items = items
        self.writeLocationId = writeLocationId
    }
}

public struct StorageLocationDraft: Codable, Equatable, Sendable {
    public var path: String
    public var label: String

    public init(path: String, label: String) {
        self.path = path
        self.label = label
    }
}

public struct StorageWriteTarget: Codable, Equatable, Sendable {
    public var id: String?

    public init(id: String? = nil) {
        self.id = id
    }
}

public struct ContentRoot: Codable, Equatable, Sendable {
    public var id: String
    public var path: String
    public var label: String
    public var libraryId: String?
    public var createdAt: String

    public init(id: String, path: String, label: String, libraryId: String? = nil, createdAt: String) {
        self.id = id
        self.path = path
        self.label = label
        self.libraryId = libraryId
        self.createdAt = createdAt
    }
}

public struct ContentRootList: Codable, Equatable, Sendable {
    public var items: [ContentRoot]
    public var nextCursor: String?

    public init(items: [ContentRoot], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct ContentRootDraft: Codable, Equatable, Sendable {
    public var path: String
    public var label: String
    public var libraryId: String?
    public var watch: Bool?
    public var organize: Bool?

    public init(path: String, label: String, libraryId: String? = nil, watch: Bool? = nil, organize: Bool? = nil) {
        self.path = path
        self.label = label
        self.libraryId = libraryId
        self.watch = watch
        self.organize = organize
    }
}

public struct ContentRootScan: Codable, Equatable, Sendable {
    public var rootId: String
    public var medium: String
    public var online: Bool
    public var count: Int

    public init(rootId: String, medium: String, online: Bool, count: Int) {
        self.rootId = rootId
        self.medium = medium
        self.online = online
        self.count = count
    }
}

public struct SourceFile: Codable, Equatable, Sendable {
    public var id: String
    public var rootId: String
    public var libraryId: String?
    public var name: String
    public var kind: String
    public var size: Int64
    public var systemId: String?
    public var availability: String
    public var medium: String
    public var title: String?
    public var artworkAvailable: Bool?
    public var groupFileCount: Int?
    public var groupError: String?
    public var contentPath: String

    public init(id: String, rootId: String, libraryId: String? = nil, name: String, kind: String, size: Int64, systemId: String? = nil, availability: String, medium: String, title: String? = nil, artworkAvailable: Bool? = nil, groupFileCount: Int? = nil, groupError: String? = nil, contentPath: String) {
        self.id = id
        self.rootId = rootId
        self.libraryId = libraryId
        self.name = name
        self.kind = kind
        self.size = size
        self.systemId = systemId
        self.availability = availability
        self.medium = medium
        self.title = title
        self.artworkAvailable = artworkAvailable
        self.groupFileCount = groupFileCount
        self.groupError = groupError
        self.contentPath = contentPath
    }
}

public struct MatchingPlugin: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: String
    public var capabilities: [String]
    public var network: Bool

    public init(id: String, name: String, kind: String, capabilities: [String], network: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        self.capabilities = capabilities
        self.network = network
    }
}

public struct MatchingPluginList: Codable, Equatable, Sendable {
    public var plugins: [MatchingPlugin]

    public init(plugins: [MatchingPlugin]) {
        self.plugins = plugins
    }
}

public struct FolderWatchPolicy: Codable, Equatable, Sendable {
    public var rootId: String
    public var enabled: Bool
    public var state: String
    public var lastScanAt: String?
    public var warning: String?

    public init(rootId: String, enabled: Bool, state: String, lastScanAt: String? = nil, warning: String? = nil) {
        self.rootId = rootId
        self.enabled = enabled
        self.state = state
        self.lastScanAt = lastScanAt
        self.warning = warning
    }
}

public struct FolderWatchPolicyDraft: Codable, Equatable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

public struct SourceOrganizationPolicy: Codable, Equatable, Sendable {
    public var sourceRootId: String
    public var enabled: Bool
    public var mode: String?
    public var targetRootId: String?
    public var enabledAt: String?

    public init(sourceRootId: String, enabled: Bool, mode: String? = nil, targetRootId: String? = nil, enabledAt: String? = nil) {
        self.sourceRootId = sourceRootId
        self.enabled = enabled
        self.mode = mode
        self.targetRootId = targetRootId
        self.enabledAt = enabledAt
    }
}

public struct SourceOrganizationPolicyDraft: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var planId: String?

    public init(enabled: Bool, planId: String? = nil) {
        self.enabled = enabled
        self.planId = planId
    }
}

public struct FolderOrganizationPreview: Codable, Equatable, Sendable {
    public var planId: String
    public var examples: [[String: String]]

    public init(planId: String, examples: [[String: String]]) {
        self.planId = planId
        self.examples = examples
    }
}

public struct AutomaticOrganizationOutcome: Codable, Equatable, Sendable {
    public var status: String
    public var sourceId: String?
    public var warning: String?

    public init(status: String, sourceId: String? = nil, warning: String? = nil) {
        self.status = status
        self.sourceId = sourceId
        self.warning = warning
    }
}

public struct SourceOrganizationDraft: Codable, Equatable, Sendable {
    public var mode: String
    public var targetRootId: String

    public init(mode: String, targetRootId: String) {
        self.mode = mode
        self.targetRootId = targetRootId
    }
}

public struct SourceOrganizationApply: Codable, Equatable, Sendable {
    public var planId: String

    public init(planId: String) {
        self.planId = planId
    }
}

public struct SourceOrganizationPreview: Codable, Equatable, Sendable {
    public var planId: String
    public var sourceId: String
    public var mode: String
    public var sourceRootId: String
    public var targetRootId: String
    public var sourceRelativePath: String
    public var targetRelativePath: String
    public var expiresAt: String
    public var files: [SourceOrganizationFile]?

    public init(planId: String, sourceId: String, mode: String, sourceRootId: String, targetRootId: String, sourceRelativePath: String, targetRelativePath: String, expiresAt: String, files: [SourceOrganizationFile]? = nil) {
        self.planId = planId
        self.sourceId = sourceId
        self.mode = mode
        self.sourceRootId = sourceRootId
        self.targetRootId = targetRootId
        self.sourceRelativePath = sourceRelativePath
        self.targetRelativePath = targetRelativePath
        self.expiresAt = expiresAt
        self.files = files
    }
}

public struct SourceOrganizationFile: Codable, Equatable, Sendable {
    public var sourceRelativePath: String
    public var targetRelativePath: String

    public init(sourceRelativePath: String, targetRelativePath: String) {
        self.sourceRelativePath = sourceRelativePath
        self.targetRelativePath = targetRelativePath
    }
}

public struct SourceOrganizationResult: Codable, Equatable, Sendable {
    public var sourceId: String
    public var originalSourceId: String
    public var warning: String?
    public var mode: String
    public var targetRootId: String
    public var targetRelativePath: String

    public init(sourceId: String, originalSourceId: String, warning: String? = nil, mode: String, targetRootId: String, targetRelativePath: String) {
        self.sourceId = sourceId
        self.originalSourceId = originalSourceId
        self.warning = warning
        self.mode = mode
        self.targetRootId = targetRootId
        self.targetRelativePath = targetRelativePath
    }
}

public struct MatchingOptions: Codable, Equatable, Sendable {
    public var online: Bool?
    public var checksum: Bool?
    public var autoSave: Bool?
    public var refreshCatalogs: Bool?
    public var allowExactNames: Bool?
    public var providerIds: [String]?
    public var managerId: String?

    public init(online: Bool? = nil, checksum: Bool? = nil, autoSave: Bool? = nil, refreshCatalogs: Bool? = nil, allowExactNames: Bool? = nil, providerIds: [String]? = nil, managerId: String? = nil) {
        self.online = online
        self.checksum = checksum
        self.autoSave = autoSave
        self.refreshCatalogs = refreshCatalogs
        self.allowExactNames = allowExactNames
        self.providerIds = providerIds
        self.managerId = managerId
    }
}

public struct MatchingCandidate: Codable, Equatable, Sendable {
    public var id: String
    public var providerId: String
    public var kind: String
    public var title: String
    public var confidence: String
    public var metadata: [String: String]
    public var fileId: String?
    public var url: String?

    public init(id: String, providerId: String, kind: String, title: String, confidence: String, metadata: [String: String], fileId: String? = nil, url: String? = nil) {
        self.id = id
        self.providerId = providerId
        self.kind = kind
        self.title = title
        self.confidence = confidence
        self.metadata = metadata
        self.fileId = fileId
        self.url = url
    }
}

public struct SavedSourceMatch: Codable, Equatable, Sendable {
    public var id: String
    public var providerId: String
    public var kind: String
    public var artworkRole: String?
    public var title: String
    public var confidence: String
    public var metadata: [String: String]
    public var originFileId: String?
    public var originUrl: String?
    public var contentAvailable: Bool
    public var contentType: String?
    public var fileName: String?
    public var updatedAt: String

    public init(id: String, providerId: String, kind: String, artworkRole: String? = nil, title: String, confidence: String, metadata: [String: String], originFileId: String? = nil, originUrl: String? = nil, contentAvailable: Bool, contentType: String? = nil, fileName: String? = nil, updatedAt: String) {
        self.id = id
        self.providerId = providerId
        self.kind = kind
        self.artworkRole = artworkRole
        self.title = title
        self.confidence = confidence
        self.metadata = metadata
        self.originFileId = originFileId
        self.originUrl = originUrl
        self.contentAvailable = contentAvailable
        self.contentType = contentType
        self.fileName = fileName
        self.updatedAt = updatedAt
    }
}

public struct SourceMatchSelections: Codable, Equatable, Sendable {
    public var automaticOrganization: AutomaticOrganizationOutcome?
    public var sourceId: String
    public var revision: Int
    public var matches: [SavedSourceMatch]

    public init(automaticOrganization: AutomaticOrganizationOutcome? = nil, sourceId: String, revision: Int, matches: [SavedSourceMatch]) {
        self.automaticOrganization = automaticOrganization
        self.sourceId = sourceId
        self.revision = revision
        self.matches = matches
    }
}

public struct SourceMatchSelectionDraft: Codable, Equatable, Sendable {
    public var requestId: String
    public var candidateId: String
    public var expectedRevision: Int

    public init(requestId: String, candidateId: String, expectedRevision: Int) {
        self.requestId = requestId
        self.candidateId = candidateId
        self.expectedRevision = expectedRevision
    }
}

public struct MatchingProblem: Codable, Equatable, Sendable {
    public var providerId: String
    public var code: String

    public init(providerId: String, code: String) {
        self.providerId = providerId
        self.code = code
    }
}

public struct SourceMatches: Codable, Equatable, Sendable {
    public var sourceId: String
    public var requestId: String
    public var automatic: MatchingAutomaticResult?
    public var plugins: [MatchingPlugin]
    public var candidates: [MatchingCandidate]
    public var problems: [MatchingProblem]

    public init(sourceId: String, requestId: String, automatic: MatchingAutomaticResult? = nil, plugins: [MatchingPlugin], candidates: [MatchingCandidate], problems: [MatchingProblem]) {
        self.sourceId = sourceId
        self.requestId = requestId
        self.automatic = automatic
        self.plugins = plugins
        self.candidates = candidates
        self.problems = problems
    }
}

public struct MatchingAutomaticResult: Codable, Equatable, Sendable {
    public var status: String
    public var saved: Int
    public var error: String?

    public init(status: String, saved: Int, error: String? = nil) {
        self.status = status
        self.saved = saved
        self.error = error
    }
}

public struct SourceGroupFile: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var relativePath: String?
    public var size: Int64
    public var availability: String

    public init(id: String, name: String, relativePath: String? = nil, size: Int64, availability: String) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.size = size
        self.availability = availability
    }
}

public struct SourceGroup: Codable, Equatable, Sendable {
    public var sourceId: String
    public var error: String?
    public var files: [SourceGroupFile]

    public init(sourceId: String, error: String? = nil, files: [SourceGroupFile]) {
        self.sourceId = sourceId
        self.error = error
        self.files = files
    }
}

public struct SourceFileList: Codable, Equatable, Sendable {
    public var items: [SourceFile]

    public init(items: [SourceFile]) {
        self.items = items
    }
}

public struct Item: Codable, Equatable, Sendable {
    public var id: String
    public var libraryId: String
    public var systemIdentifier: String
    public var title: String
    public var md5: String?
    public var crc: String?
    public var revision: Int
    public var createdAt: String
    public var updatedAt: String

    public init(id: String, libraryId: String, systemIdentifier: String, title: String, md5: String? = nil, crc: String? = nil, revision: Int, createdAt: String, updatedAt: String) {
        self.id = id
        self.libraryId = libraryId
        self.systemIdentifier = systemIdentifier
        self.title = title
        self.md5 = md5
        self.crc = crc
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ItemList: Codable, Equatable, Sendable {
    public var items: [Item]
    public var nextCursor: String?

    public init(items: [Item], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct ItemDraft: Codable, Equatable, Sendable {
    public var libraryId: String
    public var systemIdentifier: String
    public var title: String
    public var md5: String?
    public var crc: String?

    public init(libraryId: String, systemIdentifier: String, title: String, md5: String? = nil, crc: String? = nil) {
        self.libraryId = libraryId
        self.systemIdentifier = systemIdentifier
        self.title = title
        self.md5 = md5
        self.crc = crc
    }
}

public struct ItemPatch: Codable, Equatable, Sendable {
    public var title: String?
    public var md5: String?
    public var crc: String?

    public init(title: String? = nil, md5: String? = nil, crc: String? = nil) {
        self.title = title
        self.md5 = md5
        self.crc = crc
    }
}

public struct Asset: Codable, Equatable, Sendable {
    public var id: String
    public var itemId: String
    public var kind: String
    public var displayName: String
    public var relativePath: String
    public var sha256: String
    public var size: Int64
    public var md5: String?
    public var crc: String?
    public var shareable: Bool
    public var revision: Int
    public var createdAt: String
    public var updatedAt: String
    public var conflictOf: String?

    public init(id: String, itemId: String, kind: String, displayName: String, relativePath: String, sha256: String, size: Int64, md5: String? = nil, crc: String? = nil, shareable: Bool, revision: Int, createdAt: String, updatedAt: String, conflictOf: String? = nil) {
        self.id = id
        self.itemId = itemId
        self.kind = kind
        self.displayName = displayName
        self.relativePath = relativePath
        self.sha256 = sha256
        self.size = size
        self.md5 = md5
        self.crc = crc
        self.shareable = shareable
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.conflictOf = conflictOf
    }
}

public struct ManifestFile: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var relativePath: String
    public var sha256: String
    public var md5: String?
    public var crc: String?
    public var size: Int64
    public var required: Bool
    public var contentPath: String
    public var conflictOf: String?

    public init(id: String, kind: String, relativePath: String, sha256: String, md5: String? = nil, crc: String? = nil, size: Int64, required: Bool, contentPath: String, conflictOf: String? = nil) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.sha256 = sha256
        self.md5 = md5
        self.crc = crc
        self.size = size
        self.required = required
        self.contentPath = contentPath
        self.conflictOf = conflictOf
    }
}

public struct Manifest: Codable, Equatable, Sendable {
    public var version: Int
    public var itemId: String
    public var revision: Int
    public var files: [ManifestFile]

    public init(version: Int, itemId: String, revision: Int, files: [ManifestFile]) {
        self.version = version
        self.itemId = itemId
        self.revision = revision
        self.files = files
    }
}

public struct UploadSession: Codable, Equatable, Sendable {
    public var id: String
    public var received: Int64
    public var state: String

    public init(id: String, received: Int64, state: String) {
        self.id = id
        self.received = received
        self.state = state
    }
}

public struct UploadComplete: Codable, Equatable, Sendable {
    public var itemId: String
    public var kind: String
    public var displayName: String
    public var relativePath: String
    public var baseRevision: Int

    public init(itemId: String, kind: String, displayName: String, relativePath: String, baseRevision: Int) {
        self.itemId = itemId
        self.kind = kind
        self.displayName = displayName
        self.relativePath = relativePath
        self.baseRevision = baseRevision
    }
}

public struct ChangeEvent: Codable, Equatable, Sendable {
    public var cursor: Int
    public var entityType: String
    public var entityId: String
    public var op: String
    public var libraryId: String?
    public var itemId: String?
    public var sensitive: Bool
    public var recordedAt: String

    public init(cursor: Int, entityType: String, entityId: String, op: String, libraryId: String? = nil, itemId: String? = nil, sensitive: Bool, recordedAt: String) {
        self.cursor = cursor
        self.entityType = entityType
        self.entityId = entityId
        self.op = op
        self.libraryId = libraryId
        self.itemId = itemId
        self.sensitive = sensitive
        self.recordedAt = recordedAt
    }
}

public struct ChangeList: Codable, Equatable, Sendable {
    public var changes: [ChangeEvent]
    public var nextCursor: String

    public init(changes: [ChangeEvent], nextCursor: String) {
        self.changes = changes
        self.nextCursor = nextCursor
    }
}

public struct BootstrapRequest: Codable, Equatable, Sendable {
    public var token: String
    public var username: String
    public var password: String

    public init(token: String, username: String, password: String) {
        self.token = token
        self.username = username
        self.password = password
    }
}

public struct LoginRequest: Codable, Equatable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct SessionResponse: Codable, Equatable, Sendable {
    public var token: String
    public var tokenType: String
    public var userId: String
    public var expiresAt: String

    public init(token: String, tokenType: String, userId: String, expiresAt: String) {
        self.token = token
        self.tokenType = tokenType
        self.userId = userId
        self.expiresAt = expiresAt
    }
}

public struct UserDraft: Codable, Equatable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct User: Codable, Equatable, Sendable {
    public var id: String
    public var username: String
    public var isOwner: Bool
    public var createdAt: String

    public init(id: String, username: String, isOwner: Bool, createdAt: String) {
        self.id = id
        self.username = username
        self.isOwner = isOwner
        self.createdAt = createdAt
    }
}

public struct MemberDraft: Codable, Equatable, Sendable {
    public var role: String

    public init(role: String) {
        self.role = role
    }
}

public struct ItemAccessDraft: Codable, Equatable, Sendable {
    public var permission: String

    public init(permission: String) {
        self.permission = permission
    }
}

public struct GuestGrantDraft: Codable, Equatable, Sendable {
    public var libraryId: String
    public var itemId: String?
    public var capabilities: [String]
    public var expiresInSeconds: Int

    public init(libraryId: String, itemId: String? = nil, capabilities: [String], expiresInSeconds: Int) {
        self.libraryId = libraryId
        self.itemId = itemId
        self.capabilities = capabilities
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct GuestGrantCreated: Codable, Equatable, Sendable {
    public var id: String
    public var token: String
    public var expiresAt: String

    public init(id: String, token: String, expiresAt: String) {
        self.id = id
        self.token = token
        self.expiresAt = expiresAt
    }
}

public struct LibraryMember: Codable, Equatable, Sendable {
    public var userId: String
    public var role: String

    public init(userId: String, role: String) {
        self.userId = userId
        self.role = role
    }
}

public struct LibraryMemberList: Codable, Equatable, Sendable {
    public var items: [LibraryMember]

    public init(items: [LibraryMember]) {
        self.items = items
    }
}

public struct DeviceToken: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var scopes: [String]
    public var expiresAt: String?
    public var createdAt: String
    public var revokedAt: String?
    public var lastUsedAt: String?

    public init(id: String, name: String, scopes: [String], expiresAt: String? = nil, createdAt: String, revokedAt: String? = nil, lastUsedAt: String? = nil) {
        self.id = id
        self.name = name
        self.scopes = scopes
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.revokedAt = revokedAt
        self.lastUsedAt = lastUsedAt
    }
}

public struct DeviceTokenList: Codable, Equatable, Sendable {
    public var items: [DeviceToken]

    public init(items: [DeviceToken]) {
        self.items = items
    }
}

public struct DeviceTokenDraft: Codable, Equatable, Sendable {
    public var name: String
    public var scopes: [String]
    public var expiresInSeconds: Int?

    public init(name: String, scopes: [String], expiresInSeconds: Int? = nil) {
        self.name = name
        self.scopes = scopes
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct DeviceTokenCreated: Codable, Equatable, Sendable {
    public var id: String
    public var token: String
    public var scopes: [String]

    public init(id: String, token: String, scopes: [String]) {
        self.id = id
        self.token = token
        self.scopes = scopes
    }
}

public struct AuditEvent: Codable, Equatable, Sendable {
    public var id: Int
    public var at: String
    public var actorId: String?
    public var action: String
    public var resourceType: String?
    public var resourceId: String?

    public init(id: Int, at: String, actorId: String? = nil, action: String, resourceType: String? = nil, resourceId: String? = nil) {
        self.id = id
        self.at = at
        self.actorId = actorId
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
    }
}

public struct AuditList: Codable, Equatable, Sendable {
    public var events: [AuditEvent]

    public init(events: [AuditEvent]) {
        self.events = events
    }
}

public struct VirtualEntry: Codable, Equatable, Sendable {
    public var entryId: String
    public var path: String
    public var compressedSize: Int64
    public var uncompressedSize: Int64
    public var method: String
    public var crc: String?

    public init(entryId: String, path: String, compressedSize: Int64, uncompressedSize: Int64, method: String, crc: String? = nil) {
        self.entryId = entryId
        self.path = path
        self.compressedSize = compressedSize
        self.uncompressedSize = uncompressedSize
        self.method = method
        self.crc = crc
    }
}

public struct VirtualEntryList: Codable, Equatable, Sendable {
    public var supported: Bool
    public var entries: [String]
    public var format: String?
    public var items: [VirtualEntry]?

    public init(supported: Bool, entries: [String], format: String? = nil, items: [VirtualEntry]? = nil) {
        self.supported = supported
        self.entries = entries
        self.format = format
        self.items = items
    }
}

public struct AccessPolicy: Codable, Equatable, Sendable {
    public var mode: String
    public var subnets: [String]
    public var applies: Bool
    public var trusted: Bool
    public var manages: Bool

    public init(mode: String, subnets: [String], applies: Bool, trusted: Bool, manages: Bool) {
        self.mode = mode
        self.subnets = subnets
        self.applies = applies
        self.trusted = trusted
        self.manages = manages
    }
}

public struct GuestGrant: Codable, Equatable, Sendable {
    public var id: String
    public var libraryId: String
    public var itemId: String?
    public var capabilities: [String]
    public var expiresAt: String
    public var createdAt: String
    public var revokedAt: String?
    public var createdBy: String?

    public init(id: String, libraryId: String, itemId: String? = nil, capabilities: [String], expiresAt: String, createdAt: String, revokedAt: String? = nil, createdBy: String? = nil) {
        self.id = id
        self.libraryId = libraryId
        self.itemId = itemId
        self.capabilities = capabilities
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.revokedAt = revokedAt
        self.createdBy = createdBy
    }
}

public struct GuestGrantList: Codable, Equatable, Sendable {
    public var items: [GuestGrant]

    public init(items: [GuestGrant]) {
        self.items = items
    }
}

public struct RootLibraryAssignment: Codable, Equatable, Sendable {
    public var libraryId: String

    public init(libraryId: String) {
        self.libraryId = libraryId
    }
}

public struct LibraryBrowseEntry: Codable, Equatable, Sendable {
    public var entityType: String
    public var id: String
    public var name: String
    public var libraryId: String?
    public var systemId: String?
    public var canUpload: Bool
    public var canAdopt: Bool
    public var item: Item?
    public var asset: Asset?
    public var source: SourceFile?
    public var parentItem: Item?
    public var previewAsset: Asset?

    public init(entityType: String, id: String, name: String, libraryId: String? = nil, systemId: String? = nil, canUpload: Bool, canAdopt: Bool, item: Item? = nil, asset: Asset? = nil, source: SourceFile? = nil, parentItem: Item? = nil, previewAsset: Asset? = nil) {
        self.entityType = entityType
        self.id = id
        self.name = name
        self.libraryId = libraryId
        self.systemId = systemId
        self.canUpload = canUpload
        self.canAdopt = canAdopt
        self.item = item
        self.asset = asset
        self.source = source
        self.parentItem = parentItem
        self.previewAsset = previewAsset
    }
}

public struct LibraryBrowsePage: Codable, Equatable, Sendable {
    public var items: [LibraryBrowseEntry]
    public var systemCounts: [SystemCount]?
    public var nextCursor: String?

    public init(items: [LibraryBrowseEntry], systemCounts: [SystemCount]? = nil, nextCursor: String? = nil) {
        self.items = items
        self.systemCounts = systemCounts
        self.nextCursor = nextCursor
    }
}

public struct SystemCount: Codable, Equatable, Sendable {
    public var systemId: String
    public var count: Int

    public init(systemId: String, count: Int) {
        self.systemId = systemId
        self.count = count
    }
}

public struct ContentRootSummary: Codable, Equatable, Sendable {
    public var root: ContentRoot
    public var indexedFileCount: Int
    public var scanState: String
    public var lastScanAt: String?
    public var lastCheckAt: String?
    public var online: Bool?
    public var medium: String?

    public init(root: ContentRoot, indexedFileCount: Int, scanState: String, lastScanAt: String? = nil, lastCheckAt: String? = nil, online: Bool? = nil, medium: String? = nil) {
        self.root = root
        self.indexedFileCount = indexedFileCount
        self.scanState = scanState
        self.lastScanAt = lastScanAt
        self.lastCheckAt = lastCheckAt
        self.online = online
        self.medium = medium
    }
}

public struct ContentRootSummaryList: Codable, Equatable, Sendable {
    public var items: [ContentRootSummary]

    public init(items: [ContentRootSummary]) {
        self.items = items
    }
}

public struct LibraryJobScope: Codable, Equatable, Sendable {
    public var rootId: String?
    public var libraryId: String?
    public var unassigned: Bool?

    public init(rootId: String? = nil, libraryId: String? = nil, unassigned: Bool? = nil) {
        self.rootId = rootId
        self.libraryId = libraryId
        self.unassigned = unassigned
    }
}

public struct LibraryJobDraft: Codable, Equatable, Sendable {
    public var kind: String
    public var rootId: String?
    public var libraryId: String?
    public var unassigned: Bool?
    public var options: MatchingOptions?

    public init(kind: String, rootId: String? = nil, libraryId: String? = nil, unassigned: Bool? = nil, options: MatchingOptions? = nil) {
        self.kind = kind
        self.rootId = rootId
        self.libraryId = libraryId
        self.unassigned = unassigned
        self.options = options
    }
}

public struct LibraryJob: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var scope: LibraryJobScope
    public var options: MatchingOptions
    public var state: String
    public var total: Int
    public var processed: Int
    public var saved: Int
    public var review: Int
    public var unmatched: Int
    public var failed: Int
    public var skipped: Int
    public var currentSourceId: String?
    public var error: String?
    public var createdAt: String
    public var updatedAt: String
    public var interruptedCount: Int

    public init(id: String, kind: String, scope: LibraryJobScope, options: MatchingOptions, state: String, total: Int, processed: Int, saved: Int, review: Int, unmatched: Int, failed: Int, skipped: Int, currentSourceId: String? = nil, error: String? = nil, createdAt: String, updatedAt: String, interruptedCount: Int) {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.options = options
        self.state = state
        self.total = total
        self.processed = processed
        self.saved = saved
        self.review = review
        self.unmatched = unmatched
        self.failed = failed
        self.skipped = skipped
        self.currentSourceId = currentSourceId
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.interruptedCount = interruptedCount
    }
}

public struct LibraryJobResponse: Codable, Equatable, Sendable {
    public var job: LibraryJob
    public var reused: Bool?

    public init(job: LibraryJob, reused: Bool? = nil) {
        self.job = job
        self.reused = reused
    }
}

public struct LibraryJobList: Codable, Equatable, Sendable {
    public var jobs: [LibraryJob]
    public var nextCursor: String?

    public init(jobs: [LibraryJob], nextCursor: String? = nil) {
        self.jobs = jobs
        self.nextCursor = nextCursor
    }
}

public struct LibraryJobItem: Codable, Equatable, Sendable {
    public var sourceId: String
    public var source: SourceFile?
    public var status: String
    public var saved: Int
    public var suggestions: Int
    public var error: String?

    public init(sourceId: String, source: SourceFile? = nil, status: String, saved: Int, suggestions: Int, error: String? = nil) {
        self.sourceId = sourceId
        self.source = source
        self.status = status
        self.saved = saved
        self.suggestions = suggestions
        self.error = error
    }
}

public struct LibraryJobItemList: Codable, Equatable, Sendable {
    public var items: [LibraryJobItem]
    public var nextCursor: String?

    public init(items: [LibraryJobItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct WorkflowScope: Codable, Equatable, Sendable {
    public var libraryId: String?
    public var rootId: String?
    public var sourceIds: [String]?
    public var unassigned: Bool?

    public init(libraryId: String? = nil, rootId: String? = nil, sourceIds: [String]? = nil, unassigned: Bool? = nil) {
        self.libraryId = libraryId
        self.rootId = rootId
        self.sourceIds = sourceIds
        self.unassigned = unassigned
    }
}

public struct WorkflowOptions: Codable, Equatable, Sendable {
    public var online: Bool
    public var checksum: Bool
    public var shareImages: Bool
    public var providerIds: [String]?
    public var reasonerConnectionId: String?
    public var coverInspectorConnectionId: String?

    public init(online: Bool, checksum: Bool, shareImages: Bool, providerIds: [String]? = nil, reasonerConnectionId: String? = nil, coverInspectorConnectionId: String? = nil) {
        self.online = online
        self.checksum = checksum
        self.shareImages = shareImages
        self.providerIds = providerIds
        self.reasonerConnectionId = reasonerConnectionId
        self.coverInspectorConnectionId = coverInspectorConnectionId
    }
}

public struct WorkflowRunDraft: Codable, Equatable, Sendable {
    public var workflowId: String
    public var workflowDigest: String
    public var hostId: String
    public var scope: WorkflowScope
    public var options: WorkflowOptions

    public init(workflowId: String, workflowDigest: String, hostId: String, scope: WorkflowScope, options: WorkflowOptions) {
        self.workflowId = workflowId
        self.workflowDigest = workflowDigest
        self.hostId = hostId
        self.scope = scope
        self.options = options
    }
}

public struct WorkflowRun: Codable, Equatable, Sendable {
    public var workflowId: String
    public var workflowDigest: String
    public var hostId: String
    public var scope: WorkflowScope
    public var options: WorkflowOptions
    public var id: String
    public var actorId: String
    public var state: String
    public var revision: Int
    public var total: Int
    public var processed: Int
    public var createdAt: String
    public var updatedAt: String
    public var error: String?

    public init(workflowId: String, workflowDigest: String, hostId: String, scope: WorkflowScope, options: WorkflowOptions, id: String, actorId: String, state: String, revision: Int, total: Int, processed: Int, createdAt: String, updatedAt: String, error: String? = nil) {
        self.workflowId = workflowId
        self.workflowDigest = workflowDigest
        self.hostId = hostId
        self.scope = scope
        self.options = options
        self.id = id
        self.actorId = actorId
        self.state = state
        self.revision = revision
        self.total = total
        self.processed = processed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.error = error
    }
}

public struct PluginConfiguration: Codable, Equatable, Sendable {
    public var id: String
    public var digest: String
    public var enabled: Bool

    public init(id: String, digest: String, enabled: Bool) {
        self.id = id
        self.digest = digest
        self.enabled = enabled
    }
}

public struct ManagedWorkflowPlugin: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var digest: String
    public var kind: String
    public var enabled: Bool

    public init(id: String, name: String, version: String, digest: String, kind: String, enabled: Bool) {
        self.id = id
        self.name = name
        self.version = version
        self.digest = digest
        self.kind = kind
        self.enabled = enabled
    }
}

public struct DefaultPlugin: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var description: String

    public init(id: String, name: String, version: String, description: String) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
    }
}

public struct PluginManagement: Codable, Equatable, Sendable {
    public var available: Bool
    public var hostId: String?
    public var running: Bool
    public var error: String?
    public var items: [ManagedWorkflowPlugin]
    public var defaults: [DefaultPlugin]

    public init(available: Bool, hostId: String? = nil, running: Bool, error: String? = nil, items: [ManagedWorkflowPlugin], defaults: [DefaultPlugin]) {
        self.available = available
        self.hostId = hostId
        self.running = running
        self.error = error
        self.items = items
        self.defaults = defaults
    }
}

public struct WorkflowPackageSummary: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var digest: String
    public var kind: String

    public init(id: String, name: String, version: String, digest: String, kind: String) {
        self.id = id
        self.name = name
        self.version = version
        self.digest = digest
        self.kind = kind
    }
}

public struct WorkflowAdvertisement: Codable, Equatable, Sendable {
    public var packages: [WorkflowPackageSummary]

    public init(packages: [WorkflowPackageSummary]) {
        self.packages = packages
    }
}

public struct WorkflowDecision: Codable, Equatable, Sendable {
    public var decision: String

    public init(decision: String) {
        self.decision = decision
    }
}

public struct WorkflowFindingResponse: Codable, Equatable, Sendable {
    public var finding: WorkflowFinding

    public init(finding: WorkflowFinding) {
        self.finding = finding
    }
}

public struct WorkflowHost: Codable, Equatable, Sendable {
    public var packages: [WorkflowPackageSummary]?
    public var lastSeenAt: String?
    public var id: String
    public var ownerId: String
    public var name: String
    public var enrolled: Bool
    public var revokedAt: String?
    public var createdAt: String

    public init(packages: [WorkflowPackageSummary]? = nil, lastSeenAt: String? = nil, id: String, ownerId: String, name: String, enrolled: Bool, revokedAt: String? = nil, createdAt: String) {
        self.packages = packages
        self.lastSeenAt = lastSeenAt
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.enrolled = enrolled
        self.revokedAt = revokedAt
        self.createdAt = createdAt
    }
}

public struct WorkflowHostResponse: Codable, Equatable, Sendable {
    public var host: WorkflowHost

    public init(host: WorkflowHost) {
        self.host = host
    }
}

public struct WorkflowLease: Codable, Equatable, Sendable {
    public var runId: String
    public var hostId: String
    public var fence: Int
    public var expiresAt: String
    public var publicationSequence: Int?
    public var checkpointRef: String?

    public init(runId: String, hostId: String, fence: Int, expiresAt: String, publicationSequence: Int? = nil, checkpointRef: String? = nil) {
        self.runId = runId
        self.hostId = hostId
        self.fence = fence
        self.expiresAt = expiresAt
        self.publicationSequence = publicationSequence
        self.checkpointRef = checkpointRef
    }
}

public struct WorkflowSourceSnapshot: Codable, Equatable, Sendable {
    public var sourceId: String
    public var indexValidator: String
    public var selectionRevision: Int
    public var state: String
    public var outputJson: String?

    public init(sourceId: String, indexValidator: String, selectionRevision: Int, state: String, outputJson: String? = nil) {
        self.sourceId = sourceId
        self.indexValidator = indexValidator
        self.selectionRevision = selectionRevision
        self.state = state
        self.outputJson = outputJson
    }
}

public struct WorkflowPublication: Codable, Equatable, Sendable {
    public var sequence: Int
    public var checkpointRef: String
    public var completedSourceIds: [String]
    public var state: String?
    public var sourceOutputs: [WorkflowSourceOutput]?

    public init(sequence: Int, checkpointRef: String, completedSourceIds: [String], state: String? = nil, sourceOutputs: [WorkflowSourceOutput]? = nil) {
        self.sequence = sequence
        self.checkpointRef = checkpointRef
        self.completedSourceIds = completedSourceIds
        self.state = state
        self.sourceOutputs = sourceOutputs
    }
}

public struct WorkflowFindingDraft: Codable, Equatable, Sendable {
    public var sourceId: String
    public var kind: String
    public var ruleVersion: String
    public var currentValueDigest: String
    public var evidenceDigest: String
    public var reason: String
    public var evidenceIds: [String]

    public init(sourceId: String, kind: String, ruleVersion: String, currentValueDigest: String, evidenceDigest: String, reason: String, evidenceIds: [String]) {
        self.sourceId = sourceId
        self.kind = kind
        self.ruleVersion = ruleVersion
        self.currentValueDigest = currentValueDigest
        self.evidenceDigest = evidenceDigest
        self.reason = reason
        self.evidenceIds = evidenceIds
    }
}

public struct WorkflowFinding: Codable, Equatable, Sendable {
    public var sourceId: String
    public var kind: String
    public var ruleVersion: String
    public var currentValueDigest: String
    public var evidenceDigest: String
    public var reason: String
    public var evidenceIds: [String]
    public var id: String
    public var runId: String
    public var fingerprint: String
    public var dismissed: Bool

    public init(sourceId: String, kind: String, ruleVersion: String, currentValueDigest: String, evidenceDigest: String, reason: String, evidenceIds: [String], id: String, runId: String, fingerprint: String, dismissed: Bool) {
        self.sourceId = sourceId
        self.kind = kind
        self.ruleVersion = ruleVersion
        self.currentValueDigest = currentValueDigest
        self.evidenceDigest = evidenceDigest
        self.reason = reason
        self.evidenceIds = evidenceIds
        self.id = id
        self.runId = runId
        self.fingerprint = fingerprint
        self.dismissed = dismissed
    }
}

public struct WorkflowEvidence: Codable, Equatable, Sendable {
    public var id: String
    public var runId: String
    public var sourceId: String
    public var kind: String
    public var sourceValidator: String
    public var providerId: String?
    public var payloadJson: String

    public init(id: String, runId: String, sourceId: String, kind: String, sourceValidator: String, providerId: String? = nil, payloadJson: String) {
        self.id = id
        self.runId = runId
        self.sourceId = sourceId
        self.kind = kind
        self.sourceValidator = sourceValidator
        self.providerId = providerId
        self.payloadJson = payloadJson
    }
}

public struct CleanupChange: Codable, Equatable, Sendable {
    public var action: String
    public var candidateId: String
    public var artifactId: String?
    public var snapshotJson: String

    public init(action: String, candidateId: String, artifactId: String? = nil, snapshotJson: String) {
        self.action = action
        self.candidateId = candidateId
        self.artifactId = artifactId
        self.snapshotJson = snapshotJson
    }
}

public struct WorkflowProposal: Codable, Equatable, Sendable {
    public var sourceName: String?
    public var evidenceClass: String?
    public var id: String
    public var version: Int
    public var runId: String
    public var findingId: String
    public var sourceId: String
    public var sourceValidator: String
    public var selectionRevision: Int
    public var currentValueDigest: String
    public var change: CleanupChange
    public var evidenceIds: [String]
    public var reason: String
    public var digest: String

    public init(sourceName: String? = nil, evidenceClass: String? = nil, id: String, version: Int, runId: String, findingId: String, sourceId: String, sourceValidator: String, selectionRevision: Int, currentValueDigest: String, change: CleanupChange, evidenceIds: [String], reason: String, digest: String) {
        self.sourceName = sourceName
        self.evidenceClass = evidenceClass
        self.id = id
        self.version = version
        self.runId = runId
        self.findingId = findingId
        self.sourceId = sourceId
        self.sourceValidator = sourceValidator
        self.selectionRevision = selectionRevision
        self.currentValueDigest = currentValueDigest
        self.change = change
        self.evidenceIds = evidenceIds
        self.reason = reason
        self.digest = digest
    }
}

public struct WorkflowArtifact: Codable, Equatable, Sendable {
    public var id: String
    public var runId: String
    public var sourceId: String
    public var sha256: String
    public var size: Int
    public var contentType: String
    public var width: Int
    public var height: Int
    public var attributionJson: String
    public var expiresAt: String?

    public init(id: String, runId: String, sourceId: String, sha256: String, size: Int, contentType: String, width: Int, height: Int, attributionJson: String, expiresAt: String? = nil) {
        self.id = id
        self.runId = runId
        self.sourceId = sourceId
        self.sha256 = sha256
        self.size = size
        self.contentType = contentType
        self.width = width
        self.height = height
        self.attributionJson = attributionJson
        self.expiresAt = expiresAt
    }
}

public struct WorkflowApproval: Codable, Equatable, Sendable {
    public var id: String
    public var runId: String
    public var actorId: String
    public var runRevision: Int
    public var proposalVersionsJson: String
    public var digest: String
    public var createdAt: String

    public init(id: String, runId: String, actorId: String, runRevision: Int, proposalVersionsJson: String, digest: String, createdAt: String) {
        self.id = id
        self.runId = runId
        self.actorId = actorId
        self.runRevision = runRevision
        self.proposalVersionsJson = proposalVersionsJson
        self.digest = digest
        self.createdAt = createdAt
    }
}

public struct WorkflowApplication: Codable, Equatable, Sendable {
    public var id: String
    public var approvalId: String
    public var sourceId: String
    public var status: String
    public var beforeRevision: Int
    public var afterRevision: Int
    public var resultJson: String
    public var undoExpiresAt: String

    public init(id: String, approvalId: String, sourceId: String, status: String, beforeRevision: Int, afterRevision: Int, resultJson: String, undoExpiresAt: String) {
        self.id = id
        self.approvalId = approvalId
        self.sourceId = sourceId
        self.status = status
        self.beforeRevision = beforeRevision
        self.afterRevision = afterRevision
        self.resultJson = resultJson
        self.undoExpiresAt = undoExpiresAt
    }
}

public struct WorkflowRunList: Codable, Equatable, Sendable {
    public var items: [WorkflowRun]
    public var nextCursor: String?

    public init(items: [WorkflowRun], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct WorkflowFindingList: Codable, Equatable, Sendable {
    public var items: [WorkflowFinding]
    public var nextCursor: String?

    public init(items: [WorkflowFinding], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct WorkflowProposalList: Codable, Equatable, Sendable {
    public var findings: [WorkflowFinding]?
    public var items: [WorkflowProposal]
    public var nextCursor: String?

    public init(findings: [WorkflowFinding]? = nil, items: [WorkflowProposal], nextCursor: String? = nil) {
        self.findings = findings
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct WorkflowSourceSnapshotList: Codable, Equatable, Sendable {
    public var items: [WorkflowSourceSnapshot]
    public var nextCursor: String?

    public init(items: [WorkflowSourceSnapshot], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct WorkflowHostDraft: Codable, Equatable, Sendable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public struct WorkflowHostList: Codable, Equatable, Sendable {
    public var items: [WorkflowHost]

    public init(items: [WorkflowHost]) {
        self.items = items
    }
}

public struct WorkflowHostCreated: Codable, Equatable, Sendable {
    public var host: WorkflowHost
    public var enrollmentToken: String

    public init(host: WorkflowHost, enrollmentToken: String) {
        self.host = host
        self.enrollmentToken = enrollmentToken
    }
}

public struct WorkflowEnrollmentDraft: Codable, Equatable, Sendable {
    public var enrollmentToken: String

    public init(enrollmentToken: String) {
        self.enrollmentToken = enrollmentToken
    }
}

public struct WorkflowHostEnrolled: Codable, Equatable, Sendable {
    public var host: WorkflowHost
    public var token: String

    public init(host: WorkflowHost, token: String) {
        self.host = host
        self.token = token
    }
}

public struct WorkflowRunResponse: Codable, Equatable, Sendable {
    public var run: WorkflowRun

    public init(run: WorkflowRun) {
        self.run = run
    }
}

public struct WorkflowClaimDraft: Codable, Equatable, Sendable {
    public var waitMs: Int?

    public init(waitMs: Int? = nil) {
        self.waitMs = waitMs
    }
}

public struct WorkflowClaimResponse: Codable, Equatable, Sendable {
    public var lease: WorkflowLease?
    public var run: WorkflowRun?

    public init(lease: WorkflowLease? = nil, run: WorkflowRun? = nil) {
        self.lease = lease
        self.run = run
    }
}

public struct WorkflowHeartbeatDraft: Codable, Equatable, Sendable {
    public var lease: WorkflowLease

    public init(lease: WorkflowLease) {
        self.lease = lease
    }
}

public struct WorkflowPublishDraft: Codable, Equatable, Sendable {
    public var lease: WorkflowLease
    public var publication: WorkflowPublication

    public init(lease: WorkflowLease, publication: WorkflowPublication) {
        self.lease = lease
        self.publication = publication
    }
}

public struct WorkflowInterruptDraft: Codable, Equatable, Sendable {
    public var lease: WorkflowLease
    public var recoveryRequired: Bool

    public init(lease: WorkflowLease, recoveryRequired: Bool) {
        self.lease = lease
        self.recoveryRequired = recoveryRequired
    }
}

public struct WorkflowSelectionSummary: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var title: String
    public var systemId: String?
    public var artworkRole: String?
    public var contentAvailable: Bool
    public var identityConflict: Bool

    public init(id: String, kind: String, title: String, systemId: String? = nil, artworkRole: String? = nil, contentAvailable: Bool, identityConflict: Bool) {
        self.id = id
        self.kind = kind
        self.title = title
        self.systemId = systemId
        self.artworkRole = artworkRole
        self.contentAvailable = contentAvailable
        self.identityConflict = identityConflict
    }
}

public struct WorkflowSourceFacts: Codable, Equatable, Sendable {
    public var sourceId: String
    public var name: String
    public var systemId: String?
    public var sourceValidator: String
    public var selectionRevision: Int
    public var currentValueDigest: String
    public var selected: [WorkflowSelectionSummary]
    public var evidenceIds: [String]

    public init(sourceId: String, name: String, systemId: String? = nil, sourceValidator: String, selectionRevision: Int, currentValueDigest: String, selected: [WorkflowSelectionSummary], evidenceIds: [String]) {
        self.sourceId = sourceId
        self.name = name
        self.systemId = systemId
        self.sourceValidator = sourceValidator
        self.selectionRevision = selectionRevision
        self.currentValueDigest = currentValueDigest
        self.selected = selected
        self.evidenceIds = evidenceIds
    }
}

public struct WorkflowCatalogCandidate: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var title: String
    public var systemId: String?
    public var artworkRole: String?
    public var providerId: String
    public var evidenceClass: String
    public var identityConflict: Bool
    public var agreesWithSelection: Bool
    public var evidenceIds: [String]

    public init(id: String, kind: String, title: String, systemId: String? = nil, artworkRole: String? = nil, providerId: String, evidenceClass: String, identityConflict: Bool, agreesWithSelection: Bool, evidenceIds: [String]) {
        self.id = id
        self.kind = kind
        self.title = title
        self.systemId = systemId
        self.artworkRole = artworkRole
        self.providerId = providerId
        self.evidenceClass = evidenceClass
        self.identityConflict = identityConflict
        self.agreesWithSelection = agreesWithSelection
        self.evidenceIds = evidenceIds
    }
}

public struct WorkflowCatalogProblem: Codable, Equatable, Sendable {
    public var providerId: String
    public var code: String

    public init(providerId: String, code: String) {
        self.providerId = providerId
        self.code = code
    }
}

public struct WorkflowCatalogResult: Codable, Equatable, Sendable {
    public var facts: WorkflowSourceFacts
    public var candidates: [WorkflowCatalogCandidate]
    public var problems: [WorkflowCatalogProblem]
    public var supportedIdentity: Bool

    public init(facts: WorkflowSourceFacts, candidates: [WorkflowCatalogCandidate], problems: [WorkflowCatalogProblem], supportedIdentity: Bool) {
        self.facts = facts
        self.candidates = candidates
        self.problems = problems
        self.supportedIdentity = supportedIdentity
    }
}

public struct WorkflowObservation: Codable, Equatable, Sendable {
    public var sourceId: String
    public var kind: String
    public var reason: String
    public var evidenceIds: [String]
    public var candidateIds: [String]

    public init(sourceId: String, kind: String, reason: String, evidenceIds: [String], candidateIds: [String]) {
        self.sourceId = sourceId
        self.kind = kind
        self.reason = reason
        self.evidenceIds = evidenceIds
        self.candidateIds = candidateIds
    }
}

public struct WorkflowSuggestionsDraft: Codable, Equatable, Sendable {
    public var sourceId: String
    public var observations: [WorkflowObservation]
    public var proposals: [WorkflowProposalSuggestion]?

    public init(sourceId: String, observations: [WorkflowObservation], proposals: [WorkflowProposalSuggestion]? = nil) {
        self.sourceId = sourceId
        self.observations = observations
        self.proposals = proposals
    }
}

public struct WorkflowSuggestionResponse: Codable, Equatable, Sendable {
    public var findings: [WorkflowFinding]
    public var proposals: [WorkflowProposal]?

    public init(findings: [WorkflowFinding], proposals: [WorkflowProposal]? = nil) {
        self.findings = findings
        self.proposals = proposals
    }
}

public struct WorkflowSourceOutput: Codable, Equatable, Sendable {
    public var sourceId: String
    public var outputJson: String

    public init(sourceId: String, outputJson: String) {
        self.sourceId = sourceId
        self.outputJson = outputJson
    }
}

public struct WorkflowProposalSuggestion: Codable, Equatable, Sendable {
    public var sourceId: String
    public var findingId: String
    public var action: String
    public var candidateId: String
    public var evidenceIds: [String]
    public var reason: String

    public init(sourceId: String, findingId: String, action: String, candidateId: String, evidenceIds: [String], reason: String) {
        self.sourceId = sourceId
        self.findingId = findingId
        self.action = action
        self.candidateId = candidateId
        self.evidenceIds = evidenceIds
        self.reason = reason
    }
}

public struct WorkflowArtifactResponse: Codable, Equatable, Sendable {
    public var artifact: WorkflowArtifact

    public init(artifact: WorkflowArtifact) {
        self.artifact = artifact
    }
}

public struct WorkflowEvidenceResponse: Codable, Equatable, Sendable {
    public var evidence: WorkflowEvidence

    public init(evidence: WorkflowEvidence) {
        self.evidence = evidence
    }
}

public struct WorkflowProposalVersion: Codable, Equatable, Sendable {
    public var id: String
    public var version: Int
    public var digest: String

    public init(id: String, version: Int, digest: String) {
        self.id = id
        self.version = version
        self.digest = digest
    }
}

public struct WorkflowApprovalDraft: Codable, Equatable, Sendable {
    public var runRevision: Int
    public var proposals: [WorkflowProposalVersion]

    public init(runRevision: Int, proposals: [WorkflowProposalVersion]) {
        self.runRevision = runRevision
        self.proposals = proposals
    }
}

public struct WorkflowApplicationDraft: Codable, Equatable, Sendable {
    public var applicationId: String

    public init(applicationId: String) {
        self.applicationId = applicationId
    }
}

public struct WorkflowApprovalResponse: Codable, Equatable, Sendable {
    public var approval: WorkflowApproval

    public init(approval: WorkflowApproval) {
        self.approval = approval
    }
}

public struct WorkflowApplicationResponse: Codable, Equatable, Sendable {
    public var application: WorkflowApplication

    public init(application: WorkflowApplication) {
        self.application = application
    }
}

public struct WorkflowApplicationBatchResponse: Codable, Equatable, Sendable {
    public var applications: [WorkflowApplication]

    public init(applications: [WorkflowApplication]) {
        self.applications = applications
    }
}

public struct WorkflowApplicationList: Codable, Equatable, Sendable {
    public var items: [WorkflowApplication]
    public var nextCursor: String?

    public init(items: [WorkflowApplication], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
