
import UIKit

struct MenuSection {
    var name: String
    var rows:[MenuItem]
}

struct MenuItem {
    var name: String
    var entry: String = "EntryViewController"
    var storyboard: String = "Main"
    var controller: String
    var note: String = ""
}

class ViewController: AGViewController {
    var menus:[MenuSection] = [
        MenuSection(name: "Basic", rows: [
            MenuItem(name: "Join a channel (Audio)".localized, storyboard: "JoinChannelAudio", controller: "")
        ])
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let menuItem = menus[0].rows[0]
        let storyBoard: UIStoryboard = UIStoryboard(name: menuItem.storyboard, bundle: nil)

        let entryViewController:UIViewController = storyBoard.instantiateViewController(withIdentifier: "EntryViewController")
        self.navigationController?.pushViewController(entryViewController, animated: true)

    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menus[section].rows.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return menus.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return menus[section].name
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "menuCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        }
        cell?.textLabel?.text = menus[indexPath.section].rows[indexPath.row].name
        return cell!
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let menuItem = menus[indexPath.section].rows[indexPath.row]
        let storyBoard: UIStoryboard = UIStoryboard(name: menuItem.storyboard, bundle: nil)
        
        if(menuItem.storyboard == "Main") {
            guard let entryViewController = storyBoard.instantiateViewController(withIdentifier: menuItem.entry) as? EntryViewController else { return }
            
            entryViewController.nextVCIdentifier = menuItem.controller
            entryViewController.title = menuItem.name
            entryViewController.note = menuItem.note
            self.navigationController?.pushViewController(entryViewController, animated: true)
        } else {
            let entryViewController:UIViewController = storyBoard.instantiateViewController(withIdentifier: menuItem.entry)
            self.navigationController?.pushViewController(entryViewController, animated: true)
        }
    }
}
