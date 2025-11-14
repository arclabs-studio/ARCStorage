import Testing
@testable import ARCStorage

struct ARCStorageTests {
    @Test
    func testHelloFunction() {
        #expect(ARCStorage.hello() == "Hello from ARCStorage!")
    }
}
