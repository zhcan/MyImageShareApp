//
//  ViewController.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/19.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    //MARK: properties
    @IBOutlet weak var ipTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var processingState: UILabel!

    //MARK: actions
    @IBAction func connectNetwork(_ sender: UIButton) {
        print("start connect network. ip:\(String(describing: ipTextField.text)), port:\(String(describing: portTextField.text))")
        
        let tmpPort = UInt16(portTextField.text!)
        guard tmpPort != nil else {
            print("port error")
            processingState.text = "Connecting Fail! Port Error!"
            processingState.sizeToFit()
            return
        }
        
        processingState.text = "Connecting Network..."
        processingState.sizeToFit()
        
        SocketManager.shared.initIpPort(ip: ipTextField.text!, port: tmpPort!)
        SocketManager.shared.delegate = self
        SocketManager.shared.connectServer()
    }

    @IBAction func disconnectNetwork(_ sender: UIButton) {
        print("disconnect network.")
        
        processingState.text = "Disconnected"
        processingState.sizeToFit()
        
        SocketManager.shared.disconnectServer()
    }
    
    @IBAction func selectImage(_ sender: UITapGestureRecognizer) {
        print("selectImageFromPhotoList")
        photoImageView.resignFirstResponder()
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        ipTextField.delegate = self
        portTextField.delegate = self
    }

    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing text:\(String(describing: textField.text)), textName:\(String(describing: textField.layer.name)), ip:\(String(describing: ipTextField.text)), port:\(String(describing: portTextField.text))")
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let selectedImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage

        photoImageView.image = selectedImage
        dismiss(animated: true)
        print("select image \(String(describing: photoImageView.image?.description)), id:\(String(describing: photoImageView.image?.accessibilityIdentifier))")

        let imgUrl = info[UIImagePickerController.InfoKey.imageURL]
        let urlString = String(describing: imgUrl)
        let fileNameIdx = urlString.lastIndex(of: "/")
        let fileSuffixIdx = urlString.lastIndex(of: ".")
        let fileName = urlString[urlString.index(after: fileNameIdx!)..<fileSuffixIdx!]
        print("image url:\(String(describing: imgUrl)), fileName:\(fileName)")
        
        let ret = SocketManager.shared.sendImage(image: photoImageView.image!, name: String(fileName))
        if (ret) {
            processingState.text = "Image Sended"
            processingState.sizeToFit()
        } else {
            processingState.text = "Send Fail! Network Error!"
            processingState.sizeToFit()
        }
    }
    
    func confirmSaveImage() {
        let alertController = UIAlertController(title: "Received Image", message: "Click 'SAVE' save to PhotoLibrary", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel) { action in
            print("click cancel save")
            self.processingState.text = "Image not saved."
            self.processingState.sizeToFit()
        }
        let okAction = UIAlertAction(title: "SAVE", style: .default) { action in
            print("click save image")
            UIImageWriteToSavedPhotosAlbum(self.photoImageView.image!, nil, nil, nil)
            self.processingState.text = "Image saved."
            self.processingState.sizeToFit()
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
    }
}

extension ViewController: SocketManagerDelegate {
    func socketConnected() {
        print("socket connected.")
        DispatchQueue.main.async { [self] in
            processingState.text = "Socket Connected!"
            processingState.sizeToFit()
        }
    }
    
    func socketDisconnect() {
        DispatchQueue.main.async { [self] in
            processingState.text = "Socket Connect Disconnected!"
            processingState.sizeToFit()
        }
    }
    
    func ImageSaved(path: String) {
        print("image saved")
        let imageData = FileManager.default.contents(atPath: path)
        if imageData != nil {
            if let image = UIImage.init(data: imageData!) {
                DispatchQueue.main.async { [self] in
                    photoImageView.image = image
                    
//                    UIImageWriteToSavedPhotosAlbum(photoImageView.image!, nil, nil, nil)
//                    processingState.text = "Image saved."
//                    processingState.sizeToFit()
                    confirmSaveImage()
                }
            }
        } else {
            print("save image fail")
            DispatchQueue.main.async { [self] in
                processingState.text = "Image fail."
                processingState.sizeToFit()
            }
        }
        
        
    }
}
