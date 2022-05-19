//
//  ViewController.swift
//  JPEG Stream
//
//  Created by LumOfG0d on 5/18/22.
//

import UIKit
import AVFoundation

class PreviewView: UIView {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let previewView = PreviewView()
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    let session = AVCaptureSession()
    let output = AVCaptureVideoDataOutput()
    let sampleBufferQueue = DispatchQueue(label: "Sample Buffer queue")
    
    var isRecording = false
    var frames:[CIImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupVideo()
        session.startRunning()
    }

    func setupVideo() {
        session.beginConfiguration()
        view.addSubview(previewView)
        previewView.session = session
        previewView.frame = view.frame
        //previewView.layer.addSublayer(previewLayer)
        //previewLayer.session = session
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            print("failed to get device")
            return

        }
        var dInput:AVCaptureInput!
        do {
            dInput = try AVCaptureDeviceInput(device: device)
        }
        catch {
            print(error.localizedDescription)
        }
        session.addInput(dInput)
        
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        else {
            print("output not available")
            return
        }
        
        
        
        session.commitConfiguration()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if sampleBuffer.isValid {
            print("captured frame")
        }
        else {
            print("frame invalid")
        }
    }
}

