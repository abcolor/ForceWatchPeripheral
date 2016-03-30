//
//  ViewController.swift
//  ForceWatch
//
//  Created by David Liu on 2016/3/28.
//  Copyright © 2016年 David Liu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var peripheral: ForcePeripheral?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        peripheral = ForcePeripheral()
        peripheral!.startAdvertising()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func pressBtnGetAppName(sender: AnyObject) {        
        self.peripheral?.retrieveAppName({(appName: NSString) -> () in
            print("current app name: \(appName)")
        })
    }

    @IBAction func pressBtnNotify(sender: AnyObject) {
        
        let alert = UIAlertController(title: "send to bt server", message: "input message", preferredStyle: .Alert)
        
        // Add the text field. You can configure it however you need.
        alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
            //textField.keyboardType = UIKeyboardType.NumberPad
            textField.text = "play video"
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            let textField = alert.textFields![0] as UITextField
            if let message = textField.text {
                self.peripheral!.sendControlData(message.dataUsingEncoding(NSUTF8StringEncoding)!)
            }
        }))
                
        self.presentViewController(alert, animated: true, completion: nil)
    }

}

