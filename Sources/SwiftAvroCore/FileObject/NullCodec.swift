//
//  AvroClient/NullCodec.swift
//
//  Created by Yang Liu on 22/09/18.
//  Copyright © 2018 柳洋 and the project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

protocol CodecProtocol {
    /// <summary>
    /// Codec types
    /// </summary>
    //var codec: String {get}
    /// <summary>
    /// Compress data using implemented codec
    /// </summary>
    /// <param name="uncompressedData"></param>
    /// <returns></returns>
    func compress(data: Data) throws -> Data
    
    /// <summary>
    /// Decompress data using implemented codec
    /// </summary>
    /// <param name="compressedData"></param>
    /// <returns></returns>
    func decompress(data: Data) throws -> Data
    
    /// <summary>
    /// Name of this codec type
    /// </summary>
    /// <returns></returns>
    func getName() -> String
}

struct NullCodec: CodecProtocol {
    var codec: String

    func compress(data: Data) throws -> Data {
        return data
    }
    
    func decompress(data: Data) throws -> Data {
        return data
    }
    
    func getName() -> String {
        return codec
    }
    
    init(codecName: String) {
        self.codec = codecName
    }
}

struct Codec: CodecProtocol {
    var codec: CodecProtocol
    init(codec: CodecProtocol) {
        self.codec = codec
    }
    
    init() {
        self.codec = NullCodec(codecName: AvroReservedConstants.NullCodec)
    }
    
    func compress(data: Data) throws -> Data {
        return try self.codec.compress(data: data)
    }
    
    func decompress(data: Data) throws -> Data {
        return try self.codec.decompress(data: data)
    }
    
    func getName() -> String {
        return codec.getName()
    }
}
