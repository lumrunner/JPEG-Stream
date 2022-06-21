//
//  ViewController.swift
//  JPEG Stream
//
//  Created by LumOfG0d on 5/18/22.
//

import UIKit
import AVFoundation
import System
import CoreVideo
import Accelerate

struct myData {
	var num: Int!
	var image: CVPixelBuffer!
}

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

class ViewController: UIViewController, AVCaptureDepthDataOutputDelegate {
    
    let previewView = PreviewView()
	let recordButton = UIButton()
    //let previewLayer = AVCaptureVideoPreviewLayer()
    
    let session = AVCaptureSession()
    let output = AVCaptureDepthDataOutput()
	let sampleBufferQueue = DispatchQueue(label: "Sample Buffer queue")
	let frameQueue = DispatchQueue(label: "Frame saving queue")
    
    var isRecording = false
    var frames:[myData] = []
	var writePath = ""
	var num = 0
	var isRecrding = true
	let offset = 20
	let size = 50
  
    override func viewDidLoad() {
        super.viewDidLoad()

		setupButton()
        setupVideo()

		view.addSubview(previewView)
		view.addSubview(recordButton)
		
        session.startRunning()
    }

	func setupButton() {
		// adds listener for button clicks
		recordButton.addTarget(self, action: #selector(toggleRecord), for: .touchUpInside)
		
		// general ui setup
		recordButton.frame = CGRect(x: Int(view.frame.width) / 2 - size / 2, y: Int(view.frame.height) - size - offset, width: size, height: size)
		recordButton.backgroundColor = .red
		recordButton.layer.cornerRadius = CGFloat(size / 2)
		recordButton.setTitle("", for: .normal)
		recordButton.setTitle("", for: .highlighted)
		recordButton.setTitle("", for: .selected)
		recordButton.isHidden = false
	}
	
	@objc func toggleRecord(_ sender: Any) {
		if isRecording {
			isRecording = false
			recordButton.layer.cornerRadius = CGFloat(size / 2)
		}
		else {
			isRecording = true
			recordButton.layer.cornerRadius = 0
			frameQueue.async {
				self.saveFrames()
			}
		}
	}
	
    func setupVideo() {
		
        session.beginConfiguration()
        previewView.session = session
        previewView.frame = view.frame
		session.sessionPreset = .inputPriority
		
		guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            print("failed to get device")
            return
        }
		
		// Find a match that outputs video data in the format the app's custom Metal views require.
		guard let format = (device.formats.last { format in
			format.formatDescription.dimensions.width == 1920 &&
			format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
			!format.isVideoBinned &&
			!format.supportedDepthDataFormats.isEmpty
		}) else {
			return
		}
		
		// Find a match that outputs depth data in the format the app's custom Metal views require.
		guard let depthFormat = (format.supportedDepthDataFormats.last { depthFormat in
			depthFormat.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_DepthFloat32
		}) else {
			return
		}

		try? device.lockForConfiguration()
		device.activeFormat = format
		device.activeDepthDataFormat = depthFormat
		device.unlockForConfiguration()
		
		print("Selected video format: \(device.activeFormat)")
		print("Selected depth format: \(String(describing: device.activeDepthDataFormat))")
		
        do {
			let dInput = try AVCaptureDeviceInput(device: device)
			session.addInput(dInput)
        }
        catch {
            print(error.localizedDescription)
        }
		
		output.alwaysDiscardsLateDepthData = true
		output.setDelegate(self, callbackQueue: sampleBufferQueue)
        
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        else {
            print("output not available")
            return
        }

        session.commitConfiguration()
		
		var count = 0
		let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/captures/"
		while true {
			if !FileManager.default.fileExists(atPath: path + String(count)) {
				writePath = path + String(count) + "/"
				break
			}
			count += 1
		}
		try? FileManager.default.createDirectory(at: URL(fileURLWithPath: writePath, isDirectory: true), withIntermediateDirectories: true)
	}
	
	func saveFrames() {
		while isRecording || frames.count > 0 {
			if frames.count < 1 {
				usleep(1000)
				continue
			}
			
			let frame = frames.remove(at: 0)
			let image = CIImage(cvPixelBuffer: frame.image)

			let file = URL(fileURLWithPath: writePath + String(frame.num) + ".tiff")
			
			guard let colorSpace = image.colorSpace else {
				print("could not get image color space")
				return
			}
			//let type = CVPixelBufferGetPixelFormatType(frame.image)
			let context = CIContext()
			do {
				try context.writeTIFFRepresentation(of: image, to: file, format: .Lf, colorSpace: colorSpace, options: [:])
			}
			catch {
				print(error)
				frames.append(myData(num: frame.num, image: frame.image))
				try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
			}
			
		}
	}
	
	func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
		if depthData.depthDataQuality.rawValue == 0 {
			print("low quality depth")
			return
		}
		/*
		// this might reduce errors in future
		let buf = depthData.depthDataMap
		var bufCpy:CVPixelBuffer?
		CVPixelBufferCreate(nil, CVPixelBufferGetWidth(buf), CVPixelBufferGetHeight(buf), CVPixelBufferGetPixelFormatType(buf), CVBufferCopyAttachments(buf, .shouldPropagate), &bufCpy)
		
		guard let pixBuf = bufCpy else {
			print("failed to copy buffer")
			return
		}
		*/
		
		if isRecording {
			frames.append(myData(num: num, image: depthData.depthDataMap))
			num += 1
		}
		
		//print(frames.count)
	}
	
	func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {
		if isRecording {
			print("dropped frame", AVCaptureOutput.DataDroppedReason(rawValue: reason.rawValue).unsafelyUnwrapped)
		}
	}
	
}
