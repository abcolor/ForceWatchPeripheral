//
//  ForcePeripheral.swift
//  ForceWatch
//
//  Created by David Liu on 2016/3/28.
//  Copyright © 2016年 David Liu. All rights reserved.
//

import Foundation
import CoreBluetooth

class ForcePeripheral: NSObject, CBPeripheralManagerDelegate {
    
    let serviceName: String = "ForceWatch"
    let serviceUUID: CBUUID = CBUUID(string: "7e58")
    let characteristicControlAppUUID: CBUUID = CBUUID(string: "b81e")
    let characteristicGetAppNameUUID: CBUUID = CBUUID(string: "b82e")
    
    var peripheral: CBPeripheralManager!
    var characteristicControlApp: CBMutableCharacteristic!
    var characteristicGetAppName: CBMutableCharacteristic!
    var service: CBMutableService!
    var pendingData: NSData?
    
    var appNameFetchCompletionBlock: ((NSString) -> ())?

    override init() {
        super.init()
        self.peripheral = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    
    func startAdvertising() {
        if self.peripheral.isAdvertising == true {
            self.peripheral.stopAdvertising()
        }
        
        
        let advertisment:[String: AnyObject!] = [
            CBAdvertisementDataLocalNameKey : self.serviceName,
            CBAdvertisementDataServiceUUIDsKey : [ self.serviceUUID]
        ]
        
        self.peripheral.startAdvertising(advertisment)
    }
    
    func stopAdvertising() {
        self.peripheral.stopAdvertising()
    }
    
    
    func sendControlData(data: NSData) {
        if self.peripheral.state != CBPeripheralManagerState.PoweredOn {
            print("sendToSubscribers: peripheral not ready for sending state: \(self.peripheral.state)")
        }
        else {
            let result = self.peripheral.updateValue(data, forCharacteristic: self.characteristicControlApp, onSubscribedCentrals: nil)
            if result == false {
                print("Failed to send data, buffering data for retry once ready.")
                self.pendingData = data
            }
        }
    }

    func retrieveAppName(completion: ((NSString) -> ())?) {
        if self.peripheral.state != CBPeripheralManagerState.PoweredOn {
            print("sendToSubscribers: peripheral not ready for sending state: \(self.peripheral.state)")
        }
        else {
            self.peripheral.updateValue(NSData(), forCharacteristic: self.characteristicGetAppName, onSubscribedCentrals: nil)
            self.appNameFetchCompletionBlock = completion
        }
    }

    
    // =========================================================================
    // MARK: - Private Functions
    
    private func enableService() {
        
        // If the service is already registered, we need to re-register it again.
        if self.service != nil {
            self.peripheral.removeService(self.service)
        }
        
        // Create a BTLE Peripheral Service and set it to be the primary. If it
        // is not set to the primary, it will not be found when the app is in the
        // background.
        self.service = CBMutableService(type: self.serviceUUID, primary: true)
        
        
        // Set up the characteristic in the service. This characteristic is only
        // readable through subscription (CBCharacteristicsPropertyNotify) and has
        // no default value set.
        
        self.characteristicControlApp = CBMutableCharacteristic(type: self.characteristicControlAppUUID, properties: .Notify, value: nil, permissions: CBAttributePermissions(rawValue: 0))
        
        self.characteristicGetAppName = CBMutableCharacteristic(type: self.characteristicGetAppNameUUID, properties: [ .Write, .Notify], value: nil, permissions: CBAttributePermissions.Writeable)
        
        
        // Assign the characteristic
        self.service.characteristics = [self.characteristicControlApp, self.characteristicGetAppName]
        
        
        // Add the service to the peripheral manager.
        self.peripheral.addService(self.service)
    }
    
    private func disableService() {
        self.peripheral.removeService(self.service)
        self.service = nil
        self.stopAdvertising()
    }

    
    private func isAdvertising() -> Bool {
        return self.peripheral.isAdvertising
    }
 
    // =========================================================================
    // MARK: - CBPeripheralManagerDelegate
    
    @objc func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        self.startAdvertising()
    }
    
    @objc func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        
        print("peripheralStateChange: \(peripheral.state)")
        
        switch peripheral.state {
        case CBPeripheralManagerState.PoweredOn:
            self.enableService()
            
            break
        
        case CBPeripheralManagerState.PoweredOff:
            self.disableService()
            break
            
        default:
            break
        }
    }
    
    @objc func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print("didSubscribe: \(characteristic.UUID)")
    }
    
    
    @objc func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print("didUnsubscribe: \(central.identifier)")
    }
    
    @objc func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print("didStartAdvertising, error: \(error)")
    }
    
    @objc func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        
        print("isReadyToUpdateSubscribers")
        
        if self.pendingData != nil {
            let data = self.pendingData?.copy()
            self.pendingData = nil
            self.sendControlData(data as! NSData)
        }
    }
    
    @objc func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        
        if request.characteristic.UUID == self.characteristicGetAppName.UUID {
            if request.offset > self.characteristicGetAppName.value?.length {
                peripheral.respondToRequest(request, withResult: .InvalidOffset)
            }
            else {
                request.value = self.characteristicGetAppName.value?.subdataWithRange(NSMakeRange(request.offset, (self.characteristicGetAppName.value?.length)! - request.offset))
                peripheral.respondToRequest(request, withResult: .Success)
            }
        }
    }
    
    
    @objc func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        
        let request = requests[0]
        
        self.characteristicGetAppName.value = request.value
        peripheral.respondToRequest(request, withResult: .Success)
        
        if let completion = self.appNameFetchCompletionBlock {
            let appName = NSString(data: request.value!, encoding: NSUTF8StringEncoding)
            completion(appName!)
        }
    }
}