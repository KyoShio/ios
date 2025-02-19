//
//  PlaceholderTextView.swift
//  Tinodios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import UIKit

// UITexеView with an optional placeholder text.
@IBDesignable class PlaceholderTextView: UITextView {

    // MARK: constants

    private enum Constants {
        static let defaultPlaceholderColor = UIColor(red: 0.0, green: 0.0, blue: 25/255, alpha: 0.22)
        static let defaultPlaceholderText = "AbCd..."
    }

    private var isShowingPlaceholder: Bool = false

    // MARK: IB variables

    @IBInspectable var placeholderText: String = Constants.defaultPlaceholderText

    @IBInspectable open var mainTextColor: UIColor = UIColor.black
    @IBInspectable open var placeholderColor: UIColor = Constants.defaultPlaceholderColor

    // MARK: overrired UITextView variables

    override var text: String! {
        didSet {
            checkForEmptyText()
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            checkForEmptyText()
        }
    }

    // See explanation here https://stackoverflow.com/questions/13601643/uimenucontroller-hides-the-keyboard/23849955#23849955
    // and here https://github.com/alexpersian/MenuItemTester/blob/master/MenuItemTester/InputTextField.swift
    weak var nextResponderOverride: UIResponder?

    override var next: UIResponder? {
        if nextResponderOverride != nil {
            return nextResponderOverride
        } else {
            return super.next
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if nextResponderOverride != nil {
            return false
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    // MARK: initializers

    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addTextChangeObserver()
        if text.isEmpty {
            textColor = placeholderColor
            text = placeholderText
            isShowingPlaceholder = true
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addTextChangeObserver()
        if text.isEmpty {
            isShowingPlaceholder = true
            textColor = placeholderColor
            text = placeholderText
        }
    }

    // MARK: private methods

    private func addTextChangeObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(textBeginEditing), name: UITextView.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkForEmptyText), name: UITextView.textDidEndEditingNotification, object: nil)
    }

    @objc private func textBeginEditing() {
        if isShowingPlaceholder {
            text = nil
            textColor = mainTextColor
            isShowingPlaceholder = false
        }
    }

    @objc private func checkForEmptyText() {
        if text.isEmpty && !isShowingPlaceholder && !isFirstResponder {
            text = placeholderText
            textColor = placeholderColor
            isShowingPlaceholder = true
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextView.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextView.textDidEndEditingNotification, object: nil)
    }
}
