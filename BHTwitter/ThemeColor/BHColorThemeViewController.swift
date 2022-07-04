//
//  BHColorThemeViewController.swift
//  BHTwitter
//
//  Created by BandarHelal on 27/06/2022.
//

import UIKit

class ColorThemeCell: UICollectionViewCell {
    
    var colorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 18
        label.font = .systemFont(ofSize: 15, weight: .bold)
        return label
    }()
    let checkIMG: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .init(systemName: "circle")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(colorLabel)
        self.addSubview(checkIMG)
        
        NSLayoutConstraint.activate([
            colorLabel.topAnchor.constraint(equalTo: self.topAnchor),
            colorLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            colorLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            colorLabel.heightAnchor.constraint(equalToConstant: 36),
            
            checkIMG.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 12),
            checkIMG.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            checkIMG.widthAnchor.constraint(equalToConstant: 24),
            checkIMG.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
struct ColorThemeItem {
    let colorID: Int
    let name: String
    var color: UIColor
    
    init(colorID: Int, name: String, color: UIColor = .label) {
        self.colorID = colorID
        self.name = name
        self.color = color
    }
}

class BHColorThemeViewController: UIViewController {
    
    var colors = [
        ColorThemeItem(colorID: 1, name: "Blue", color: UIColor(argbHexString: "#1D9BF0")!),
        ColorThemeItem(colorID: 2, name: "Yellow", color: UIColor(argbHexString: "#FFD400")!),
        ColorThemeItem(colorID: 3, name: "Red", color: UIColor(argbHexString: "#F91880")!),
        ColorThemeItem(colorID: 4, name: "Purple", color: UIColor(argbHexString: "#7856FF")!),
        ColorThemeItem(colorID: 5, name: "Orange", color: UIColor(argbHexString: "#FF7A00")!),
        ColorThemeItem(colorID: 6, name: "Green", color: UIColor(argbHexString: "#00BA7C")!),
    ] {
        didSet {
            colorCollectionView.reloadData()
        }
    }
    lazy var colorCollectionView: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collection.contentInsetAdjustmentBehavior = .always
        collection.register(ColorThemeCell.self, forCellWithReuseIdentifier: "colorItem")
        collection.delegate = self
        collection.dataSource = self
        collection.translatesAutoresizingMaskIntoConstraints = false
        return collection
    }()
    
    var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a theme color for your Twitter experience that can be seen by you."
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .justified
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.view.addSubview(headerLabel)
        self.view.addSubview(colorCollectionView)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            
            colorCollectionView.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor),
            colorCollectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            colorCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            colorCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
        
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        colorCollectionView.collectionViewLayout.invalidateLayout()
        super.viewWillTransition(to: size, with: coordinator)
    }
}

extension BHColorThemeViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "colorItem", for: indexPath) as! ColorThemeCell
        let currCell = self.colors[indexPath.row]
        
        cell.colorLabel.text = currCell.name
        cell.colorLabel.backgroundColor = currCell.color
        
        if (UserDefaults.standard.object(forKey: "bh_color_theme_selectedColor") != nil) {
            let selectedColor = UserDefaults.standard.integer(forKey: "bh_color_theme_selectedColor")
            switch selectedColor {
            case 1:
                if (currCell.colorID == 1) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            case 2:
                if (currCell.colorID == 2) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            case 3:
                if (currCell.colorID == 3) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            case 4:
                if (currCell.colorID == 4) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            case 5:
                if (currCell.colorID == 5) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            case 6:
                if (currCell.colorID == 6) {
                    collectionView.visibleCells.forEach { cell in
                        guard let colorCell = cell as? ColorThemeCell else {return}
                        colorCell.checkIMG.image = .init(systemName: "circle")
                    }
                    cell.checkIMG.image = .init(systemName: "checkmark.circle")
                }
            default:
                break
            }
        } else {
            if (currCell.colorID == 0) {
                cell.checkIMG.image = .init(systemName: "checkmark.circle")
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let colorItem = self.colors[indexPath.row]
        collectionView.visibleCells.forEach { cell in
            guard let colorCell = cell as? ColorThemeCell else {return}
            colorCell.checkIMG.image = .init(systemName: "circle")
        }
        guard let currCell = collectionView.cellForItem(at: indexPath) as? ColorThemeCell else {return}
        currCell.checkIMG.image = .init(systemName: "checkmark.circle")
        UserDefaults.standard.set(colorItem.colorID, forKey: "bh_color_theme_selectedColor")
        BH_changeTwitterColor(colorItem.colorID)
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
        return CGSize(width: 98, height: 74)
    }
}

// https://github.com/SwifterSwift/SwifterSwift/
public extension UIColor {
    /// SwifterSwift: Create Color from RGB values with optional transparency.
    ///
    /// - Parameters:
    ///   - red: red component.
    ///   - green: green component.
    ///   - blue: blue component.
    ///   - transparency: optional transparency value (default is 1).
    convenience init?(red: Int, green: Int, blue: Int, transparency: CGFloat = 1) {
        guard red >= 0, red <= 255 else { return nil }
        guard green >= 0, green <= 255 else { return nil }
        guard blue >= 0, blue <= 255 else { return nil }

        var trans = transparency
        if trans < 0 { trans = 0 }
        if trans > 1 { trans = 1 }

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: trans)
    }

    /// SwifterSwift: Create Color from hexadecimal string in the format ARGB (alpha-red-green-blue).
    ///
    /// - Parameters:
    ///   - argbHexString: hexadecimal string (examples: 7FEDE7F6, 0x7FEDE7F6, #7FEDE7F6, #f0ff, 0xFF0F, ..).
    convenience init?(argbHexString: String) {
        var string = argbHexString.replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: "#", with: "")

        if string.count <= 4 { // convert hex to long format if in short format
            var str = ""
            for character in string {
                str.append(String(repeating: String(character), count: 2))
            }
            string = str
        }

        guard let hexValue = Int(string, radix: 16) else { return nil }

        let hasAlpha = string.count == 8

        let alpha = hasAlpha ? (hexValue >> 24) & 0xFF : 0xFF
        let red = (hexValue >> 16) & 0xFF
        let green = (hexValue >> 8) & 0xFF
        let blue = hexValue & 0xFF

        self.init(red: red, green: green, blue: blue, transparency: CGFloat(alpha) / 255)
    }
}
