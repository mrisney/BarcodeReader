//
//  BarcodeScannerController.swift
//  BarcodeReader
//
//  Created by Marc Risney on 18/08/2018.
//

import UIKit
import AVFoundation
import DLParser
import SwiftyJSON

class BarcodeScannerController: UIViewController {

    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    
    var captureSession = AVCaptureSession()
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var barCodeFrameView: UIView?

    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
   
    override func viewDidLoad() {
        super.viewDidLoad()

        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .back)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
//            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        // Start video capture.
        captureSession.startRunning()
        
        // Move the message label and top bar to the front
        view.bringSubview(toFront: messageLabel)
        view.bringSubview(toFront: topbar)
        
        // Initialize barcode Frame to highlight the PDF417 barcode
        barCodeFrameView = UIView()
        
        if let qrCodeFrameView = barCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubview(toFront: qrCodeFrameView)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func sendData(barcodeRawValue: String) {
        
        if presentedViewController != nil {
            return
        }
        
  

        let license =  AAMVAParser(data : barcodeRawValue).parse()
        let json = JSONSerializer.toJson(license)
        //let output = String(describing: license).replacingOccurrences(of: ", ", with: "\n")
        let output = json
        
        
        let alertPrompt = UIAlertController(title: "Sending Data", message: "Sending the following data to WIGLS  \(output)", preferredStyle: .actionSheet)
        let confirmAction = UIAlertAction(title: "Confirm", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            
            if let url = URL(string: barcodeRawValue) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
        
        alertPrompt.addAction(confirmAction)
        alertPrompt.addAction(cancelAction)
        
        present(alertPrompt, animated: true, completion: nil)
    }

}

extension BarcodeScannerController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            barCodeFrameView?.frame = CGRect.zero
            messageLabel.text = "No driver license bar code is detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            barCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                sendData(barcodeRawValue: metadataObj.stringValue!)
                messageLabel.text = metadataObj.stringValue
            }
        }
    }
    
}
