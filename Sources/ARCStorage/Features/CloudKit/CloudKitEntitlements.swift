//
//  CloudKitEntitlements.swift
//  ARCStorage
//

import Foundation

/// Reads the iCloud container identifiers the **running process** actually carries.
///
/// `CKContainer(identifier:)` is not a throwing initialiser: when the process lacks a matching
/// `com.apple.developer.icloud-container-identifiers` entitlement, CloudKit traps
/// (`EXC_BREAKPOINT`) before any error can be caught. So the entitlement has to be checked
/// *before* the container is constructed, and the only way to do that with public API is to read
/// the entitlements blob out of the executable's own code signature.
///
/// A binary built with `CODE_SIGNING_ALLOWED=NO` carries no `LC_CODE_SIGNATURE` at all, which is
/// exactly the case this guards: the app launches local-only instead of trapping at startup.
///
/// Signed builds are unaffected — their entitlements list the container and the check passes.
enum CloudKitEntitlements {
    /// Whether the process is entitled to use the given CloudKit container.
    ///
    /// - Parameter identifier: The container identifier, e.g. `"iCloud.com.example.app"`.
    /// - Returns: `true` when the executable's entitlements list the container.
    static func declaresContainer(_ identifier: String) -> Bool {
        processContainerIdentifiers.contains(identifier)
    }

    /// The iCloud container identifiers in the main executable's entitlements.
    ///
    /// Parsed once: the executable is memory-mapped and only its load commands and signature
    /// blobs are touched, but there is no reason to repeat that on every container creation.
    static var processContainerIdentifiers: [String] {
        cachedProcessContainerIdentifiers
    }

    // MARK: - Parsing

    /// Extracts the iCloud container identifiers from a Mach-O image's embedded entitlements.
    ///
    /// Exposed for testing with synthesised images; production callers use
    /// ``processContainerIdentifiers``.
    ///
    /// - Parameter image: The bytes of a Mach-O executable (thin or fat).
    /// - Returns: The declared container identifiers, empty when the image is unsigned, carries no
    ///   entitlements blob, or declares none.
    static func containerIdentifiers(inMachOImage image: Data) -> [String] {
        guard let entitlements = entitlements(inMachOImage: image),
              let identifiers = entitlements[containerIdentifiersKey] as? [String] else {
            return []
        }
        return identifiers
    }

    /// Extracts the entitlements dictionary from a Mach-O image's code signature.
    ///
    /// - Parameter image: The bytes of a Mach-O executable (thin or fat).
    /// - Returns: The entitlements, or `nil` when the image is unsigned or carries no
    ///   entitlements blob.
    static func entitlements(inMachOImage image: Data) -> [String: Any]? {
        for sliceOffset in sliceOffsets(in: image) {
            guard let signature = codeSignatureRange(in: image, sliceOffset: sliceOffset),
                  let plist = entitlementsPlist(in: image, signatureOffset: signature) else {
                continue
            }
            return plist
        }
        return nil
    }
}

// MARK: - Mach-O layout

extension CloudKitEntitlements {
    /// Mach-O and code-signing constants, spelled out rather than imported: `MachO` does not vend
    /// the code-signing blob magics, and these four values are stable file-format constants.
    fileprivate static var machHeader64Magic: UInt32 {
        0xFEED_FACF
    }

    fileprivate static var fatMagic: UInt32 {
        0xCAFE_BABE
    } // big-endian on disk
    fileprivate static var loadCommandCodeSignature: UInt32 {
        0x1D
    }

    fileprivate static var embeddedSignatureMagic: UInt32 {
        0xFADE_0CC0
    }

    fileprivate static var embeddedEntitlementsMagic: UInt32 {
        0xFADE_7171
    }

    fileprivate static var containerIdentifiersKey: String {
        "com.apple.developer.icloud-container-identifiers"
    }

    /// The offsets of the 64-bit Mach-O slices in the image: one for a thin binary, several for fat.
    fileprivate static func sliceOffsets(in image: Data) -> [Int] {
        guard let magic: UInt32 = image.integer(at: 0, bigEndian: false) else { return [] }
        if magic == machHeader64Magic {
            return [0]
        }

        guard magic.byteSwapped == fatMagic || magic == fatMagic,
              let architectureCount: UInt32 = image.integer(at: 4, bigEndian: true) else {
            return []
        }
        // fat_arch: cputype, cpusubtype, offset, size, align — 4 × UInt32 plus align.
        let architectureSize = 20
        return (0 ..< Int(architectureCount)).compactMap { index in
            let base = 8 + index * architectureSize
            guard let offset: UInt32 = image.integer(at: base + 8, bigEndian: true),
                  let sliceMagic: UInt32 = image.integer(at: Int(offset), bigEndian: false),
                  sliceMagic == machHeader64Magic else {
                return nil
            }
            return Int(offset)
        }
    }

    /// The file offset of the slice's `LC_CODE_SIGNATURE` payload, if it has one.
    fileprivate static func codeSignatureRange(in image: Data, sliceOffset: Int) -> Int? {
        // mach_header_64: magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved.
        guard let commandCount: UInt32 = image.integer(at: sliceOffset + 16, bigEndian: false) else {
            return nil
        }
        var cursor = sliceOffset + 32
        for _ in 0 ..< commandCount {
            guard let command: UInt32 = image.integer(at: cursor, bigEndian: false),
                  let commandSize: UInt32 = image.integer(at: cursor + 4, bigEndian: false),
                  commandSize >= 8 else {
                return nil
            }
            if command == loadCommandCodeSignature {
                guard let dataOffset: UInt32 = image.integer(at: cursor + 8, bigEndian: false) else {
                    return nil
                }
                return sliceOffset + Int(dataOffset)
            }
            cursor += Int(commandSize)
        }
        return nil
    }

    /// The entitlements plist inside a `CS_SuperBlob`, if one of its blobs carries entitlements.
    fileprivate static func entitlementsPlist(in image: Data, signatureOffset: Int) -> [String: Any]? {
        guard let magic: UInt32 = image.integer(at: signatureOffset, bigEndian: true),
              magic == embeddedSignatureMagic,
              let blobCount: UInt32 = image.integer(at: signatureOffset + 12, bigEndian: true) else {
            return nil
        }
        // CS_BlobIndex: type, offset — both big-endian, following the 12-byte SuperBlob header.
        for index in 0 ..< Int(blobCount) {
            let indexOffset = signatureOffset + 12 + index * 8
            guard let blobOffset: UInt32 = image.integer(at: indexOffset + 4, bigEndian: true) else {
                continue
            }
            let blobStart = signatureOffset + Int(blobOffset)
            guard let blobMagic: UInt32 = image.integer(at: blobStart, bigEndian: true),
                  blobMagic == embeddedEntitlementsMagic,
                  let blobLength: UInt32 = image.integer(at: blobStart + 4, bigEndian: true),
                  blobLength > 8 else {
                continue
            }
            let payloadStart = blobStart + 8
            let payloadEnd = blobStart + Int(blobLength)
            guard payloadEnd <= image.count else { continue }
            let payload = image.subdata(in: payloadStart ..< payloadEnd)
            let plist = try? PropertyListSerialization.propertyList(from: payload, format: nil)
            if let plist = plist as? [String: Any] {
                return plist
            }
        }
        return nil
    }
}

// MARK: - Process entitlements

/// The main executable's iCloud container identifiers, read once on first use.
///
/// A global `let` rather than a stored static so the mapping and parsing happen lazily and exactly
/// once, without any mutable shared state to isolate.
private let cachedProcessContainerIdentifiers: [String] = {
    guard let executable = Bundle.main.executableURL,
          // Mapped, not read: a Debug executable can be hundreds of megabytes and only its load
          // commands and signature blobs are ever touched.
          let image = try? Data(contentsOf: executable, options: .mappedIfSafe) else {
        return []
    }
    return CloudKitEntitlements.containerIdentifiers(inMachOImage: image)
}()

// MARK: - Data reading

extension Data {
    /// Reads a fixed-width integer at a byte offset, returning `nil` rather than trapping when the
    /// offset runs past the end of the data.
    fileprivate func integer<T: FixedWidthInteger>(at offset: Int, bigEndian: Bool) -> T? {
        let size = MemoryLayout<T>.size
        guard offset >= 0, offset + size <= count else { return nil }
        let start = index(startIndex, offsetBy: offset)
        let value = subdata(in: start ..< index(start, offsetBy: size))
            .withUnsafeBytes { $0.loadUnaligned(as: T.self) }
        return bigEndian ? T(bigEndian: value) : T(littleEndian: value)
    }
}
