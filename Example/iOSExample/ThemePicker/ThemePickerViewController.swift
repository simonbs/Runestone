import Runestone
import UIKit

protocol ThemePickerViewControllerDelegate: AnyObject {
    func themePickerViewController(_ viewController: ThemePickerViewController, didPick theme: ThemeSetting)
}

final class ThemePickerViewController: UITableViewController {
    private enum ReuseIdentifier {
        static let preview = "preview"
        static let theme = "theme"
    }

    private enum Section {
        case preview
        case themes
    }

    private enum Item: Hashable {
        struct PreviewParameters: Hashable {
            let theme: ThemeSetting
        }

        struct ThemeParameters: Hashable {
            let theme: ThemeSetting
            let isSelected: Bool
        }

        case preview(PreviewParameters)
        case theme(ThemeParameters)
    }

    weak var delegate: ThemePickerViewControllerDelegate?

    private var dataSource: UITableViewDiffableDataSource<Section, Item>?
    private var selectedTheme: ThemeSetting

    init(selectedTheme: ThemeSetting) {
        self.selectedTheme = selectedTheme
        super.init(style: .insetGrouped)
        title = "Theme"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        registerCells()
        setupDataSource()
        setupSnapshot()
    }
}

private extension ThemePickerViewController {
    @objc private func done() {
        dismiss(animated: true)
    }

    private func registerCells() {
        tableView.register(ThemePickerPreviewCell.self, forCellReuseIdentifier: ReuseIdentifier.preview)
    }

    private func setupDataSource() {
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { [weak self] _, indexPath, itemIdentifier in
            if let self = self {
                return self.cell(for: itemIdentifier, at: indexPath)
            } else {
                fatalError("Cannot get a cell because self is deallocated")
            }
        }
        tableView.dataSource = dataSource
    }

    private func setupSnapshot() {
        let themeItems: [Item] = ThemeSetting.allCases.map { theme in
            let isSelected = theme == selectedTheme
            let parameters = Item.ThemeParameters(theme: theme, isSelected: isSelected)
            return .theme(parameters)
        }
        let previewParameters = Item.PreviewParameters(theme: selectedTheme)
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.preview, .themes])
        snapshot.appendItems([.preview(previewParameters)], toSection: .preview)
        snapshot.appendItems(themeItems, toSection: .themes)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    private func cell(for item: Item, at indexPath: IndexPath) -> UITableViewCell {
        switch item {
        case .preview(let parameters):
            return previewCell(with: parameters, at: indexPath)
        case .theme(let parameters):
            return themeCell(with: parameters, at: indexPath)
        }
    }

    private func previewCell(with parameters: Item.PreviewParameters, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.preview, for: indexPath)
        guard let typedCell = cell as? ThemePickerPreviewCell else {
            fatalError("Expected cell of type \(ThemePickerPreviewCell.self) but got \(type(of: cell))")
        }
        let theme = parameters.theme.makeTheme()
        let viewModel = ThemePickerPreviewCell.ViewModel(theme: theme, text: CodeSample.default)
        typedCell.populate(with: viewModel)
        return typedCell
    }

    private func themeCell(with parameters: Item.ThemeParameters, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.theme)
        ?? UITableViewCell(style: .default, reuseIdentifier: ReuseIdentifier.theme)
        cell.textLabel?.text = parameters.theme.title
        cell.accessoryType = parameters.isSelected ? .checkmark : .none
        return cell
    }
}

extension ThemePickerViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource?.itemIdentifier(for: indexPath)
        switch item {
        case .theme(let parameters):
            selectedTheme = parameters.theme
            setupSnapshot()
            delegate?.themePickerViewController(self, didPick: parameters.theme)
        case .preview, .none:
            break
        }
    }
}
