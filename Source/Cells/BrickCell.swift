//
//  BrickCell.swift
//  BrickApp
//
//  Created by Ruben Cagnie on 5/25/16.
//  Copyright © 2016 Wayfair. All rights reserved.
//

import UIKit

// Mark: - Resizeable cells

public protocol AsynchronousResizableCell: class  {
    weak var resizeDelegate: AsynchronousResizableDelegate? { get set }
}

public protocol AsynchronousResizableDelegate: class {
    func performResize(cell: BrickCell, completion: ((Bool) -> Void)?)
}

public protocol ImageDownloaderCell {
    var imageDownloader: ImageDownloader? { get set }
}

public protocol BrickCellTapDelegate: UIGestureRecognizerDelegate {
    func didTapBrickCell(_ brickCell: BrickCell)
}

public protocol OverrideContentSource: class {
    func overrideContent(for brickCell: BrickCell)
    func resetContent(for brickCell: BrickCell)
}

public protocol Bricklike {
    associatedtype BrickType: Brick
    var brick: BrickType { get }
    var index: Int { get }
    var collectionIndex: Int { get }
    var collectionIdentifier: String? { get }
}

extension Bricklike where Self : BrickCell {
    public var brick: BrickType { return _brick as! BrickType }
}

open class BaseBrickCell: UICollectionViewCell {

    // Using the UICollectionViewCell.backgroundView is not really stable
    // Especially when reusing cells, the backgroundView might disappear and reappear when scrolling up or down
    // The suspicion is that the `removeFromSuperview()` is called, even if the view is no longer part of the cell
    // http://stackoverflow.com/questions/23059811/is-uicollectionview-backgroundview-broken
    var brickBackgroundView: UIView? {
        didSet {
            if oldValue?.superview == self.contentView {
                //Make sure not to remove the oldValue from its current superview if it's not this contentview (reusability)
                oldValue?.removeFromSuperview()
            }
            if let view = brickBackgroundView {
                view.frame = self.bounds
                view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                self.contentView.insertSubview(view, at: 0)
            }
        }
    }

    open lazy var bottomSeparatorLine: UIView = {
        return UIView()
    }()

    open lazy var topSeparatorLine: UIView = {
        return UIView()
    }()

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        // Setting zPosition instead of relaying on
        // UICollectionView zIndex management 'fixes' the issue
        // http://stackoverflow.com/questions/12659301/uicollectionview-setlayoutanimated-not-preserving-zindex
        self.layer.zPosition = CGFloat(layoutAttributes.zIndex)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        brickBackgroundView?.frame = self.bounds
    }
}

// MARK: UI Convenience Methods
extension BaseBrickCell {

    public func removeSeparators() {
        bottomSeparatorLine.removeFromSuperview()
        topSeparatorLine.removeFromSuperview()
    }

    public func addSeparatorLine(_ width: CGFloat, onTop: Bool? = false, xOrigin: CGFloat = 0, backgroundColor: UIColor = UIColor.lightGray, height: CGFloat = 0.5) {

        let separator = (onTop == true) ? topSeparatorLine : bottomSeparatorLine

        separator.frame = self.contentView.frame
        separator.backgroundColor = backgroundColor
        separator.frame.size.height = height
        separator.frame.size.width = width

        separator.frame.origin.x = xOrigin
        let originY = (onTop == true) ? 0 : (self.frame.height - separator.frame.height)
        separator.frame.origin.y = originY
        self.contentView.addSubview(separator)
    }
}

open class BrickCell: BaseBrickCell {

    internal var _brick: Brick! {
        didSet {
            self.accessibilityIdentifier = _brick.accessibilityIdentifier
            self.accessibilityLabel = _brick.accessibilityLabel
            self.accessibilityHint = _brick.accessibilityHint
        }
    }
    open var tapGesture: UITapGestureRecognizer?

    open var identifier: String {
        return _brick.identifier
    }

    open fileprivate(set) var index: Int = 0
    open fileprivate(set) var collectionIndex: Int = 0
    open fileprivate(set) var collectionIdentifier: String?

    #if os(tvOS)
    @objc public var allowsFocus: Bool = true
    #endif

    @IBOutlet weak internal var topSpaceConstraint: NSLayoutConstraint? {
        didSet { defaultTopConstraintConstant = topSpaceConstraint?.constant ?? 0 }
    }
    @IBOutlet weak internal var bottomSpaceConstraint: NSLayoutConstraint? {
        didSet { defaultBottomConstraintConstant = bottomSpaceConstraint?.constant ?? 0 }
    }
    @IBOutlet weak internal var leftSpaceConstraint: NSLayoutConstraint? {
        didSet { defaultLeftConstraintConstant = leftSpaceConstraint?.constant ?? 0 }
    }
    @IBOutlet weak internal var rightSpaceConstraint: NSLayoutConstraint? {
        didSet { defaultRightConstraintConstant = rightSpaceConstraint?.constant ?? 0 }
    }

    fileprivate var defaultTopConstraintConstant: CGFloat = 0
    fileprivate var defaultBottomConstraintConstant: CGFloat = 0
    fileprivate var defaultLeftConstraintConstant: CGFloat = 0
    fileprivate var defaultRightConstraintConstant: CGFloat = 0

    open var defaultEdgeInsets: UIEdgeInsets {
        return UIEdgeInsetsMake(defaultTopConstraintConstant, defaultLeftConstraintConstant, defaultBottomConstraintConstant, defaultRightConstraintConstant)
    }

    @objc open dynamic var edgeInsets: UIEdgeInsets = UIEdgeInsets.zero {
        didSet {
            self.topSpaceConstraint?.constant = edgeInsets.top
            self.bottomSpaceConstraint?.constant = edgeInsets.bottom
            self.leftSpaceConstraint?.constant = edgeInsets.left
            self.rightSpaceConstraint?.constant = edgeInsets.right
        }
    }

    open func setContent(_ brick: Brick, index: Int, collectionIndex: Int, collectionIdentifier: String?) {
        self._brick = brick
        self.index = index
        self.collectionIndex = collectionIndex
        self.collectionIdentifier = collectionIdentifier

        self.isUserInteractionEnabled = true
        if let gesture = self.tapGesture {
            self.removeGestureRecognizer(gesture)
        }
        self.tapGesture = nil
        if let _ = brick.brickCellTapDelegate {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(BrickCell.didTapCell))
            gesture.delegate = brick.brickCellTapDelegate
            self.tapGesture = gesture
            addGestureRecognizer(gesture)
        }

        reloadContent()
    }

    open func updateContent() {

    }

    internal func reloadContent() {
        self._brick.overrideContentSource?.resetContent(for: self)
        updateContent()
        self._brick.overrideContentSource?.overrideContent(for: self)
    }

    @objc func didTapCell() {
        _brick.brickCellTapDelegate?.didTapBrickCell(self)
    }

    open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard self._brick.height.isEstimate(withValue: nil) else {
            return layoutAttributes
        }

        let preferred = layoutAttributes.copy() as! UICollectionViewLayoutAttributes

        let size = CGSize(width: layoutAttributes.frame.width, height: self.heightForBrickView(withWidth: layoutAttributes.frame.width))
        preferred.frame.size = size
        return preferred
    }

    open func heightForBrickView(withWidth width: CGFloat) -> CGFloat {
        self.layoutIfNeeded()

        let size = self.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: 1000, verticalFittingPriority: 10)
        return size.height
    }

}

