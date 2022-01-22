//
//  MainView.swift
//  Example
//
//  Created by Simon on 19/01/2022.
//

import Runestone
import UIKit

final class MainView: UIView {
    let textView: TextView = {
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        this.backgroundColor = UIColor(named: "Background")
        this.autocorrectionType = .no
        this.autocapitalizationType = .none
        this.smartDashesType = .no
        this.smartQuotesType = .no
        this.smartInsertDeleteType = .no
        this.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        this.lineSelectionDisplayType = .line
        this.insertionPointColor = UIColor(named: "Foreground")!
        this.selectionBarColor = UIColor(named: "Foreground")!
        this.selectionHighlightColor = UIColor(named: "Foreground")!.withAlphaComponent(0.2)
        this.lineHeightMultiplier = 1.3
        this.kern = 0.3
        this.alwaysBounceVertical = true
        return this
    }()

    init() {
        super.init(frame: .zero)
        setupView()
        setupLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = UIColor(named: "Background")
        addSubview(textView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
