//
//  CredentialsViewController.swift
//  Tinodios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import UIKit
import TinodeSDK

class CredentialsViewController : UIViewController {
    
    @IBOutlet weak var codeText: UITextField!
    
    var meth: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        UiUtils.dismissKeyboardForTaps(onView: self.view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent {
            // If the user's logged in and is voluntarily leaving the verification VC
            // by hitting the Back button.
            let tinode = Cache.getTinode()
            if tinode.isConnectionAuthenticated || tinode.myUid != nil {
                tinode.logout()
            }
        }
    }

    @IBAction func onConfirm(_ sender: UIButton) {
        guard let code = codeText.text else {
            return
        }
        guard let method = meth else {
            return
        }
        
        let tinode = Cache.getTinode()
        
        guard let token = tinode.authToken else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        let c = Credential(meth: method, val: nil, resp: code, params: nil)
        var creds = [Credential]()
        creds.append(c)
        
        do {
            try tinode.loginToken(token: token, creds: creds)?
                .thenApply(onSuccess: { msg in
                    if let ctrl = msg?.ctrl, ctrl.code >= 300 {
                        DispatchQueue.main.async {
                            UiUtils.showToast(message: "Verification failure: \(ctrl.code) \(ctrl.text)")
                        }
                    } else {
                        UiUtils.routeToChatListVC()
                    }
                    return nil
                })
        } catch {
            Cache.log.error("CredentialsVC - loginToken failed: %{public}@", error.localizedDescription)
        }
    }
}
