import Testing
@testable import Parlance

@MainActor
@Suite("RealLifeSetupViewModel")
struct RealLifeSetupViewModelTests {

    @Test("attemptStart returns false and sets failure for invalid scenario")
    func attemptStart_invalid_setsFailure() {
        let vm = RealLifeSetupViewModel()
        vm.onScenarioChange("the weather is nice today and the sun is shining")
        #expect(vm.attemptStart() == false)
        #expect(vm.validationFailure == .noSpeechActOrAudience)
    }

    @Test("attemptStart returns true and clears failure for valid scenario")
    func attemptStart_valid_clearsFailure() {
        let vm = RealLifeSetupViewModel()
        vm.onScenarioChange("I need to tell my manager I'm taking leave next week")
        #expect(vm.attemptStart() == true)
        #expect(vm.validationFailure == nil)
    }

    @Test("editing the field clears a previously-set failure")
    func editing_clearsFailure() {
        let vm = RealLifeSetupViewModel()
        vm.onScenarioChange("the weather is nice today and the sun is shining")
        _ = vm.attemptStart()
        #expect(vm.validationFailure != nil)
        vm.onScenarioChange("I need to tell my manager about leave")
        #expect(vm.validationFailure == nil)
    }

    @Test("attemptStart short input reports tooShort")
    func attemptStart_short_tooShort() {
        let vm = RealLifeSetupViewModel()
        vm.onScenarioChange("hi")
        #expect(vm.attemptStart() == false)
        #expect(vm.validationFailure == .tooShort)
    }

    @Test("init prefill seeds scenario text")
    func initPrefill_seedsText() {
        let vm = RealLifeSetupViewModel(prefillScenario: "asking my landlord about rent")
        #expect(vm.scenarioText == "asking my landlord about rent")
    }
}
