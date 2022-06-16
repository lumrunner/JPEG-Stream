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
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    let session = AVCaptureSession()
    let output = AVCaptureDepthDataOutput()
	let sampleBufferQueue = DispatchQueue(label: "Sample Buffer queue")
    
    var isRecording = false
    var frames:[myData] = []
	var writePath = ""
	var num = 0
	
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupVideo()
        session.startRunning()
		saveFrames()
    }

    func setupVideo() {
        session.beginConfiguration()
        view.addSubview(previewView)
        previewView.session = session
        previewView.frame = view.frame
        //previewView.layer.addSublayer(previewLayer)
        //previewLayer.session = session
		session.sessionPreset = .hd4K3840x2160
		guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .depthData, position: .unspecified) else {
            print("failed to get device")
            return
        }
		let availableFormats = device.activeFormat.supportedDepthDataFormats
		let depthFormat = availableFormats.filter { format in
			let pixelFotmatType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
			
			return pixelFotmatType == kCVPixelFormatType_DepthFloat32
		}.first
		try? device.lockForConfiguration()
		device.activeDepthDataFormat = depthFormat
		device.unlockForConfiguration()
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
		while true {
			if frames.count < 1 {
				usleep(1000)
				continue
			}
			
			let frame = frames.remove(at: 0)
			let image = CIImage(cvPixelBuffer: frame.image)

			let file = URL(fileURLWithPath: writePath + String(frame.num) + ".png")
			/*
			do {
				try UIImage(ciImage: image).pngData()?.write(to: file)

			}
			catch {
				print(error)
				print(file.deletingLastPathComponent())
				try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
				frames.append(myData(num: frame.num, image: frame.image))
			}
			 */
			
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
		let buf = depthData.depthDataMap
		var bufCpy:CVPixelBuffer?
		CVPixelBufferCreate(nil, CVPixelBufferGetWidth(buf), CVPixelBufferGetHeight(buf), CVPixelBufferGetPixelFormatType(buf), CVBufferCopyAttachments(buf, .shouldPropagate), &bufCpy)
		
		guard let pixBuf = bufCpy else {
			print("failed to copy buffer")
			return
		}
		*/
		frames.append(myData(num: num, image: depthData.depthDataMap))
		//print(frames.count)
		num += 1
	}
	
	func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {
		print("dropped frame", AVCaptureOutput.DataDroppedReason(rawValue: reason.rawValue).unsafelyUnwrapped)
	}
	
}


/*
extension UIViewController: AVCaptureVideoDataOutput {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !sampleBuffer.isValid {
            print("frame invalid")
        }
    }
}
*/
