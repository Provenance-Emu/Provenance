//
//  UIAlertController+Theming.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/16/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

#if os(iOS)
    extension UIAlertController {
        public struct UIAlertControllerOverrides {
            let backgroundColor: UIColor?
            let textColor: UIColor?
            let borderColor: UIColor?
            let borderWidth: CGFloat
            let cornerRadius: CGFloat
            let cancelBackgroundColor: UIColor?
            let cancelTextColor: UIColor?
            let destructiveBackgroundColor: UIColor?
            let destructiveTextColor: UIColor?

            init(backgroundColor: UIColor? = nil, textColor: UIColor? = nil, borderColor: UIColor? = nil, borderWidth: CGFloat = 0.0, cornerRadius: CGFloat = 0.0, cancelBackgroundColor: UIColor? = nil, cancelTextColor: UIColor? = nil, destructiveBackgroundColor: UIColor? = nil, destructiveTextColor: UIColor? = nil ) {
                self.backgroundColor = backgroundColor
                self.textColor = textColor
                self.borderColor = borderColor
                self.borderWidth = borderWidth
                self.cornerRadius = cornerRadius
                self.cancelBackgroundColor = cancelBackgroundColor
                self.cancelTextColor = cancelTextColor
                self.destructiveBackgroundColor = destructiveBackgroundColor
                self.destructiveTextColor = destructiveTextColor
            }
        }

        // view{load,willAppear,didAppear} had GFX glitches. This seems to render accuratly before animation and after
        // Remove this method if you don't want ALL your UIAlertController's to look the same
        override open func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            setDefaultOverrides()
			if let popoverPresentationController = popoverPresentationController {
				popoverPresentationController.backgroundColor = .clear

			}
        }

		open override func viewWillAppear(_ animated: Bool) {
			super.viewWillAppear(animated)
			setDefaultOverrides()

		}

        // Set how you want your defaults to be for all instances of UIAlertController
        func setDefaultOverrides() {

            let overrides = UIAlertControllerOverrides(backgroundColor: Theme.currentTheme.settingsCellBackground,
                                                       textColor: Theme.currentTheme.settingsCellText,
                                                       borderColor:  Theme.currentTheme.settingsCellText?.withAlphaComponent(0.6),
                                                       borderWidth: 0.0,
                                                       cornerRadius: 10.0,
                                                       cancelBackgroundColor: Theme.currentTheme.settingsCellBackground,
                                                       cancelTextColor: UIColor.init(white: 0.9, alpha: 1),
                                                       destructiveBackgroundColor: UIColor.init(red: 0.5, green: 0.15, blue: 0.15, alpha: 1.0),
                                                       destructiveTextColor: UIColor.init(white: 0.9, alpha: 1))
            setOverrideSettings(overrides)
        }

        func setOverrideSettings(_ settings: UIAlertControllerOverrides) {
            let FirstSubview = self.view.subviews.first
            let AlertContentViews: [UIView?] = [FirstSubview?.subviews.first, FirstSubview?.subviews.last]

            // Find the titles of UIAlertActions that are .cancel type
			#if swift(>=4.1)
            let cancelTitles: [String] = self.actions.filter {$0.style == .cancel}.compactMap {return $0.title}
			#else
			let cancelTitles: [String] = self.actions.filter {$0.style == .cancel}.flatMap {return $0.title}
			#endif

            // Find the titles of UIAlertActions that are .destructive type
			#if swift(>=4.1)
            let destructiveTitles: [String] = self.actions.filter {$0.style == .destructive}.compactMap {return $0.title}
			#else
			let destructiveTitles: [String] = self.actions.filter {$0.style == .destructive}.flatMap {return $0.title}
			#endif

            // TODO: Could do the same for 'destructive' types

            AlertContentViews.forEach {
//                print("AlertContentSubview \(String(describing: $0))")

                $0?.subviews.forEach({ (subview) in
                    if let backgroundColor = settings.backgroundColor {
                        subview.backgroundColor = backgroundColor
                    }

                    subview.layer.cornerRadius = settings.cornerRadius
                    subview.layer.borderWidth = settings.borderWidth
                    subview.alpha = 1

                    if let label = subview as? UILabel, let textColor = settings.textColor {
                        label.textColor = textColor
                    }

                    if let borderColor = settings.borderColor {
                        subview.layer.borderColor = borderColor.cgColor
                    }
                })

                // Set label colors
                if let view = $0, let textColor = settings.textColor {
                    getAllSubviews(ofType: UILabel.self, forView: view)?.forEach {

                        // Check if the label is of the .cancel type
                        if let text = $0.text, cancelTitles.contains(text) {
                            if let cancelBackgroundColor = settings.cancelBackgroundColor {
                                //                            if self.preferredStyle == .actionSheet {
                                $0.superview?.superview?.backgroundColor = cancelBackgroundColor
                                //                            }
                                //                            else {
                                //                                $0.superview?.backgroundColor = cancelBackgroundColor
                                //                            }
                            }
                            if let cancelTextColor = settings.cancelTextColor {
                                $0.textColor = cancelTextColor
                                $0.tintColor = cancelTextColor
                            } else {
                                $0.textColor = textColor
                                $0.tintColor = textColor
                            }
                        } else if let text = $0.text, destructiveTitles.contains(text) {
                            if let destructiveBackgroundColor = settings.destructiveBackgroundColor {
                                //                            if self.preferredStyle == .actionSheet {
                                $0.superview?.superview?.backgroundColor = destructiveBackgroundColor
                                //                            }
                                //                            else {
                                //                                $0.superview?.backgroundColor = destructiveBackgroundColor
                                //                            }
                            }
                            if let destructiveTextColor = settings.destructiveTextColor {
                                $0.textColor = destructiveTextColor
                                $0.tintColor = destructiveTextColor
                            } else {
                                $0.textColor = textColor
                                $0.tintColor = textColor
                            }
                        } else {
                            $0.textColor = textColor
                            $0.tintColor = textColor
                        }
                    }
                }
            }
        }

        // Assistance function to recursively get all subviews of a type
        func getAllSubviews<T: UIView>(ofType type: T.Type, forView view: UIView?) -> [T]? {
			#if swift(>=4.1)
			let mapped = view?.subviews.compactMap { subView -> [T]? in
				var result = getAllSubviews(ofType: T.self, forView: subView)
				if let view = subView as? T {
					result = result ?? [T]()
					result!.append(view)
				}
				return result
			}
			#else
			let mapped = view?.subviews.flatMap { subView -> [T]? in
				var result = getAllSubviews(ofType: T.self, forView: subView)
				if let view = subView as? T {
					result = result ?? [T]()
					result!.append(view)
				}
				return result
			}
			#endif

            return mapped != nil ? Array(mapped!.joined()) : nil
        }
    }
#endif
