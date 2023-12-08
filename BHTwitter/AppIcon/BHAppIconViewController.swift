//
//  BHAppIconViewController.swift
//  BHTwitter
//
//  Created by Bandar Alruwaili
//

import UIKit

struct AppIconItem: Hashable, Codable {
    internal init(id: UUID = UUID(), imageName: String, settingsImageName: String, isPrimaryIcon: Bool) {
        self.id = id
        self.imageName = imageName
        self.settingsImageName = settingsImageName
        self.isPrimaryIcon = isPrimaryIcon
    }
    
    let id: UUID
    let imageName: String
    let settingsImageName: String
    let isPrimaryIcon: Bool
}

class AppIconCell: UICollectionViewCell {
    static let reuseIdentifier = "appicon"
    
    var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 22
        return imageView
    }()
    let checkIMG: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .init(systemName: "circle")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(imageView)
        self.addSubview(checkIMG)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 98),
            imageView.widthAnchor.constraint(equalToConstant: 98),
            
            checkIMG.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            checkIMG.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            checkIMG.widthAnchor.constraint(equalToConstant: 24),
            checkIMG.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
class BHAppIconViewController: UIViewController {
    
    lazy var appIconCollectionView: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collection.contentInsetAdjustmentBehavior = .always
        collection.register(AppIconCell.self, forCellWithReuseIdentifier: AppIconCell.reuseIdentifier)
        collection.delegate = self
        collection.dataSource = self
        collection.translatesAutoresizingMaskIntoConstraints = false
        return collection
    }()
    
    var headerLabel: UILabel = {
        let label = UILabel()
        label.text = BHTBundle.shared().localizedString(forKey: "APP_ICON_HEADER_TITLE")
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .justified
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var icons = [AppIconItem]() {
        didSet {
            appIconCollectionView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppIcons()
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.view.backgroundColor = .systemBackground
        self.view.addSubview(headerLabel)
        self.view.addSubview(appIconCollectionView)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            
            appIconCollectionView.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor),
            appIconCollectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            appIconCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            appIconCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
    }
    
    func setupAppIcons() {
        let appBundle = Bundle.main
        let CFBundleIcons = appBundle.object(forInfoDictionaryKey: "CFBundleIcons") as! Dictionary<String, Any>
        let CFBundlePrimaryIcon = CFBundleIcons["CFBundlePrimaryIcon"] as! Dictionary<String, Any>
        let primaryIcon = CFBundlePrimaryIcon["CFBundleIconName"] as! String
        let CFBundleAlternateIcons = CFBundleIcons["CFBundleAlternateIcons"] as! Dictionary<String, Any>
        
        icons.append(AppIconItem(imageName: primaryIcon, settingsImageName: "Icon-Production-settings", isPrimaryIcon: true))
        
        for (key, _) in CFBundleAlternateIcons {
            icons.append(AppIconItem(imageName: key, settingsImageName: "\(key)-settings", isPrimaryIcon: false))
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        appIconCollectionView.collectionViewLayout.invalidateLayout()
        super.viewWillTransition(to: size, with: coordinator)
    }
}

extension BHAppIconViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return icons.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppIconCell.reuseIdentifier, for: indexPath) as! AppIconCell
        let currCell = self.icons[indexPath.row]
        cell.imageView.image = UIImage(named: currCell.settingsImageName)
        
        if let alternateIconName = UIApplication.shared.alternateIconName {
            if currCell.imageName == alternateIconName {
                collectionView.visibleCells.forEach { cell in
                    guard let iconCell = cell as? AppIconCell else {return}
                    iconCell.checkIMG.image = .init(systemName: "circle")
                }
                cell.checkIMG.image = .init(systemName: "checkmark.circle")
            }
        } else if currCell.isPrimaryIcon {
            collectionView.visibleCells.forEach { cell in
                guard let iconCell = cell as? AppIconCell else {return}
                iconCell.checkIMG.image = .init(systemName: "circle")
            }
            cell.checkIMG.image = .init(systemName: "checkmark.circle")
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let iconItem = self.icons[indexPath.row]
        collectionView.visibleCells.forEach { cell in
            guard let iconCell = cell as? AppIconCell else {return}
            iconCell.checkIMG.image = .init(systemName: "circle")
        }
        guard let currCell = collectionView.cellForItem(at: indexPath) as? AppIconCell else {return}
        UIApplication.shared.setAlternateIconName(iconItem.isPrimaryIcon ? nil : iconItem.imageName) { err in
            if err == nil {
                currCell.checkIMG.image = .init(systemName: "checkmark.circle")
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 98, height: 136)
    }
}
