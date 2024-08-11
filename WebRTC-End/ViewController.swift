//
//  ViewController.swift
//  WebRTC-End
//
//  Created by iOS on 05/08/24.
//

import UIKit
import WebRTC
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var ServerStatus: UITextView!
    @IBOutlet weak var webRtcstatus: UITextView!
    @IBOutlet weak var requestBtn: UIButton!
    @IBOutlet weak var acceptBtn: UIButton!
    
    private var signalClient: SocketIOProvider?
    private var webRTCClient: WebRTCClient?
    private var config = Config.default
    
    private var signalingConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.ServerStatus?.text = self.signalingConnected ? "Connected" : "Not connected"
                self.ServerStatus?.textColor = self.signalingConnected ? .green : .red
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.signalingConnected = false
        self.webRtcstatus?.text = "New"
        
        let socketURL = URL(string: "http://192.168.0.105:8080")!
        let socketProvider = SocketIOProvider(url: socketURL, roomName: "Madhu")
        self.signalClient = socketProvider
        self.signalClient?.delegate = self
        
        self.webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        self.webRTCClient?.delegate = self
        
        self.signalClient?.connect()
    }
    
    @IBAction func Request(_ sender: Any) {
        self.webRTCClient?.offer { (sdp) in
            print("offer sent: \(sdp) ")
            self.signalClient?.sendSdp(sdp: sdp)
            DispatchQueue.main.async {
                self.acceptBtn.isHidden = true
            }
        }
    }
    
    @IBAction func Accept(_ sender: Any) {
        self.webRTCClient?.answer { (localSdp) in
            print("answer sent: \(localSdp) ")
            self.signalClient?.sendSdp(sdp: localSdp)
            DispatchQueue.main.async {
                self.requestBtn.isHidden = true
            }
        }
    }
}

extension ViewController: WebRTCClientDelegate, SocketProviderDelegate {
    
    func socket(_ socket: SocketProvider, didReceiveData data: Data) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            switch message {
            case .candidate(let iceCandidate):
                self.webRTCClient?.set(remoteCandidate: iceCandidate.rtcIceCandidate, completion: { error in
                    print("Received remote candidate")
                })
            case .sdp(let sessionDescription):
                self.webRTCClient?.set(remoteSdp: sessionDescription.rtcSessionDescription, completion: { error in
                    print("Received remote sdp")
                })
            }
        } catch {
            print("Warning: Could not decode incoming message: \(error)")
        }
    }
    
    func socket(_ socket: any SocketProvider, didEncounterError error: any Error) {
        print("Socket encountered error: \(error)")
    }
    
    func socketCandidate(candidate rtcIceCandidate: RTCIceCandidate) {
        self.webRTCClient?.set(remoteCandidate: rtcIceCandidate, completion: { error in
            print("Received remote candidate")
        })
    }
    
    func socketSdp(sdp rtcSdp: RTCSessionDescription) {
        self.webRTCClient?.set(remoteSdp: rtcSdp, completion: { error in
            print("Received remote sdp")
            self.requestBtn.isHidden = true
        })
    }
    
    
    func socketDidConnect(_ socket: SocketProvider) {
        self.signalingConnected = true
    }
    
    func socketDidDisconnect(_ socket: SocketProvider) {
        self.signalingConnected = false
    }
    
    
    // WebRTC
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("Discovered local candidate")
        self.signalClient?.sendCandidate(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        let textColor: UIColor
        switch state {
        case .connected, .completed:
            textColor = .green
        case .disconnected:
            textColor = .orange
        case .failed, .closed:
            textColor = .red
        case .new, .checking, .count:
            textColor = .black
        @unknown default:
            textColor = .black
        }
        DispatchQueue.main.async {
            self.webRtcstatus?.text = state.description.capitalized
            self.webRtcstatus?.textColor = textColor
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        DispatchQueue.main.async {
            let message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
            let alert = UIAlertController(title: "Message from WebRTC", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
