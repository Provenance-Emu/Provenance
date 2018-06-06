//
//  PVGameMoreInfoViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit
import RealmSwift
#if os(iOS)
import SafariServices
import AssetsLibrary
#endif

/* TODO:
 Add edit for text fields
 Add long touch for imageview for editing artwork and restoring
 Use a category to impliment the same functions as long press on GameLibraryViewController
 Improove visual look
 Wrap long press of UIGameLibrayVC to if !pushPop available, since all that stuff will be handled in this VC
 Add UICollectionView wrapper
 */
#if os(iOS)
extension UIImageView {
	public override var ignoresInvertColors: Bool {
		get {
			return true
		} set {
		}
	}
}
#endif

// Special label that renders Countries as flag emojis when available
class RegionLabel: LongPressLabel {
    override var text: String? {
        get {
            return super.text
        }
        set {
            let flags = ["Europe" : "🇪🇺", "USA" : "🇺🇸", "Japan" : "🇯🇵", "World" : "🌎", "Korea" : "🇰🇷", "Spain" : "🇪🇸", "Taiwan" : "🇹🇼", "China" : "🇨🇳", "Australia" : "🇦🇺", "Netherlands" : "🇳🇱", "Italy" : "🇮🇹", "Germany" : "🇩🇪", "France" : "🇫🇷", "Brazil" : "🇧🇷", "Asia" : "🌏"]
            let swappedFlagsText = flags.reduce(newValue, { (result, dict) -> String? in
                let (text, flag) = dict
                return result?.replacingOccurrences(of: text, with: flag)
            })
            super.text = swappedFlagsText
        }
    }
}

class LongPressLabel: UILabel {
    #if os(tvOS)
    override var canBecomeFocused: Bool {
        return true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
		super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({ [unowned self] in
            if self.isFocused {
                self.backgroundColor = UIColor.lightGray
            } else {
                self.backgroundColor = nil
            }
            }, completion: nil)
    }
    #endif
}

class GameMoreInfoPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, GameLaunchingViewController, GameSharingViewController {
    var mustRefreshDataSource: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate = self
    }

    var game: PVGame? {
        return (self.viewControllers?.first as? PVGameMoreInfoViewController)?.game
    }

    lazy var games: Results<PVGame> = {
        RomDatabase.sharedInstance.allGamesSortedBySystemThenTitle()
    }()

    // MARK: - Delegate

    // Sent when a gesture-initiated transition begins.
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {

    }

	@IBAction func shareButtonClicked(_ sender: Any) {
		guard let game = game else {
			return
		}

		share(for: game, sender: sender)
	}

    // Sent when a gesture-initiated transition ends. The 'finished' parameter indicates whether the animation finished, while the 'completed' parameter indicates whether the transition completed or bailed out (if the user let go early).
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            #if os(iOS)
                if let referenceURL = game?.referenceURL, !referenceURL.isEmpty {
                    onlineLookupBarButtonItem.isEnabled = true
                } else {
                    onlineLookupBarButtonItem.isEnabled = false
                }
            #endif
        }
    }

    #if os(iOS)
    // Delegate may specify a different spine location for after the interface orientation change. Only sent for transition style 'UIPageViewControllerTransitionStylePageCurl'.
    // Delegate may set new view controllers or update double-sided state within this method's implementation as well.
    public func pageViewController(_ pageViewController: UIPageViewController, spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewControllerSpineLocation {
        return .min
    }

    public func pageViewControllerSupportedInterfaceOrientations(_ pageViewController: UIPageViewController) -> UIInterfaceOrientationMask {
        return [.portrait]
    }

    public func pageViewControllerPreferredInterfaceOrientationForPresentation(_ pageViewController: UIPageViewController) -> UIInterfaceOrientation {
        return .portrait
    }
    #endif

    // MARK: - Data Source
    // In terms of navigation direction. For example, for 'UIPageViewControllerNavigationOrientationHorizontal', view controllers coming 'before' would be to the left of the argument view controller, those coming 'after' would be to the right.
    // Return 'nil' to indicate that no more progress can be made in the given direction.
    // For gesture-initiated transitions, the page view controller obtains view controllers via these methods, so use of setViewControllers:direction:animated:completion: is not required.
    // MARK: - UIPageViewControllerDataSource
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let moreInfoviewController = viewController as? PVGameMoreInfoViewController else {
            ELOG("Wrong controller type \(viewController.debugDescription)")
            return nil
        }
        return nextFrom(viewController: moreInfoviewController, direction: .reverse)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let moreInfoviewController = viewController as? PVGameMoreInfoViewController else {
            ELOG("Wrong controller type \(viewController.debugDescription)")
            return nil
        }
        return nextFrom(viewController: moreInfoviewController, direction: .forward)
    }

    // A page indicator will be visible if both methods are implemented, transition style is 'UIPageViewControllerTransitionStyleScroll', and navigation orientation is 'UIPageViewControllerNavigationOrientationHorizontal'.
    // Both methods are called in response to a 'setViewControllers:...' call, but the presentation index is updated automatically in the case of gesture-driven navigation.
//    public func presentationCount(for pageViewController: UIPageViewController) -> Int // The number of items reflected in the page indicator.
//    public func presentationIndex(for pageViewController: UIPageViewController) -> Int // The selected item reflected in the page indicator.

    private func nextFrom(viewController: PVGameMoreInfoViewController, direction: UIPageViewControllerNavigationDirection) -> PVGameMoreInfoViewController? {
        guard let game = viewController.game, let currentIndex = games.index(of: game) else {
            ELOG("Game or current index was nil")
            return nil
        }

        let nextGameIndex = direction == .forward ? games.index(after: currentIndex) : games.index(before: currentIndex)
        guard nextGameIndex != currentIndex, nextGameIndex < games.count, nextGameIndex >= 0 else {
            ELOG("Game or current index was nil")
            return nil
        }

        let storyboard = UIStoryboard.init(name: "Provenance", bundle: nil)
        let nextViewController = storyboard.instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController

        let nextGame = games[nextGameIndex]
        nextViewController.game = nextGame
        return nextViewController
    }

    // MARK: Actions
    @IBAction func playButtonTapped(_ sender: UIBarButtonItem) {
        if let game = game {
			load(game, sender: sender, core:nil)
        }
    }

    @IBAction func moreInfoButtonClicked(_ sender: UIBarButtonItem) {
        #if os(iOS)

        if #available(iOS 9.0, *) {
            if let urlString = game?.referenceURL, let url = URL(string: urlString) {
                if #available(iOS 11.0, *) {
                    let config = SFSafariViewController.Configuration()
                    config.barCollapsingEnabled = true
                    config.entersReaderIfAvailable = true

                    let webVC = SFSafariViewController(url: url, configuration: config)
                    present(webVC, animated: true, completion: nil)
                } else {
                    let webVC = SFSafariViewController(url: url, entersReaderIfAvailable: true)
                    present(webVC, animated: true, completion: nil)
                }
            }
        } else {
            let alert = UIAlertController(title: "Not supported", message: "Feature requires iOS 9 or above", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
        #endif
    }

    @IBOutlet weak var onlineLookupBarButtonItem: UIBarButtonItem!
}

class PVGameMoreInfoViewController: UIViewController, GameLaunchingViewController, GameSharingViewController {

    @objc
    public var game: PVGame! {
        didSet {
            assert(game != nil, "Set a nil game")

            if game != oldValue {
                registerForChange()

                if isViewLoaded {
                    updateContent()
                }
            }
        }
    }

    @objc
    var showsPlayButton: Bool = true {
        didSet {
            #if os(iOS)
            if showsPlayButton {
                navigationItem.rightBarButtonItems = [playBarButtonItem, onlineLookupBarButtonItem]
            } else {
                navigationItem.rightBarButtonItems = [onlineLookupBarButtonItem]
            }
            #endif
        }
    }

    @IBOutlet weak var artworkImageView: UIImageView!

    @IBOutlet weak var nameLabel: LongPressLabel!
    @IBOutlet weak var systemLabel: UILabel!
    @IBOutlet weak var developerLabel: LongPressLabel!
    @IBOutlet weak var publishDateLabel: LongPressLabel!
    @IBOutlet weak var genresLabel: LongPressLabel!
    @IBOutlet weak var regionLabel: RegionLabel!
    @IBOutlet weak var descriptionTextView: UITextView!

    @IBOutlet var singleImageTapGesture: UITapGestureRecognizer!
    @IBOutlet var doubleImageTapGesture: UITapGestureRecognizer!
    @IBOutlet var imageLongPressGestureRecognizer: UILongPressGestureRecognizer!

    @IBOutlet var playCountLabel: LongPressLabel!
    @IBOutlet var timeSpentLabel: LongPressLabel!

    #if os(iOS)
    @IBOutlet weak var onlineLookupBarButtonItem: UIBarButtonItem!
    #endif
    @IBOutlet weak var playBarButtonItem: UIBarButtonItem!

    var mustRefreshDataSource = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Prevent double tap from triggering single tap also
        #if os(iOS)
        singleImageTapGesture.require(toFail: doubleImageTapGesture)
        #endif

        // Add a shadow to artwork
        let layer = artworkImageView.layer
        artworkImageView.clipsToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 1)
        layer.shadowRadius = 4.0
        layer.shadowOpacity = 0.7

        #if os(iOS)
		// Ignore Smart Invert
		artworkImageView.ignoresInvertColors = true

		if #available(iOS 9.0, *) {

		} else {
			// Fix iOS 8 colors
			descriptionTextView.textColor = Theme.currentTheme.settingsCellText
		}
        #endif
    }

	deinit {
		token?.invalidate()
	}

//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        descriptionTextView.showsVerticalScrollIndicator = true
        descriptionTextView.flashScrollIndicators()
        descriptionTextView.indicatorStyle = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateContent()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    private func secondsToHoursMinutesSeconds (seconds: Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    func updateContent() {
        self.title = game?.title

        #if os(iOS)
        if showsPlayButton {
            navigationItem.rightBarButtonItems = [playBarButtonItem, onlineLookupBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [onlineLookupBarButtonItem]
        }
        #endif

        nameLabel.text = game?.title ?? ""
        systemLabel.text = game?.system.name ?? ""
        developerLabel.text = game?.developer  ?? ""
        publishDateLabel.text = game?.publishDate  ?? ""
        genresLabel.text = game?.genres?.components(separatedBy: ",").joined(separator: ", ")  ?? ""
        regionLabel.text = game?.regionName

        var descriptionText = game?.gameDescription  ?? ""
        #if DEBUG
            descriptionText = [game?.debugDescription ?? "", descriptionText].joined(separator: "\n")
        #endif
        descriptionTextView.text = descriptionText

        let playsText: String
        if let playCount = game?.playCount {
            playsText = "\(playCount)"
        } else {
            playsText = "Never"
        }
        playCountLabel.text = playsText

        let timeSpentText: String
        if let timeSpent = game?.timeSpentInGame {
            let calendar = Calendar(identifier: .gregorian)
            let calendarUnitFlags: Set<Calendar.Component> = Set([.year, .month, .day, .hour, .minute, .second])
            let components = calendar.dateComponents(calendarUnitFlags, from: Date(), to: Date(timeIntervalSinceNow: TimeInterval(timeSpent)))

            var textBuilder = ""
            if let days = components.day, days > 0 {
                textBuilder += "\(days) Days, "
            }

            if let hours = components.hour, hours > 0 {
                textBuilder += "\(hours) Hours, "
            }

            if let minutes = components.minute, minutes > 0 {
                textBuilder += "\(minutes) Minutes, "
            }

            if let seconds = components.second, seconds > 0 {
                textBuilder += "\(seconds) Seconds"
            }

            if !textBuilder.isEmpty {
                timeSpentText = textBuilder
            } else {
                timeSpentText = "None"
            }

        } else {
            timeSpentText = "None"
        }
        timeSpentLabel.text = timeSpentText

        updateImageView()

        #if os(iOS)
        if let referenceURL = game?.referenceURL, !referenceURL.isEmpty {
            onlineLookupBarButtonItem.isEnabled = true
        } else {
            onlineLookupBarButtonItem.isEnabled = false
        }
        #endif
    }

	func image(withText text: String) -> UIImage? {
		#if os(iOS)
		let backgroundColor: UIColor = Theme.currentTheme.settingsCellBackground!
		#else
		let backgroundColor: UIColor = UIColor.init(white: 0.9, alpha: 0.9)
		#endif
		if text == "" {
			return UIImage.image(withSize: CGSize(width: CGFloat(PVThumbnailMaxResolution), height: CGFloat(PVThumbnailMaxResolution)), color: backgroundColor, text: NSAttributedString(string: ""))
		}
		// TODO: To be replaced with the correct system placeholder
		let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center

		#if os(iOS)
		let attributedText = NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 30.0), NSAttributedStringKey.paragraphStyle: paragraphStyle, NSAttributedStringKey.foregroundColor: Theme.currentTheme.settingsCellText!])
		#else
		let attributedText = NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 30.0), NSAttributedStringKey.paragraphStyle: paragraphStyle, NSAttributedStringKey.foregroundColor: UIColor.gray])
		#endif

		let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
		let ratio: CGFloat = game?.boxartAspectRatio.rawValue ?? 1.0
		let width: CGFloat = height * ratio
		let size = CGSize(width: width, height: height)
		let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
		return missingArtworkImage
	}

    var showingFrontArt = true

    var canShowBackArt: Bool {
        if let backArt = game?.boxBackArtworkURL, !backArt.isEmpty {
            return true
        } else {
            return false
        }
    }

	@IBAction func shareButtonClicked(_ sender: Any) {
		share(for: game, sender: sender)
	}

    #if os(iOS)

	@IBAction func moreInfoButtonClicked(_ sender: UIBarButtonItem) {
        if #available(iOS 9.0, *) {
            if let urlString = game?.referenceURL, let url = URL(string: urlString) {
                if #available(iOS 11.0, *) {
                    let config = SFSafariViewController.Configuration()
                    config.barCollapsingEnabled = true
                    config.entersReaderIfAvailable = true

                    let webVC = SFSafariViewController(url: url, configuration: config)
                    present(webVC, animated: true, completion: nil)
                } else {
                    let webVC = SFSafariViewController(url: url, entersReaderIfAvailable: true)
                    present(webVC, animated: true, completion: nil)
                }
            }
        } else {
            let alert = UIAlertController(title: "Not supported", message: "Feature requires iOS 9 or above", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    #endif

    @IBAction func imageViewTapped(_ sender: UITapGestureRecognizer) {
        if canShowBackArt {
            showingFrontArt = !showingFrontArt
            updateImageView()
        }
    }

    @IBAction func imageViewDoubleTapped(_ sender: UITapGestureRecognizer) {
        let mediaZoom = MediaZoom(with: artworkImageView, animationTime: 0.5, useBlur: true)
        view.addSubview(mediaZoom)
        mediaZoom.show {
            mediaZoom.removeFromSuperview()
        }
    }

    @IBAction func playButtonTapped(_ sender: UIBarButtonItem) {
        if let game = game {
			load(game, sender: sender, core: nil)
        }
    }

    private func updateImageView() {
        if showingFrontArt {
            if let imageKey = (game?.customArtworkURL.isEmpty ?? true) ? game?.originalArtworkURL : game?.customArtworkURL {
                PVMediaCache.shareInstance().image(forKey: imageKey, completion: { (key, image) in
                    if let image = image {
                        if self.artworkImageView.image == nil {
                            // Don't animate the first load, it's annoying
                            self.artworkImageView.image = image
                        } else {
                            self.flipImageView(withImage: image)
                        }
					} else {
						self.artworkImageView.image = self.image(withText: self.game.title)
					}
                })
			} else {
				self.artworkImageView.image = self.image(withText: self.game.title)
			}
        } else {
            if let imageKey = game?.boxBackArtworkURL, !imageKey.isEmpty {
                PVMediaCache.shareInstance().image(forKey: imageKey, completion: { (key, image) in
                    if let image = image {
                        self.flipImageView(withImage: image)
                    } else {
                        // Need to download
                        guard let url = URL(string: imageKey) else {
                            ELOG("Couldn't create URL with \(imageKey)")
                            return
                        }

                        // Download the art now
                        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                            if let data = data {

                                // Save to cache for later
                                _ = try? PVMediaCache.writeData(toDisk: data, withKey: imageKey)

                                DispatchQueue.main.async {
                                    if let newImage = UIImage(data: data) {
                                        self.flipImageView(withImage: newImage)
                                    }
                                }
                            }
                        }).resume()
                    }
                })
            }
        }
    }

    private func flipImageView(withImage image: UIImage) {
        let direction: UIViewAnimationOptions = showingFrontArt ? .transitionFlipFromLeft : .transitionFlipFromRight
        UIView.transition(with: artworkImageView, duration: 0.4, options: direction, animations: {
            self.artworkImageView.image = image
        }, completion: nil)
    }

    @IBAction func nameTapped(_ sender: Any) {
		editKey(\PVGame.title, title: "Title", label: nameLabel, reloadGameInfoAfter: true)
    }

    @IBAction func developerTapped(_ sender: Any) {
        editKey(\PVGame.developer, title: "Developer", label: developerLabel)
    }

    @IBAction func publishDateTapped(_ sender: Any) {
        editKey(\PVGame.publishDate, title: "Published Date", label: publishDateLabel)
    }

    @IBAction func genresTapped(_ sender: Any) {
        editKey(\PVGame.genres, title: "Genres", label: genresLabel)
    }

    @IBAction func regionLongPressed(_ sender: Any) {
        editKey(\PVGame.regionName, title: "Regions", label: regionLabel)
    }

    @IBAction func descriptionTapped(_ sender: Any) {
        descriptionTextView.isUserInteractionEnabled = true
        #if os(iOS)
        descriptionTextView.isEditable = true
        #endif
        descriptionTextView.becomeFirstResponder()
        descriptionTextView.delegate = self
    }

    @IBAction func imageLongPressed(_ sender: Any) {
        #if os(iOS)
        askToChangeArtwork()
        #endif
    }

    @IBAction func timeSpentTapped(_ sender: Any) {
        askToResetAnalytics()
    }

    @IBAction func playsTapped(_ sender: Any) {
        askToResetAnalytics()
    }

    // Deal will nullable key paths
    private func editKey(_ key: WritableKeyPath<PVGame, String?>, title: String, label: UILabel) {
        let currentValue = game![keyPath: key]
        let alert = UIAlertController(title: "Edit \(title)", message: nil, preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = title
            textField.text = currentValue
            textField.allowsEditingTextAttributes = false
            textField.clearButtonMode = .always
            textField.keyboardAppearance  = .dark
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { (action) in
            let textField = alert.textFields?.first!
            let submittedValue = textField?.text

            if submittedValue != currentValue {
                do {
                    try RomDatabase.sharedInstance.writeTransaction {
                        self.game![keyPath: key] = submittedValue
                    }
                    label.text = submittedValue
                } catch {
                    ELOG("Failed to update value of \(key) to \(submittedValue ?? "nil"). \(error.localizedDescription)")
                }
            }
        }))

        present(alert, animated: true, completion: nil)
    }

    // Deal with non-null - non-empty keys paths
	private func editKey(_ key: WritableKeyPath<PVGame, String>, title: String, label: UILabel, reloadGameInfoAfter: Bool = false) {

        let currentValue = game![keyPath: key]
        let alert = UIAlertController(title: "Edit \(title)", message: nil, preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = title
            textField.text = currentValue
            textField.allowsEditingTextAttributes = false
            textField.clearButtonMode = .always
            textField.keyboardAppearance  = .dark
            textField.autocapitalizationType = .sentences

        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { (action) in
            let textField = alert.textFields?.first!
            let submittedValue = textField?.text

            if submittedValue == nil || submittedValue!.isEmpty {
                let errAlert = UIAlertController(title: "Invalid Value", message: "\(title) cannot be empty", preferredStyle: .alert)
                errAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(errAlert, animated: true, completion: nil)
            } else if submittedValue != currentValue, let newValue = submittedValue {
                do {
                    try RomDatabase.sharedInstance.writeTransaction {
                        self.game![keyPath: key] = newValue
                    }

                    label.text = newValue

					if reloadGameInfoAfter, self.game.releaseID == nil || self.game.releaseID!.isEmpty {
						PVGameImporter.shared.lookupInfo(for: self.game, overwrite: false)
					}
                } catch {
                    ELOG("Failed to update value of \(key) to \(newValue). \(error.localizedDescription)")
                }
            }
        }))

        present(alert, animated: true, completion: nil)
    }

    var token: NotificationToken?
    func registerForChange() {
		token?.invalidate()
        token = game?.observe({ (change) in
            switch change {
            case .change(let properties):
                if !properties.isEmpty, self.isViewLoaded {
                    DispatchQueue.main.async {
                        self.updateContent()
                    }
                }
            case .error(let error):
                ELOG("An error occurred: \(error)")
            case .deleted:
                print("The object was deleted.")
            }
        })
    }
}

@available(iOS 9.0, *)
extension PVGameMoreInfoViewController {

     // Buttons that shw up under thie VC when it's in a push/pop preview display mode
    override var previewActionItems: [UIPreviewActionItem] {
		guard let game = game else {
			return [UIPreviewActionItem]()
		}

        let playAction = UIPreviewAction(title: "Play", style: .default) { (action, viewController) in
            if let libVC = self.presentingViewController as? PVGameLibraryViewController {
				libVC.load(game, sender: self.view, core: nil)
            }
        }

        let isFavorite = game.isFavorite
        let favoriteToggle = UIPreviewAction(title: "Favorite", style: isFavorite ? .selected : .default) { (action, viewController) in
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    self.game.isFavorite = !self.game.isFavorite
                }
            } catch {
                ELOG("\(error)")
            }
        }

        let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { (action, viewController) in
            let alert = UIAlertController(title: "Delete \(self.game!.title)", message: "Any save states and battery saves will also be deleted, are you sure?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: {(_ action: UIAlertAction) -> Void in
                // Delete from Realm
				do {
					try RomDatabase.sharedInstance.delete(game: game)
				} catch {
					self.presentError(error.localizedDescription)
				}
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
			(UIApplication.shared.delegate?.window??.rootViewController ?? self).present(alert, animated: true)
        }

		let shareAction = UIPreviewAction(title: "Share", style: .default) { (action, viewController) in

			if let libVC = viewController as? (UIViewController & GameSharingViewController) {
				libVC.share(for: game, sender: libVC.view)
			}
		}

		return [playAction, favoriteToggle, shareAction, deleteAction]
    }
}

extension PVGameMoreInfoViewController: UITextViewDelegate {
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == descriptionTextView {
            descriptionTextView.resignFirstResponder()
            #if os(iOS)
            descriptionTextView.isEditable = false
            #endif
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    self.game!.gameDescription = descriptionTextView.text
                }
            } catch {
                ELOG("Failed to update game description : \(error.localizedDescription)")
            }
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

#if os(tvOS)
extension PVGameMoreInfoViewController {
//    override var preferredFocusedView: UIView? {
//        return artworkImageView
//    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [artworkImageView, nameLabel, developerLabel, publishDateLabel, regionLabel, genresLabel, playCountLabel, timeSpentLabel, descriptionTextView]
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
		super.didUpdateFocus(in: context, with: coordinator)

//        coordinator.addCoordinatedAnimations({ [unowned self] in
//
//            }, completion: nil)
    }

//    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
//        super.didUpdateFocus(in: context, with: coordinator)
//
//        if context.nextFocusedView == self {
//            backgroundColor = .red
//        } else if context.previouslyFocusedView == self {
//            backgroundColor = .clear
//        }
//    }
}
#endif

// MARK: - Edit Gesture
extension PVGameMoreInfoViewController {
    private func askToResetAnalytics() {
        let alert = UIAlertController(title: "Erase history?", message: "Would you like to erase your play counter and time spent in \(game!.title)?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    self.game?.playCount = 0
                    self.game?.timeSpentInGame = 0
                }
                self.playCountLabel.text = "0"
                self.timeSpentLabel.text = "None"
            } catch {
                ELOG("Failed to erase play counts. \(error.localizedDescription)")
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func askToChangeArtwork() {
        #if os(iOS)
            guard let game = self.game else {
                return
            }

            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

//            actionSheet.addAction(UIAlertAction(title: "Choose Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                self.chooseCustomArtwork(for: game)
//            }))

            actionSheet.addAction(UIAlertAction(title: "Paste Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.pasteCustomArtwork(for: game)
            }))

//            if !game.originalArtworkURL.isEmpty && game.originalArtworkURL != game.customArtworkURL {
//                actionSheet.addAction(UIAlertAction(title: "Restore Original Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//                    try! PVMediaCache.deleteImage(forKey: game.customArtworkURL)
//
//                    try! RomDatabase.sharedInstance.writeTransaction {
//                        game.customArtworkURL = ""
//                    }
//
//                    let originalArtworkURL: String = game.originalArtworkURL
//                    DispatchQueue.global(qos: .default).async {
//                        self.gameImporter?.getArtworkFromURL(originalArtworkURL)
//                        DispatchQueue.main.async {
//                            let indexPaths = self.indexPathsForGame(withMD5Hash: game.md5Hash)
//                            self.fetchGames()
//                            self.collectionView?.reloadItems(at: indexPaths)
//                        }
//                    }
//                }))
//            }

            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
        #endif
    }

    // TODO: These are copied from PVGameLibraryViewController
    // Can make a protocol with default implimentation instead
    #if os(iOS)
    func chooseCustomArtwork(for game: PVGame) {
//
//        let imagePickerActionSheet = UIActionSheet()
//        let cameraIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
//        let photoLibraryIsAvaialble: Bool = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
//        let cameraAction: PVUIActionSheetAction = {() -> Void in
//            self.gameForCustomArt = game!
//            let pickerController = UIImagePickerController()
//            pickerController.delegate = weakSelf
//            pickerController.allowsEditing = false
//            pickerController.sourceType = .camera
//            self.present(pickerController, animated: true) {() -> Void in }
//        }
//        let libraryAction: PVUIActionSheetAction = {() -> Void in
//            self.gameForCustomArt = game!
//            let pickerController = UIImagePickerController()
//            pickerController.delegate = weakSelf
//            pickerController.allowsEditing = false
//            pickerController.sourceType = .photoLibrary
//            self.present(pickerController, animated: true) {() -> Void in }
//        }
//
//        assetsLibrary = ALAssetsLibrary()
//        assetsLibrary?.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupSavedPhotos), using: { (group, stop) in
//            guard let group = group else {
//                return
//            }
//
//            group.setAssetsFilter(ALAssetsFilter.allPhotos())
//            let index: Int = group.numberOfAssets() - 1
//            VLOG("Group: \(group)")
//            if index >= 0 {
//                var indexPathsToUpdate = [IndexPath]()
//
//                group.enumerateAssets(at: IndexSet(integer: index), options: [], using: { (result, index, stop) in
//                    if let rep: ALAssetRepresentation = result?.defaultRepresentation() {
//                        imagePickerActionSheet.pv_addButton(withTitle: "Use Last Photo Taken", action: {() -> Void in
//                            let orientation : UIImageOrientation = UIImageOrientation(rawValue: rep.orientation().rawValue)!
//
//                            let lastPhoto = UIImage(cgImage: rep.fullScreenImage().takeUnretainedValue(), scale: CGFloat(rep.scale()), orientation: orientation)
//
//                            do {
//                                try PVMediaCache.writeImage(toDisk: lastPhoto, withKey: rep.url().path)
//                                try RomDatabase.sharedInstance.writeTransaction {
//                                    game.customArtworkURL = rep.url().path
//                                }
//                            } catch {
//                                ELOG("Failed to set custom artwork URL for game \(game.title) \n \(error.localizedDescription)")
//                            }
//
//                            let indexPaths = self.indexPathsForGame(withMD5Hash: game.md5Hash)
//                            indexPathsToUpdate.append(contentsOf: indexPaths)
//                            self.fetchGames()
//                            self.assetsLibrary = nil
//                        })
//                        if cameraIsAvailable || photoLibraryIsAvaialble {
//                            if cameraIsAvailable {
//                                imagePickerActionSheet.pv_addButton(withTitle: "Take Photo...", action: cameraAction)
//                            }
//                            if photoLibraryIsAvaialble {
//                                imagePickerActionSheet.pv_addButton(withTitle: "Choose from Library...", action: libraryAction)
//                            }
//                        }
//                        imagePickerActionSheet.pv_addCancelButton(withTitle: "Cancel", action: nil)
//                        imagePickerActionSheet.show(in: self.view)
//                    }
//                })
//
//                DispatchQueue.main.async {
//                    self.collectionView?.reloadItems(at: indexPathsToUpdate)
//                }
//            }
//            else {
//                let alert = UIAlertController(title: "No Photos", message: "There are no photos in your library to choose from", preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//                self.present(alert, animated: true) {() -> Void in }
//            }
//        }, failureBlock: { (error) in
//            if cameraIsAvailable || photoLibraryIsAvaialble {
//                if cameraIsAvailable {
//                    imagePickerActionSheet.pv_addButton(withTitle: "Take Photo...", action: cameraAction)
//                }
//                if photoLibraryIsAvaialble {
//                    imagePickerActionSheet.pv_addButton(withTitle: "Choose from Library...", action: libraryAction)
//                }
//            }
//            imagePickerActionSheet.pv_addCancelButton(withTitle: "Cancel", action: nil)
//            imagePickerActionSheet.show(in: self.view)
//            self.assetsLibrary = nil
//        })
    }

    func pasteCustomArtwork(for game: PVGame) {
        let pb = UIPasteboard.general
        var pastedImageMaybe: UIImage? = pb.image

        let pastedURL: URL? = pb.url

        if pastedImageMaybe == nil {
            if let pastedURL = pastedURL {
                do {
                    let data = try Data(contentsOf: pastedURL)
                    pastedImageMaybe = UIImage(data: data)
                } catch {
                    ELOG("Failed to read pasteboard URL: \(error.localizedDescription)")
                }
            } else {
                ELOG("No image or image url in pasteboard")
                return
            }
        }

        if let pastedImage = pastedImageMaybe {
            var key: String
            if let pastedURL = pastedURL {
                key = pastedURL.lastPathComponent
            } else {
                key = UUID().uuidString
            }

            do {
                try PVMediaCache.writeImage(toDisk: pastedImage, withKey: key)
                try RomDatabase.sharedInstance.writeTransaction {
                    game.customArtworkURL = key
                }
                self.updateImageView()
            } catch {
                ELOG("Failed to set custom artwork URL for game \(game.title).\n\(error.localizedDescription)")
            }
        } else {
            ELOG("No pasted image")
        }
    }

    #endif

}

// TEMP

//
//  MediaZoom.swift
//  MediaZoom (https://github.com/xmartlabs/XLMediaZoom)
//
//  Copyright (c) 2017 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit

public class MediaZoom: UIView, UIScrollViewDelegate {

    public lazy var imageView: UIImageView = {
        let image = UIImageView(frame: self.mediaFrame())
        image.clipsToBounds = true
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        image.contentMode = .scaleAspectFill
        return image
    }()

    public var maxAlpha: CGFloat = 1
    public var hideHandler: (() -> Void)?
    public var useBlurEffect = false
    public var animationTime: Double
    public var originalImageView: UIImageView
    public var backgroundView: UIView
    public lazy var contentView: UIScrollView = {
        let contentView = UIScrollView(frame: MediaZoom.currentFrame())
        contentView.contentSize = self.mediaFrame().size
        contentView.backgroundColor = .clear
        contentView.maximumZoomScale = 1.5
        return contentView
    }()

    public init(with image: UIImageView, animationTime: Double, useBlur: Bool = false) {
        let frame = MediaZoom.currentFrame()
        self.animationTime = animationTime
        useBlurEffect = useBlur
        originalImageView = image
        backgroundView = MediaZoom.backgroundView(with: frame, useBlur: useBlur)
        super.init(frame: frame)

        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange(notification:)),
            name: .UIDeviceOrientationDidChange,
            object: nil
        )
        #endif
        imageView.image = image.image
        addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleSingleTap(sender:))
            )
        )
        contentView.addSubview(imageView)
        contentView.delegate = self
        addSubview(backgroundView)
        addSubview(contentView)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show(onHide callback: (() -> Void)? = nil) {
        let frame = MediaZoom.currentFrame()
        self.frame = frame
        backgroundView.frame = frame
        imageView.frame = mediaFrame()
        hideHandler = callback
        UIView.animate(
            withDuration: animationTime,
            animations: { [weak self] in
                guard let `self` = self else { return }
                self.imageView.frame = self.imageFrame()
                self.backgroundView.alpha = self.maxAlpha
            },
            completion: { [weak self] finished in
                if finished {
                    self?.showAnimationDidFinish()
                }
            }
        )
    }

    private static func backgroundView(with frame: CGRect, useBlur: Bool) -> UIView {
        if useBlur {
            let blurView = UIVisualEffectView(frame: frame)
            blurView.effect = UIBlurEffect(style: .dark)
            blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            blurView.alpha = 0
            return blurView
        } else {
            let bgView = UIView(frame: frame)
            bgView.backgroundColor = .black
            bgView.alpha = 0
            return bgView
        }
    }

    private static func currentFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        return CGRect(
            x: CGFloat(0),
            y: CGFloat(0),
            width: screenSize.width,
            height: screenSize.height
        )
    }

    private func imageFrame() -> CGRect {
        let size = bounds
        guard let imageSize = imageView.image?.size else { return CGRect.zero }
        let ratio = min(size.height / imageSize.height, size.width / imageSize.width)
        let imageWidth = imageSize.width * ratio
        let imageHeight = imageSize.height * ratio
        let imageX = (frame.size.width - imageWidth) * 0.5
        let imageY = (frame.size.height - imageHeight) * 0.5
        return CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
    }

    private func mediaFrame() -> CGRect {
        return originalImageView.frame
    }

    #if os(iOS)
    @objc func deviceOrientationDidChange(notification: NSNotification) {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight, .portrait:
            let newFrame = MediaZoom.currentFrame()
            frame = newFrame
            backgroundView.frame = newFrame
            imageView.frame = imageFrame()
        default:
            break
        }
    }
    #endif

    @objc public func handleSingleTap(sender: UITapGestureRecognizer) {
        willHandleSingleTap()
        UIView.animate(
            withDuration: animationTime,
            animations: { [weak self] in
                guard let `self` = self else { return }
                self.contentView.zoomScale = 1
                self.imageView.frame = self.mediaFrame()
                self.backgroundView.alpha = 0
            },
            completion: { [weak self] finished in
                if finished {
                    self?.removeFromSuperview()
                    self?.contentView.zoomScale = 1
                    self?.hideHandler?()
                }
            }
        )
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        let yOffset = (scrollView.frame.height - imageView.frame.height) / 2.0
        let xOffset = (scrollView.frame.width - imageView.frame.width) / 2.0
        let x = xOffset > 0 ? xOffset : scrollView.frame.origin.x
        let y = yOffset > 0 ? yOffset : scrollView.frame.origin.y
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.imageView.frame.origin = CGPoint(x: x, y: y)
        }
        return imageView
    }

    open func willHandleSingleTap() {

    }

    open func showAnimationDidFinish() {

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
