//
//  Response.swift
//  SwiftAvroCore
//
//  Created by Yang.Liu on 24/02/22.
//

import Foundation

class MessageResponse {
    let avro: Avro
    let context: Context
    var sessionCache: [[uint8]: AvroSchema]
    var serverResponse: HandshakeResponse

    public init(context:Context, serverHash: [uint8], serverProtocol: String) throws {
        self.avro = Avro()
        self.context = context
        self.avro.setSchema(schema: context.responseSchema)
        self.sessionCache = [[uint8]:AvroSchema]()
        self.serverResponse = HandshakeResponse(match: HandshakeMatch.NONE,serverProtocol: serverProtocol, serverHash: serverHash, meta: context.handshakeResponeMeta)
    }
    
    func encodeHandshakeResponse(response: HandshakeResponse) throws -> Data {
        return try avro.encode(response)
    }
    public func addSupportPotocol(protocolString: String, hash: [uint8]) throws {
        sessionCache[hash] = avro.newSchema(schema:protocolString)
    }
    
    /*
     avro handshake
     client --->
     HandshakeRequest protocl schema in json| clientHash|null client protocol| serverHash (same as clientHash)
     server <----
     HandshakeResponse protocl schema in json:
      * match=BOTH, serverProtocol=null, serverHash=null if the client sent the valid hash of the server's protocol and the server knows what protocol corresponds to the client's hash. In this case, the request is complete and the response data immediately follows the HandshakeResponse.
      * match=CLIENT, serverProtocol!=null, serverHash!=null if the server has previously seen the client's protocol, but the client sent an incorrect hash of the server's protocol. The request is complete and the response data immediately follows the HandshakeResponse. The client must use the returned protocol to process the response and should also cache that protocol and its hash for future interactions with this server.
      * match=NONE if the server has not previously seen the client's protocol. The serverHash and serverProtocol may also be non-null if the server's protocol hash was incorrect.
     In this case the client must then re-submit its request with its protocol text (clientHash!=null, clientProtocol!=null, serverHash!=null) and the server should respond with a successful match (match=BOTH, serverProtocol=null, serverHash=null) as above.
    */
    public func resolveHandshakeRequest(requestData: Data) throws -> Data {
        let request = try avro.decodeFrom(from:requestData, schema: context.requestSchema) as HandshakeRequest
        if request.clientHash.count != 16 {
            throw AvroHandshakeError.noClientHash
        }
        if let _ = sessionCache[request.clientHash] {
            if request.serverHash != serverResponse.serverHash {
                return try encodeHandshakeResponse(response: HandshakeResponse(match: HandshakeMatch.CLIENT, serverProtocol: serverResponse.serverProtocol, serverHash: serverResponse.serverHash))
            }
            return try encodeHandshakeResponse(response: HandshakeResponse(match: HandshakeMatch.BOTH, serverProtocol: nil, serverHash: nil))
        }
        if let clientProtocol = request.clientProtocol,request.serverHash == serverResponse.serverHash {
            sessionCache[request.clientHash] = avro.newSchema(schema: clientProtocol)
            return try encodeHandshakeResponse(response: HandshakeResponse(match: HandshakeMatch.BOTH, serverProtocol: nil, serverHash: nil))
        }
        // client use this response to retrieve the supported protocol from server
        return try encodeHandshakeResponse(response: HandshakeResponse(match: HandshakeMatch.NONE, serverProtocol: serverResponse.serverProtocol, serverHash: serverResponse.serverHash))
    }
    
    public func outdateSession(header: HandshakeRequest) {
        sessionCache.removeValue(forKey: header.clientHash)
    }
    
    public func clearSession() {
        sessionCache.removeAll()
    }
    
    /*
     The format of a call response is:
     * response metadata, a map with values of type bytes
     * a one-byte error flag boolean, followed by either:
     ** if the error flag is false, the message response, serialized per the message's response schema.
     ** if the error flag is true, the error, serialized per the message's effective error union schema.
    */
    public func writeResponse<T:Codable>(header: HandshakeRequest, requestMessageName: String, parameter: T) throws -> Data {
        var data = Data()
        let d = try? avro.encodeFrom(context.responseSchema, schema: context.metaSchema)
        data.append(d!)
        if let serverProtocol = sessionCache[header.serverHash],
           let messages = serverProtocol.getProtocol()?.messages,
           let messageSchema = messages[requestMessageName],
           let response = messageSchema.response {
                /*let flag = try? avro.encodeFrom(false, schema: AvroSchema.init(type: "boolean"))
                data.append(flag!)*/
                let d = try? avro.encodeFrom(parameter, schema: response)
                data.append(d!)
        }
        return data
    }
    
    public func writeErrorResponse<T:Codable>(header: HandshakeRequest, requestMessageName: String, errorId: Int,errorValue: T) throws -> Data {
        var data = Data()
        let d = try? avro.encodeFrom(context.responseSchema, schema: context.metaSchema)
        data.append(d!)
        /*if let serverProtocol = sessionCache[header.serverHash],
           let messages = serverProtocol.getProtocol()?.messages,
           let messageSchema = messages[requestMessageName],
           let errors = messageSchema.errors {
                guard errorId < errors.count else {
                    throw AvroMessageError.errorIdOutofRangeError
                }
                let flag = try? avro.encodeFrom(true, schema: AvroSchema.init(type: "boolean"))
                data.append(flag!)
                let d = try? avro.encodeFrom(errorValue, schema: errors[errorId])
                data.append(d!)
        }*/
        return data
    }
    
    public func readResponse<T:Codable>(header: HandshakeRequest, requestMessageName: String, from: Data)throws -> ([String: [UInt8]]?, Bool, [T]) {
        let metaSchema = avro.decodeSchema(schema: MessageConstant.metadataSchema)!
        let (meta, nameIndex) = try! avro.decodeFromContinue(from: from, schema: metaSchema) as ([String: [UInt8]]?,Int)
        let (flag, paramIndex) = try! avro.decodeFromContinue(from: from.advanced(by: nameIndex), schema: AvroSchema.init(type: "boolean")) as (Bool,Int)
        var param = [T]()
        /*if flag {
            if let serverProtocol = sessionCache[header.serverHash],
               let messages = serverProtocol.getProtocol()?.messages,
               let messageSchema = messages[requestMessageName] {
                var index = paramIndex
                for e in messageSchema.errors! {
                    let (p, nextIndex) = try! avro.decodeFromContinue(from: from.advanced(by: index), schema: e) as (T,Int)
                    param.append(p)
                    index = nextIndex
                }
            }
            return (meta, flag, param)
        }
        if let serverProtocol = sessionCache[header.serverHash],
           let messages = serverProtocol.getProtocol()?.messages,
           let messageSchema = messages[requestMessageName] {
            if let r = messageSchema.response {
                let p = try! avro.decodeFrom(from: from.advanced(by: paramIndex), schema: r) as T
                param.append(p)
            }
        }*/
        return (meta, flag, param)
    }
}
