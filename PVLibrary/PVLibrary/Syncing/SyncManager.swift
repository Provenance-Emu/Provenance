//
//  SyncManager.swift
//  Delta
//
//  Created by Riley Testut on 11/12/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Harmony

private extension UserDefaults
{
    @NSManaged var didValidateHarmonyBetaDatabase: Bool
}

extension SyncManager
{
    enum RecordType: String, Hashable
    {
        case game = "Game"
        case gameCollection = "GameCollection"
        case cheat = "Cheat"
        case saveState = "SaveState"
        case controllerSkin = "ControllerSkin"
        case gameControllerInputMapping = "GameControllerInputMapping"
        case gameSave = "GameSave"
        
        var localizedName: String {
            switch self
            {
            case .game: return NSLocalizedString("Game", comment: "")
            case .gameCollection: return NSLocalizedString("Game Collection", comment: "")
            case .cheat: return NSLocalizedString("Cheat", comment: "")
            case .saveState: return NSLocalizedString("Save State", comment: "")
            case .controllerSkin: return NSLocalizedString("Controller Skin", comment: "")
            case .gameControllerInputMapping: return NSLocalizedString("Game Controller Input Mapping", comment: "")
            case .gameSave: return NSLocalizedString("Game Save", comment: "")
            }
        }
    }
    
    enum Service: String, CaseIterable
    {
        case googleDrive = "com.rileytestut.Harmony.Drive"
        case dropbox = "com.rileytestut.Harmony.Dropbox"
        
        var localizedName: String {
            switch self
            {
            case .googleDrive: return NSLocalizedString("Google Drive", comment: "")
            case .dropbox: return NSLocalizedString("Dropbox", comment: "")
            }
        }
        
        var service: Harmony.Service {
            switch self
            {
            case .googleDrive: return DriveService.shared
            case .dropbox: return DropboxService.shared
            }
        }
    }
    
    enum Error: LocalizedError
    {
        case nilService
        
        var errorDescription: String? {
            switch self
            {
            case .nilService: return NSLocalizedString("There is no chosen service for syncing.", comment: "")
            }
        }
    }
}

extension Syncable where Self: NSManagedObject
{
    var recordType: SyncManager.RecordType {
        let recordType = SyncManager.RecordType(rawValue: self.syncableType)!
        return recordType
    }
}

final class SyncManager
{
    static let shared = SyncManager()
    
    var service: Service? {
        guard let service = self.coordinator?.service else { return nil }
        return Service(rawValue: service.identifier)
    }
    
    var recordController: RecordController? {
        return self.coordinator?.recordController
    }
    
    private(set) var syncProgress: Progress?
        
    private(set) var previousSyncResult: SyncResult?
    
    private(set) var coordinator: SyncCoordinator?
    
    private init()
    {
        DriveService.shared.clientID = "457607414709-7oc45nq59frd7rre6okq22fafftd55g1.apps.googleusercontent.com"
        
        DropboxService.shared.clientID = "f5btgysf9ma9bb6"
        DropboxService.shared.preferredDirectoryName = "Delta Emulator"
        
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.syncingDidFinish(_:)), name: SyncCoordinator.didFinishSyncingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension SyncManager
{
    func start(service: Service?, completionHandler: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        guard let service = service else { return completionHandler(.success) }
        
        let coordinator = SyncCoordinator(service: service.service, persistentContainer: DatabaseManager.shared)
        
        if !UserDefaults.standard.didValidateHarmonyBetaDatabase
        {
            UserDefaults.standard.didValidateHarmonyBetaDatabase = true
            
            coordinator.deauthenticate { (result) in
                do
                {
                    try FileManager.default.removeItem(at: RecordController.defaultDirectoryURL())
                }
                catch CocoaError.fileNoSuchFile
                {
                    // Ignore
                }
                catch
                {
                    print("Failed to remove Harmony database.", error)
                }
                
                self.start(service: service, completionHandler: completionHandler)
            }
            
            return
        }
        
        coordinator.start { (result) in
            do
            {
                _ = try result.get()
                
                self.coordinator = coordinator
                completionHandler(.success)
            }
            catch let authError as AuthenticationError
            {
                // Authentication failed, but otherwise started successfully so still assign self.coordinator.
                self.coordinator = coordinator
                
                switch authError
                {
                case .other(ServiceError.connectionFailed):
                    // Authentication failed due to network connection, but otherwise started successfully so we ignore this error.
                    completionHandler(.success)
                    
                default:
                    // Another authentication error occured, so we'll deauthenticate ourselves.
                    print("SyncManager.start auth error:", authError)
                    
                    self.deauthenticate() { (result) in
                        switch result
                        {
                        case .success:
                            completionHandler(.success)
                            
                        case .failure:
                            // authError is more useful than result's error.
                            completionHandler(.failure(authError))
                        }
                    }
                }
            }
            catch
            {
                print("SyncManager.start error:", error)
                completionHandler(.failure(error))
            }
        }
    }
    
    func reset(for service: Service?, completionHandler: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        if let coordinator = self.coordinator
        {
            coordinator.deauthenticate { (result) in
                self.coordinator = nil
                self.start(service: service, completionHandler: completionHandler)
            }
        }
        else
        {
            self.start(service: service, completionHandler: completionHandler)
        }
    }
    
    func authenticate(presentingViewController: UIViewController? = nil, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    {
        guard let coordinator = self.coordinator else { return completionHandler(.failure(AuthenticationError(Error.nilService))) }
        
        coordinator.authenticate(presentingViewController: presentingViewController) { (result) in
            do
            {
                let account = try result.get()
                
                if !coordinator.recordController.isSeeded
                {
                    coordinator.recordController.seedFromPersistentContainer { (result) in
                        switch result
                        {
                        case .success: completionHandler(.success(account))
                        case .failure(let error): completionHandler(.failure(AuthenticationError(error)))
                        }
                    }
                }
                else
                {
                    completionHandler(.success(account))
                }
            }
            catch
            {
                completionHandler(.failure(AuthenticationError(error)))
            }
        }
    }
    
    func deauthenticate(completionHandler: @escaping (Result<Void, DeauthenticationError>) -> Void)
    {
        guard let coordinator = self.coordinator else { return completionHandler(.success) }
        
        coordinator.deauthenticate(completionHandler: completionHandler)
    }
    
    func sync()
    {
        let progress = self.coordinator?.sync()
        self.syncProgress = progress
    }
}

private extension SyncManager
{
    @objc func syncingDidFinish(_ notification: Notification)
    {
        guard let result = notification.userInfo?[SyncCoordinator.syncResultKey] as? SyncResult else { return }
        self.previousSyncResult = result
        
        self.syncProgress = nil
        
        print("Finished syncing!")
    }
    
    @objc func didEnterBackground(_ notification: Notification)
    {
        self.sync()
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.sync()
    }
}
