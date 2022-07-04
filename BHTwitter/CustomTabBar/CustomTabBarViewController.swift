//
//  CustomTabBarUtility.swift
//  BHTwitter
//
//  Created by BandarHelal on 11/04/2022.
//

import UIKit

struct item: Codable {
    internal init(title: String, pageID: String) {
        self.title = title
        self.pageID = pageID
    }
    
    var title: String
    var pageID: String
}
struct section {
    internal init(title: String, items: [item]) {
        self.title = title
        self.items = items
    }
    var title: String
    var items: [item]
    
    func saveItems(for key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self.items) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: key)
        }
    }
}

class CustomTabBarUtility: NSObject {
    @objc static func getAllowedTabBars() -> [String]? {
        if let savedItems = UserDefaults.standard.object(forKey: "allowed") as? Data {
            let decoder = JSONDecoder()
            guard let savedList = try? decoder.decode([item].self, from: savedItems) else {
                return nil
            }
            var tmpArr = [String]()
            savedList.forEach {
                tmpArr.append($0.pageID)
            }
            return tmpArr
        }
        return nil
    }
    @objc static func getHiddenTabBars() -> [String]? {
        if let savedItems = UserDefaults.standard.object(forKey: "hidden") as? Data {
            let decoder = JSONDecoder()
            guard let savedList = try? decoder.decode([item].self, from: savedItems) else {
                return nil
            }
            var tmpArr = [String]()
            savedList.forEach {
                tmpArr.append($0.pageID)
            }
            return tmpArr
        }
        return nil
    }
}

class CustomTabBarViewController: UIViewController {
    
    lazy var tableView: UITableView = {
        let table = UITableView(frame: self.view.frame, style: .insetGrouped)
        table.delegate = self
        table.dataSource = self
        table.dragInteractionEnabled = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        table.isEditing = true
        return table
    }()
    var data = [section]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        getData()
        tableView.reloadData()
        restSettingsBarButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func restSettingsBarButton() {
        let restButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(restSettingsBarButtonHandler(_:)))
        self.navigationItem.rightBarButtonItem = restButton
    }
    @objc func restSettingsBarButtonHandler(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Hi", message: "Are sure you want to rest the settings to default?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
            UserDefaults.standard.removeObject(forKey: "allowed")
            UserDefaults.standard.removeObject(forKey: "hidden")
            self.getData()
            self.tableView.reloadData()
        }))
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        self.present(alert, animated: true)
    }
    private func getItems(for key: String) -> [item]? {
        if let savedItems = UserDefaults.standard.object(forKey: key) as? Data {
            let decoder = JSONDecoder()
            return try? decoder.decode([item].self, from: savedItems)
        }
        return nil
    }
    private func getData() {
        if let savedAllowedArr = getItems(for: "allowed"), let savedHiddenArr = getItems(for: "hidden") {
            data = [
                section(title: "Active tab bar", items: savedAllowedArr),
                section(title: "Hidden tab bar", items: savedHiddenArr)
            ]
        } else {
            data = [
                section(title: "Active tab bar", items: [
                    item(title: "Home", pageID: "home"),
                    item(title: "Explore", pageID: "guide"),
                    item(title: "Spaces", pageID: "audiospace"),
                    item(title: "Communities", pageID: "communities"),
                    item(title: "Notifications", pageID: "ntab"),
                    item(title: "Messages", pageID: "messages")
                ]),
                section(title: "Hidden tab bar", items: [])
            ]
        }
    }
    private func updateData() {
        data[0].saveItems(for: "allowed")
        data[1].saveItems(for: "hidden")
    }
}
extension CustomTabBarViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].items.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = data[indexPath.section].items[indexPath.row].title
        return cell!
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return data[section].title
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if (indexPath.section == 0) {
            return .delete
        } else {
            return .insert
        }
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let item = data[indexPath.section].items[indexPath.row]
            data[1].items.append(item)
            data[indexPath.section].items.remove(at: indexPath.row)
            tableView.moveRow(at: indexPath, to: IndexPath(row: (data[1].items.count - 1), section: 1))
        } else if (editingStyle == .insert) {
            let item = data[indexPath.section].items[indexPath.row]
            data[0].items.append(item)
            data[indexPath.section].items.remove(at: indexPath.row)
            tableView.moveRow(at: indexPath, to: IndexPath(row: (data[0].items.count - 1), section: 0))
        }
        updateData()
    }
}
