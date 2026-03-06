//
//  VirtualKeyboardView.swift
//  PVUI
//
//  Created by Claude on behalf of Provenance Emu.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

#if canImport(UIKit) && !os(tvOS)
import UIKit
import PVCoreBridge
import PVLogging
import GameController

/// Delegate that receives key events from the virtual keyboard.
@available(iOS 14.0, *)
public protocol VirtualKeyboardViewDelegate: AnyObject {
    func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyDown keyCode: GCKeyCode)
    func virtualKeyboard(_ keyboard: VirtualKeyboardView, keyUp keyCode: GCKeyCode)
}

/// A lightweight on-screen keyboard overlay that forwards key events to a
/// `KeyboardResponder` core.  The design intentionally mirrors the retro
/// aesthetic used elsewhere in Provenance (dark background, neon accent).
@available(iOS 14.0, *)
public final class VirtualKeyboardView: UIView {

    // MARK: - Public

    public weak var delegate: VirtualKeyboardViewDelegate?

    // MARK: - Private

    /// All key rows displayed on the keyboard.
    private let rows: [[KeySpec]] = [
        // Function row
        [.init("ESC",  .escape),
         .init("F1",   .F1),  .init("F2",   .F2),   .init("F3",   .F3),   .init("F4",  .F4),
         .init("F5",   .F5),  .init("F6",   .F6),   .init("F7",   .F7),   .init("F8",  .F8),
         .init("F9",   .F9),  .init("F10",  .F10),  .init("F11",  .F11),  .init("F12", .F12)],
        // Number row
        [.init("`",   .graveAccentAndTilde),
         .init("1",   .one),   .init("2",  .two),   .init("3",   .three), .init("4",  .four),
         .init("5",   .five),  .init("6",  .six),   .init("7",   .seven), .init("8",  .eight),
         .init("9",   .nine),  .init("0",  .zero),  .init("-",   .hyphen),
         .init("=",   .equalSign), .init("⌫", .deleteOrBackspace)],
        // QWERTY row
        [.init("TAB", .tab),
         .init("Q",   .keyQ), .init("W",  .keyW),  .init("E",   .keyE), .init("R",  .keyR),
         .init("T",   .keyT), .init("Y",  .keyY),  .init("U",   .keyU), .init("I",  .keyI),
         .init("O",   .keyO), .init("P",  .keyP),  .init("[",   .openBracket),
         .init("]",   .closeBracket), .init("\\", .backslash)],
        // ASDF row
        [.init("CAPS", .capsLock),
         .init("A",   .keyA), .init("S",  .keyS),  .init("D",   .keyD), .init("F",  .keyF),
         .init("G",   .keyG), .init("H",  .keyH),  .init("J",   .keyJ), .init("K",  .keyK),
         .init("L",   .keyL), .init(";",  .semicolon), .init("'", .quote),
         .init("RET", .returnOrEnter)],
        // ZXCV row
        [.init("⇧",   .leftShift),
         .init("Z",   .keyZ), .init("X",  .keyX),  .init("C",   .keyC), .init("V",  .keyV),
         .init("B",   .keyB), .init("N",  .keyN),  .init("M",   .keyM), .init(",",  .comma),
         .init(".",   .period), .init("/", .slash), .init("⇧",  .rightShift)],
        // Bottom row
        [.init("CTRL", .leftControl),
         .init("ALT",  .leftAlt),
         .init("",     .spacebar, widthMultiplier: 5),
         .init("ALT",  .rightAlt),
         .init("CTRL", .rightControl),
         .init("◀",   .leftArrow),
         .init("▲",   .upArrow),
         .init("▼",   .downArrow),
         .init("▶",   .rightArrow)]
    ]

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.92)
        layer.cornerRadius = 12
        layer.masksToBounds = true

        // Subtle separator line at the top
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 4
        outerStack.distribution = .fillEqually
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fill
            for spec in row {
                let btn = makeButton(spec: spec)
                rowStack.addArrangedSubview(btn)
                if spec.widthMultiplier > 1 {
                    btn.widthAnchor.constraint(
                        equalTo: btn.heightAnchor,
                        multiplier: spec.widthMultiplier
                    ).isActive = true
                }
            }
            outerStack.addArrangedSubview(rowStack)
        }
    }

    private func makeButton(spec: KeySpec) -> UIButton {
        let btn = RepeatButton()
        btn.setTitle(spec.label, for: .normal)
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        btn.setTitleColor(UIColor(white: 0.9, alpha: 1), for: .normal)
        btn.setTitleColor(UIColor(white: 0.5, alpha: 1), for: .highlighted)
        btn.backgroundColor = UIColor(white: 0.25, alpha: 1)
        btn.layer.cornerRadius = 5
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = UIColor(white: 0.5, alpha: 0.4).cgColor
        btn.tag = spec.keyCode.rawValue
        btn.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return btn
    }

    // MARK: - Actions

    @objc private func keyTouchDown(_ sender: UIButton) {
        let keyCode = GCKeyCode(rawValue: sender.tag)
        sender.backgroundColor = UIColor(white: 0.45, alpha: 1)
        delegate?.virtualKeyboard(self, keyDown: keyCode)
    }

    @objc private func keyTouchUp(_ sender: UIButton) {
        let keyCode = GCKeyCode(rawValue: sender.tag)
        sender.backgroundColor = UIColor(white: 0.25, alpha: 1)
        delegate?.virtualKeyboard(self, keyUp: keyCode)
    }
}

// MARK: - KeySpec

@available(iOS 14.0, *)
private struct KeySpec {
    let label: String
    let keyCode: GCKeyCode
    let widthMultiplier: CGFloat

    init(_ label: String, _ keyCode: GCKeyCode, widthMultiplier: CGFloat = 1) {
        self.label = label
        self.keyCode = keyCode
        self.widthMultiplier = widthMultiplier
    }
}

// MARK: - RepeatButton (long-press repeat for backspace etc.)

@available(iOS 14.0, *)
private final class RepeatButton: UIButton {
    private var repeatTimer: Timer?
    /// Initial delay before key-repeat starts, matching standard keyboard behaviour (~400 ms).
    private let initialRepeatDelay: TimeInterval = 0.4
    /// Interval between repeated key events once repeat has started (~80 ms).
    private let repeatInterval: TimeInterval = 0.08

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Fire first repeat only after the initial delay, then at `repeatInterval`.
        repeatTimer = Timer.scheduledTimer(withTimeInterval: initialRepeatDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: self.repeatInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.sendActions(for: .touchDown)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
#endif
