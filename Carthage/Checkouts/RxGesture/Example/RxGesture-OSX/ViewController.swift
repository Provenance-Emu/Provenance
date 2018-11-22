//
//  ViewController.swift
//  RxGesture-OSX
//
//  Created by Marin Todorov on 3/24/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Cocoa

import RxSwift
import RxCocoa
import RxGesture

class Step {
    enum Action { case previous, next }

    let title: String
    let code: String
    let install: (NSView, NSTextField, AnyObserver<Action>, DisposeBag) -> Void

    init(title: String, code: String, install: @escaping (NSView, NSTextField, AnyObserver<Action>, DisposeBag) -> Void) {
        self.title = title
        self.code = code
        self.install = install
    }
}

class MacViewController: NSViewController {

    @IBOutlet weak var myView: NSView!
    @IBOutlet weak var myViewText: NSTextField!
    @IBOutlet weak var info: NSTextField!
    @IBOutlet weak var code: NSTextView!

    fileprivate let nextStepObserver = PublishSubject<Step.Action>()
    fileprivate let bag = DisposeBag()
    fileprivate var stepBag = DisposeBag()

    override func viewWillAppear() {
        super.viewWillAppear()

        view.wantsLayer = true

        myView.wantsLayer = true
        myView.layer?.backgroundColor = NSColor.red.cgColor
        myView.layer?.cornerRadius = 5

        let steps: [Step] = [
            clickStep,
            doubleClickStep,
            rightClickStep,
            anyClickStep,
            pressStep,
            panStep,
            rotateStep,
            magnificationStep
        ]

        func newIndex(for index: Int, action: Step.Action) -> Int {
            switch action {
            case .previous:
                return index > 0 ? index - 1 : steps.count - 1
            case .next:
                return index < steps.count - 1 ? index + 1 : 0
            }
        }

        nextStepObserver
            .scan(0, accumulator: newIndex)
            .startWith(0)
            .map { (steps[$0], $0) }
            .subscribe(onNext: { [unowned self] in self.updateStep($0, at: $1) })
            .disposed(by: bag)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateAnchorPoint()
    }

    private func updateAnchorPoint() {
        let frame = myView.layer!.frame
        myView.layer!.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        myView.layer!.frame = frame
    }

    @IBAction func previousStep(_ sender: Any) {
        nextStepObserver.onNext(.previous)
    }

    @IBAction func nextStep(_ sender: Any) {
        nextStepObserver.onNext(.next)
    }

    func updateStep(_ step: Step, at index: Int) {
        stepBag = DisposeBag()

        info.stringValue = "\(index + 1). " + step.title
        code.string = step.code

        myViewText.stringValue = ""
        step.install(myView, myViewText, nextStepObserver.asObserver(), stepBag)

        print("active gestures: \(myView.gestureRecognizers.count)")
    }

    lazy var clickStep: Step = Step(
        title: "Click the square",
        code: """
        view.rx
            .leftClickGesture()
            .when(.recognized)
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, _, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)
            view.animateBackgroundColor(to: .red)

            view.rx
                .leftClickGesture()
                .when(.recognized)
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var doubleClickStep: Step = Step(
        title: "Double click the square",
        code: """
        view.rx
            .leftClickGesture { gesture, _ in
                gesture.numberOfClicksRequired = 2
            }
            .when(.recognized)
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, _, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)
            view.animateBackgroundColor(to: .green)

            view.rx
                .leftClickGesture { gesture, _ in
                    gesture.numberOfClicksRequired = 2
                }
                .when(.recognized)
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var rightClickStep: Step = Step(
        title: "Right click the square",
        code: """
        view.rx
            .rightClickGesture()
            .when(.recognized)
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, _, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)
            view.animateBackgroundColor(to: .blue)

            view.rx
                .rightClickGesture()
                .when(.recognized)
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var anyClickStep: Step = Step(
        title: "Click any button (left or right)",
        code: """
        view.rx
            .anyGesture(.leftClick(), .rightClick())
            .when(.recognized)
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, _, nextStep, stepBag in

            view.animateTransform(to: CATransform3DMakeScale(1.5, 1.5, 1.0))
            view.animateBackgroundColor(to: .red)

            view.rx
                .anyGesture(.leftClick(), .rightClick())
                .when(.recognized)
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var pressStep: Step = Step(
        title: "Long press the square",
        code: """
        view.rx
            .pressGesture()
            .when(.began)
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, _, nextStep, stepBag in

            view.animateBackgroundColor(to: .red)
            view.animateTransform(to: CATransform3DMakeScale(2.0, 2.0, 1.0))

            view.rx
                .pressGesture()
                .when(.began)
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var panStep: Step = Step(
        title: "Drag the square around",
        code: """
        view.rx
            .panGesture()
            .when(.changed)
            .asTranslation()
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)

        view.rx
            .anyGesture(
                (.pan(), when: .ended),
                (.click(), when: .recognized)
            )
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, label, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)

            view.rx
                .panGesture()
                .when(.changed)
                .asTranslation()
                .subscribe(onNext: {[unowned self] translation, _ in
                    label.stringValue = String(format: "(%.f, %.f)", arguments: [translation.x, translation.y])
                    view.layer!.transform = CATransform3DMakeTranslation(translation.x, translation.y, 0.0)
                })
                .disposed(by: stepBag)

            view.rx
                .anyGesture(
                    (.pan(), when: .ended),
                    (.leftClick(), when: .recognized)
                )
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var rotateStep: Step = Step(
        title: "Rotate the square with your trackpad, or click if you do not have a trackpad",
        code: """
        view.rx
            .rotationGesture()
            .when(.changed)
            .asRotation()
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)

        view.rx
            .anyGesture(
                (.rotation(), when: .ended),
                (.click(), when: .recognized)
            )
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, label, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)

            view.rx
                .rotationGesture()
                .when(.changed)
                .asRotation()
                .subscribe(onNext: { rotation in
                    label.stringValue = String(format: "angle: %.2f", rotation)
                    view.layer!.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
                })
                .disposed(by: stepBag)

            view.rx
                .anyGesture(
                    (.rotation(), when: .ended),
                    (.leftClick(), when: .recognized)
                )
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

    lazy var magnificationStep: Step = Step(
        title: "Pinch the square with your trackpad, or click if you do not have a trackpad",
        code: """
        view.rx
            .magnificationGesture()
            .when(.changed)
            .asScale()
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)

        view.rx
            .anyGesture(
                (.magnification(), when: .ended),
                (.click(), when: .recognized)
            )
            .subscribe(onNext: { _ in
                // Do something
            })
            .disposed(by: disposeBag)
        """,
        install: { view, label, nextStep, stepBag in

            view.animateTransform(to: CATransform3DIdentity)

            view.rx
                .magnificationGesture()
                .when(.changed)
                .asScale()
                .subscribe(onNext: {[unowned self] scale in
                    label.stringValue = String(format: "scale: %.2f", scale)
                    view.layer!.transform = CATransform3DMakeScale(scale, scale, 1)
                })
                .disposed(by: stepBag)

            view.rx
                .anyGesture(
                    (.magnification(), when: .ended),
                    (.leftClick(), when: .recognized)
                )
                .subscribe(onNext: { _ in
                    nextStep.onNext(.next)
                })
                .disposed(by: stepBag)
    })

}

private extension NSView {

    func animateTransform(to transform: CATransform3D) {
        let initialTransform = self.layer!.transform

        let anim = CABasicAnimation(keyPath: "transform")
        anim.duration = 0.5
        anim.fromValue = NSValue(caTransform3D: initialTransform)
        anim.toValue = NSValue(caTransform3D: transform)
        self.layer!.add(anim, forKey: nil)
        self.layer!.transform = transform
    }

    func animateBackgroundColor(to color: NSColor) {
        let initialColor = self.layer!.backgroundColor!

        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.duration = 0.5
        anim.fromValue = initialColor
        anim.toValue = color.cgColor
        self.layer!.add(anim, forKey: nil)
        self.layer!.backgroundColor = color.cgColor
    }
}
