// PVCheatSearchViewController.swift
// PVUI
//
// iOS view controller for searching the local cheatbase.sqlite and
// importing selected cheat codes into the current game.

#if canImport(UIKit)
import UIKit
import PVLibrary
import PVLogging

/// Displayed when the user taps "Search Database" in the cheats list.
/// Allows filtering the local cheat database by the current game's MD5 or
final class PVCheatSearchViewController: UIViewController {

    // MARK: - Properties

    /// MD5 hash of the current ROM, used for exact matching.
    var gameMD5: String?
    /// Title of the current game, used as a fallback search term.
    var gameTitle: String?
    /// Called with each cheat entry the user chooses to import.
    var onImport: ((CheatDatabaseEntry) -> Void)?

    private var allResults: [CheatDatabaseEntry] = []
    private var filterText: String = ""

    /// Filtered view of `allResults`; derived rather than stored to avoid duplication.
    private var filteredResults: [CheatDatabaseEntry] {
        guard !filterText.isEmpty else { return allResults }
        let lower = filterText.lowercased()
        return allResults.filter {
            $0.cheatName.lowercased().contains(lower) ||
            $0.category.lowercased().contains(lower) ||
            $0.deviceName.lowercased().contains(lower)
        }
    }

    private var isLoading = false
    private var loadingTask: Task<Void, Never>?

    // Debounce timer for search-bar input
    private var filterDebounceTimer: Timer?
    private let filterDebounceInterval: TimeInterval = 0.3

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(PVCheatSearchCell.self, forCellReuseIdentifier: PVCheatSearchCell.reuseID)
        tv.backgroundColor = .retroBlack
        #if !os(tvOS)
        tv.separatorColor = UIColor.retroBlue.withAlphaComponent(0.3)
        #endif
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        return tv
    }()

    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.placeholder = "Filter by name or category"
        sb.delegate = self
        sb.backgroundColor = .retroBlack
        sb.barTintColor = .retroBlack
        #if !os(tvOS)
        sb.searchTextField.backgroundColor = UIColor.retroBlack.withAlphaComponent(0.7)
        sb.searchTextField.textColor = .white
        sb.searchTextField.tintColor = .retroBlue
        #endif
        return sb
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.color = .retroBlue
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var emptyLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = "No cheat codes found"
        lbl.textColor = UIColor.white.withAlphaComponent(0.5)
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 18, weight: .medium)
        lbl.isHidden = true
        return lbl
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CHEAT DATABASE"
        view.backgroundColor = .retroBlack
        navigationController?.navigationBar.applyRetroWaveStyle()
        RetroWaveGridBackground.createGridBackground(for: view, gridColor: UIColor.retroPurple.withAlphaComponent(0.3))

        setupLayout()
        loadCheats()
    }

    deinit {
        loadingTask?.cancel()
        filterDebounceTimer?.invalidate()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Data Loading

    private func loadCheats() {
        guard !isLoading else { return }
        isLoading = true
        activityIndicator.startAnimating()
        emptyLabel.isHidden = true

        // Cancel any in-flight task before starting a new one.
        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self else { return }
            do {
                var results: [CheatDatabaseEntry] = []

                // Try exact MD5 match first
                if let md5 = gameMD5, !md5.isEmpty {
                    results = try await CheatDatabase.shared.searchCheats(byMD5: md5)
                    DLOG("CheatSearch: \(results.count) results by MD5")
                }

                // Fall back to title search if MD5 returned nothing
                if results.isEmpty, let title = gameTitle, !title.isEmpty {
                    results = try await CheatDatabase.shared.searchCheats(byTitle: title)
                    DLOG("CheatSearch: \(results.count) results by title '\(title)'")
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.allResults = results
                    self.isLoading = false
                    self.activityIndicator.stopAnimating()
                    self.emptyLabel.isHidden = !results.isEmpty
                    self.tableView.reloadData()
                }
            } catch {
                guard !Task.isCancelled else { return }
                ELOG("CheatSearch error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                    self.activityIndicator.stopAnimating()
                    self.emptyLabel.text = "Error loading database"
                    self.emptyLabel.isHidden = false
                }
            }
        }
    }

    // MARK: - Filtering

    private func applyFilter(_ text: String) {
        filterText = text
        tableView.reloadData()
        emptyLabel.isHidden = !filteredResults.isEmpty
    }
}

// MARK: - UITableViewDataSource

extension PVCheatSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PVCheatSearchCell.reuseID, for: indexPath) as? PVCheatSearchCell else {
            return UITableViewCell()
        }
        cell.configure(with: filteredResults[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PVCheatSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = filteredResults[indexPath.row]

        let alert = UIAlertController(
            title: "Import Cheat?",
            message: "\"\(entry.cheatName)\"\n\(entry.cheatCode)",
            preferredStyle: .alert
        )
        alert.view.tintColor = .retroBlue
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            self?.onImport?(entry)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension PVCheatSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Debounce rapid keystrokes to avoid per-keystroke table reloads.
        filterDebounceTimer?.invalidate()
        filterDebounceTimer = Timer.scheduledTimer(withTimeInterval: filterDebounceInterval, repeats: false) { [weak self] _ in
            self?.applyFilter(searchText)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        filterDebounceTimer?.invalidate()
        applyFilter(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
}

// MARK: - Cell

private final class PVCheatSearchCell: UITableViewCell {
    static let reuseID = "PVCheatSearchCell"

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .bold)
        l.textColor = .white
        l.numberOfLines = 1
        return l
    }()

    private let codeLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        l.textColor = UIColor.retroBlue
        l.numberOfLines = 2
        return l
    }()

    private let badgeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .retroYellow
        l.numberOfLines = 1
        return l
    }()

    private let stack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .retroBlack
        contentView.backgroundColor = .retroBlack
        selectionStyle = .none

        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(codeLabel)
        stack.addArrangedSubview(badgeLabel)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: CheatDatabaseEntry) {
        nameLabel.text = entry.cheatName
        codeLabel.text = entry.cheatCode
        badgeLabel.text = "\(entry.deviceName)  ·  \(entry.category)"
        applyRetroWaveBorder(color: .retroBlue.withAlphaComponent(0.4), width: 1)
    }
}

#endif
