
import UIKit
import AGEVideoLayout

class BaseViewController: AGViewController {
    var configs: [String:Any] = [:]
    override func viewDidLoad() {
        LogUtils.removeAll()
    }
    
    func showAlert(title: String? = nil, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(action)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func getAudioLabel(uid:UInt, isLocal:Bool) -> String {
        return "AUDIO ONLY\n\(isLocal ? "Local" : "Remote")\n\(uid)"
    }
}

extension AGEVideoContainer {
    func layoutStream(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count == 1 {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 1, height: 1)))
        } else if count == 2 {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.5, height: 1)))
        } else if count > 2, count < 5 {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.5, height: 0.5)))
        } else {
            return
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream1x2(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 2  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 1, height: 0.5)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream2x1(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 2  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.5, height: 1)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream2x2(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 4  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.5, height: 0.5)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream2x3(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 6  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.5, height: 0.33)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream3x2(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 6  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.33, height: 0.5)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
    
    func layoutStream3x3(views: [AGView]) {
        let count = views.count
        
        var layout: AGEVideoLayout
        
        if count > 9  {
            return
        } else {
            layout = AGEVideoLayout(level: 0)
                .itemSize(.scale(CGSize(width: 0.33, height: 0.33)))
        }
        
        self.listCount { (level) -> Int in
            return views.count
        }.listItem { (index) -> AGEView in
            return views[index.item]
        }
        
        self.setLayouts([layout])
    }
}
