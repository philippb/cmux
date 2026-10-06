import Foundation
import Testing
@testable import CmuxSettings

@Suite("Always confirm closure preferences")
struct AlwaysConfirmClosurePreferenceTests {
    @Test func alwaysConfirmClosurePreferencesDefaultOffAndPersistIndependently() {
        let suiteName = "cmux.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let app = AppCatalogSection()
        let workspace = app.alwaysConfirmWorkspaceClose
        let window = app.alwaysConfirmWindowClose
        #expect(workspace.id == "app.alwaysConfirmWorkspaceClose")
        #expect(window.id == "app.alwaysConfirmWindowClose")
        #expect(!workspace.value(in: defaults))
        #expect(!window.value(in: defaults))

        workspace.set(true, in: defaults)
        #expect(workspace.value(in: defaults))
        #expect(!window.value(in: defaults))

        window.set(true, in: defaults)
        workspace.set(false, in: defaults)
        #expect(!workspace.value(in: defaults))
        #expect(window.value(in: defaults))
        #expect(app.warnBeforeClosingWorkspace.value(in: defaults))
        #expect(app.warnBeforeClosingWindow.value(in: defaults))
        #expect(app.confirmQuitMode.value(in: defaults) == .always)
    }

}
