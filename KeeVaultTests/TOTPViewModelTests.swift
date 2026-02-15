import XCTest
@testable import KeeVault

@MainActor
final class TOTPViewModelTests: XCTestCase {
    func testInitComputesInitialCodeAndTimingValues() {
        let vm = TOTPViewModel(config: TOTPConfig(secret: "JBSWY3DPEHPK3PXP", period: 30, digits: 6, algorithm: .sha1))

        XCTAssertEqual(vm.period, 30)
        XCTAssertNotEqual(vm.code, "------")
        XCTAssertTrue((1...30).contains(vm.secondsRemaining))
        XCTAssertTrue((0...1).contains(vm.progress))
    }

    func testStartAndStopCanBeCalledRepeatedly() {
        let vm = TOTPViewModel(config: TOTPConfig(secret: "JBSWY3DPEHPK3PXP"))

        vm.start()
        vm.stop()
        vm.stop()
        vm.start()

        XCTAssertNotEqual(vm.code, "------")
        XCTAssertTrue((1...vm.period).contains(vm.secondsRemaining))

        vm.stop()
    }
}
