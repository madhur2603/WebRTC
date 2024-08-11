import Foundation
import SocketIO
import WebRTC

protocol SocketProviderDelegate: AnyObject {
    func socketDidConnect(_ socket: SocketProvider)
    func socketDidDisconnect(_ socket: SocketProvider)
    func socket(_ socket: SocketProvider, didReceiveData data: Data)
    func socket(_ socket: SocketProvider, didEncounterError error: Error)
    func socketCandidate(candidate rtcIceCandidate: RTCIceCandidate)
    func socketSdp(sdp rtcSdp: RTCSessionDescription)
}

protocol SocketProvider: AnyObject {
    var delegate: SocketProviderDelegate? { get set }
    func connect()
    func disconnect()
    func send(data: Data)
}

class SocketIOProvider: SocketProvider {
    
    private let manager: SocketManager
    private var socket: SocketIOClient
    weak var delegate: SocketProviderDelegate?
    private var roomName: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init(url: URL, roomName: String) {
        self.manager = SocketManager(socketURL: url, config: [.log(true), .compress])
        self.socket = manager.defaultSocket
        self.roomName = roomName
        setupHandlers()
    }
    
    private func setupHandlers() {
        self.socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            print("Socket connected")
            self.joinRoom()
            self.delegate?.socketDidConnect(self)
        }
        
        self.socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            self.delegate?.socketDidDisconnect(self)
        }
        
        self.socket.on("message") { [weak self] data, ack in
            self?.handleEvent(data: data)
        }
        
        self.socket.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            if let error = data.first as? Error {
                self.delegate?.socket(self, didEncounterError: error)
            }
        }
    }
    
    private func handleEvent(data: [Any]) {
         guard let data = data.first as? String,
               let dataObject = data.data(using: .utf8) else { return }
         self.delegate?.socket(self, didReceiveData: dataObject)
     }
         
    func connect() {
        self.socket.connect()
    }
    
    func disconnect() {
        self.socket.disconnect()
    }
    
    func sendCandidate(candidate rtcIceCandidate: RTCIceCandidate){
        let message = Message.candidate(IceCandidate(from: rtcIceCandidate))
        do {
            let dataMessage = try self.encoder.encode(message)
            self.send(data: dataMessage)
        } catch {
            debugPrint("Warning: Could not encode candidate: \(error)")
        }
    }
    
    func sendSdp(sdp rtcSdp: RTCSessionDescription){
        let message = Message.sdp(SessionDescription(from: rtcSdp))
        do {
            let dataMessage = try self.encoder.encode(message)
            self.send(data: dataMessage)
        } catch {
            debugPrint("Warning: Could not encode sdp: \(error)")
        }
    }
    
    func send(data: Data) {
        if self.socket.status == .connected {
            if let jsonString = String(data: data, encoding: .utf8) {
                self.socket.emit("message", jsonString)
            } else {
                debugPrint("Warning: Failed to convert data to JSON string")
            }
        } else {
            debugPrint("Warning: Tried emitting when not connected")
        }
    }
    
    private func joinRoom() {
        self.socket.emit("joinRoom", self.roomName)
    }
}

extension SocketIOProvider: SocketProviderDelegate {
    
    func socket(_ socket: SocketProvider, didEncounterError error: Error) {
        self.delegate?.socket(self, didEncounterError: error)
    }
    
    func socketCandidate(candidate rtcIceCandidate: RTCIceCandidate) {
        self.delegate?.socketCandidate(candidate: rtcIceCandidate)
    }
    
    func socketSdp(sdp rtcSdp: RTCSessionDescription) {
        self.delegate?.socketSdp(sdp: rtcSdp)
    }
    
    func socketDidConnect(_ socket: SocketProvider) {
           self.delegate?.socketDidConnect(self)
       }
    func socketDidDisconnect(_ socket: SocketProvider) {
        self.delegate?.socketDidDisconnect(self)
        
        // try to reconnect every two seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            debugPrint("Trying to reconnect to signaling server...")
            self.socket.connect()
        }
    }
    
    func socket(_ socket: SocketProvider, didReceiveData data: Data) {
        let message: Message
        do {
            message = try self.decoder.decode(Message.self, from: data)
        } catch {
            debugPrint("Warning: Could not decode incoming message: \(error)")
            return
        }
        
        switch message {
        case .candidate(let iceCandidate):
            self.delegate?.socketCandidate(candidate: iceCandidate.rtcIceCandidate)
        case .sdp(let sessionDescription):
            self.delegate?.socketSdp(sdp: sessionDescription.rtcSessionDescription)
        }
    }
    
}
