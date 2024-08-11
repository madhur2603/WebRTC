//
//  Message.swift
//  WebRTC-End
//
//  Created by iOS on 05/08/24.
//

import Foundation


enum Message {
    case sdp(SessionDescription)
    case candidate(IceCandidate)
}

extension Message: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "SessionDescription":
            self = .sdp(try container.decode(SessionDescription.self, forKey: .payload))
        case "IceCandidate":
            self = .candidate(try container.decode(IceCandidate.self, forKey: .payload))
        default:
            throw DecodeError.unknownType
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sdp(let sessionDescription):
            try container.encode("SessionDescription", forKey: .type)
            try container.encode(sessionDescription, forKey: .payload)
        case .candidate(let iceCandidate):
            try container.encode("IceCandidate", forKey: .type)
            try container.encode(iceCandidate, forKey: .payload)
        }
    }
    
    enum DecodeError: Error {
        case unknownType
    }
    
    enum CodingKeys: String, CodingKey {
        case type, payload
    }
}
