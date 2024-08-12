//
//  UIAlertController+Rx.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//


private extension UIAlertAction {
    static func createReactive(title: String?, style: Style) -> (UIAlertAction, Observable<Void>) {
        let didSelect = PublishSubject<UIAlertAction>()
        let action = UIAlertAction(title: title, style: style, handler: didSelect.onNext)
        return (action, didSelect.map { _ in})
    }
}