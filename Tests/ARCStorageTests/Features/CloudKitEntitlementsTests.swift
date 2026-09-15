import Foundation
import Testing
@testable import ARCStorage

/// Oracle for these tests: the Mach-O and code-signing file formats, from which the fixtures are
/// synthesised byte by byte. Nothing here reads back a value the parser itself produced.
struct CloudKitEntitlementsTests {
    // MARK: - Entitlements present

    @Test("A signed image exposes the container identifiers in its entitlements")
    func containerIdentifiers_signedImage_returnsDeclaredContainers() {
        // Given
        let image = MachOImageBuilder
            .thin(entitlements: ["com.apple.developer.icloud-container-identifiers": ["iCloud.com.example.app"]])

        // When
        let identifiers = CloudKitEntitlements.containerIdentifiers(inMachOImage: image)

        // Then
        #expect(identifiers == ["iCloud.com.example.app"])
    }

    @Test("Several declared containers are all returned") func containerIdentifiers_multipleContainers_returnsAll() {
        // Given
        let image = MachOImageBuilder
            .thin(entitlements: ["com.apple.developer.icloud-container-identifiers": ["iCloud.a",
                                                                                      "iCloud.b"]])

        // When / Then
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: image) == ["iCloud.a", "iCloud.b"])
    }

    @Test("Entitlements unrelated to iCloud yield no containers")
    func containerIdentifiers_otherEntitlementsOnly_returnsEmpty() {
        // Given
        let image = MachOImageBuilder.thin(entitlements: ["aps-environment": "development"])

        // When / Then
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: image).isEmpty)
    }

    // MARK: - The case that was crashing

    @Test("An unsigned image — no LC_CODE_SIGNATURE — yields no containers instead of trapping")
    func containerIdentifiers_unsignedImage_returnsEmpty() {
        // Given: what `CODE_SIGNING_ALLOWED=NO` produces — a Mach-O with no signature load command.
        let image = MachOImageBuilder.thin(entitlements: nil)

        // When / Then
        #expect(CloudKitEntitlements.entitlements(inMachOImage: image) == nil)
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: image).isEmpty)
    }

    @Test("Bytes that are not Mach-O at all yield no containers") func containerIdentifiers_notMachO_returnsEmpty() {
        // Given
        let image = Data("this is not a Mach-O binary".utf8)

        // When / Then
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: image).isEmpty)
    }

    @Test("A truncated image is rejected rather than read past its end")
    func containerIdentifiers_truncatedImage_returnsEmpty() {
        // Given: a valid header whose load commands are cut off mid-way.
        let full = MachOImageBuilder
            .thin(entitlements: ["com.apple.developer.icloud-container-identifiers": ["iCloud.x"]])
        let truncated = full.prefix(40)

        // When / Then
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: Data(truncated)).isEmpty)
    }

    // MARK: - Fat binaries

    @Test("A fat image is read through to the slice carrying the entitlements")
    func containerIdentifiers_fatImage_readsSlice() {
        // Given
        let slice = MachOImageBuilder
            .thin(entitlements: ["com.apple.developer.icloud-container-identifiers": ["iCloud.com.example.fat"]])
        let image = MachOImageBuilder.fat(slices: [slice])

        // When / Then
        #expect(CloudKitEntitlements.containerIdentifiers(inMachOImage: image) == ["iCloud.com.example.fat"])
    }
}

// MARK: - Fixture builder

/// Synthesises the minimum Mach-O structure the parser walks: a 64-bit header, an optional
/// `LC_CODE_SIGNATURE` pointing at a `CS_SuperBlob`, and an embedded-entitlements blob.
private enum MachOImageBuilder {
    static func thin(entitlements: [String: Any]?) -> Data {
        var loadCommands = Data()
        var signature = Data()

        if let entitlements {
            let plist = (try? PropertyListSerialization.data(fromPropertyList: entitlements,
                                                             format: .xml,
                                                             options: 0)) ?? Data()
            signature = superBlob(entitlementsPlist: plist)
        }

        let headerSize = 32
        let commandSize = 16 // linkedit_data_command
        let signatureOffset = headerSize + (entitlements == nil ? 0 : commandSize)

        if entitlements != nil {
            loadCommands.appendLittleEndian(UInt32(0x1D)) // LC_CODE_SIGNATURE
            loadCommands.appendLittleEndian(UInt32(commandSize))
            loadCommands.appendLittleEndian(UInt32(signatureOffset)) // dataoff
            loadCommands.appendLittleEndian(UInt32(signature.count)) // datasize
        }

        var image = Data()
        image.appendLittleEndian(UInt32(0xFEED_FACF)) // MH_MAGIC_64
        image.appendLittleEndian(UInt32(0x0100_000C)) // cputype arm64
        image.appendLittleEndian(UInt32(0)) // cpusubtype
        image.appendLittleEndian(UInt32(2)) // filetype MH_EXECUTE
        image.appendLittleEndian(UInt32(entitlements == nil ? 0 : 1)) // ncmds
        image.appendLittleEndian(UInt32(loadCommands.count)) // sizeofcmds
        image.appendLittleEndian(UInt32(0)) // flags
        image.appendLittleEndian(UInt32(0)) // reserved
        image.append(loadCommands)
        image.append(signature)
        return image
    }

    static func fat(slices: [Data]) -> Data {
        let headerSize = 8 + slices.count * 20
        var header = Data()
        header.appendBigEndian(UInt32(0xCAFE_BABE)) // FAT_MAGIC
        header.appendBigEndian(UInt32(slices.count))

        var offset = headerSize
        var body = Data()
        for slice in slices {
            header.appendBigEndian(UInt32(0x0100_000C)) // cputype
            header.appendBigEndian(UInt32(0)) // cpusubtype
            header.appendBigEndian(UInt32(offset)) // offset
            header.appendBigEndian(UInt32(slice.count)) // size
            header.appendBigEndian(UInt32(14)) // align
            body.append(slice)
            offset += slice.count
        }
        return header + body
    }

    /// A `CS_SuperBlob` holding a single embedded-entitlements blob.
    private static func superBlob(entitlementsPlist plist: Data) -> Data {
        var entitlementsBlob = Data()
        entitlementsBlob.appendBigEndian(UInt32(0xFADE_7171)) // CSMAGIC_EMBEDDED_ENTITLEMENTS
        entitlementsBlob.appendBigEndian(UInt32(8 + plist.count))
        entitlementsBlob.append(plist)

        let superBlobHeaderSize = 12 + 8 // header + one index entry
        var blob = Data()
        blob.appendBigEndian(UInt32(0xFADE_0CC0)) // CSMAGIC_EMBEDDED_SIGNATURE
        blob.appendBigEndian(UInt32(superBlobHeaderSize + entitlementsBlob.count))
        blob.appendBigEndian(UInt32(1)) // blob count
        blob.appendBigEndian(UInt32(5)) // slot type: entitlements
        blob.appendBigEndian(UInt32(superBlobHeaderSize)) // offset from superblob start
        blob.append(entitlementsBlob)
        return blob
    }
}

extension Data {
    fileprivate mutating func appendLittleEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    fileprivate mutating func appendBigEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
