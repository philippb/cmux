import CoreGraphics
import Testing
@testable import CmuxNextSidebar

/// `sidebar.nestedTabs` and `sidebar.showCounts`: a workspace row can show
/// how many tabs it has, and a disclosure on it lists its tabs inline.
@Suite struct SidebarNestedTabsTests {
    private func sections() -> [SidebarSection] {
        var sections = fixture()
        sections[1].nodes[0] = .workspace(SidebarWorkspace(
            id: id("a"), title: "a",
            tabs: [SidebarTab(id: TabID("t1"), title: "Terminal"),
                   SidebarTab(id: TabID("t2"), title: "Chat", kind: .agentChat)]
        ))
        sections[1].nodes[1] = .group(SidebarGroup(id: g1, name: "G1", color: .purple, workspaces: [
            SidebarWorkspace(id: id("g1"), title: "g1", tabs: [SidebarTab(id: TabID("t3"), title: "Terminal")]), w("g2"), w("g3"),
        ]))
        return sections
    }

    @Test func offByDefaultRowsHaveNoDisclosureAndNoCount() {
        let layout = SidebarLayout.make(sections: sections(), metrics: .standard)
        let row = layout.row(for: .workspace(id("a")))
        #expect(row?.tabDisclosure == nil)
        #expect(row?.tabCount == nil)
        #expect(layout.row(for: .tab(id("a"), TabID("t1"))) == nil)
    }

    @Test func nestedTabsExpandOnlyTheWorkspacesTheUserOpened() {
        var options = SidebarLayoutOptions()
        options.nestedTabs = true
        let collapsed = SidebarLayout.make(sections: sections(), metrics: .standard, options: options)
        #expect(collapsed.row(for: .workspace(id("a")))?.tabDisclosure == .collapsed)
        #expect(collapsed.row(for: .tab(id("a"), TabID("t1"))) == nil)

        options.expandedWorkspaces = [id("a")]
        let expanded = SidebarLayout.make(sections: sections(), metrics: .standard, options: options)
        #expect(expanded.row(for: .workspace(id("a")))?.tabDisclosure == .expanded)
        #expect(expanded.row(for: .tab(id("a"), TabID("t2")))?.tabKind == .agentChat)
        // A workspace in a group keeps its disclosure, collapsed.
        #expect(expanded.row(for: .workspace(id("g1")))?.tabDisclosure == .collapsed)
    }

    @Test func aWorkspaceWithoutTabsHasNothingToDisclose() {
        var options = SidebarLayoutOptions()
        options.nestedTabs = true
        let layout = SidebarLayout.make(sections: sections(), metrics: .standard, options: options)
        #expect(layout.row(for: .workspace(id("b")))?.tabDisclosure == .empty)
    }

    @Test func showWorkspaceTabsStillListsEveryTabWithoutADisclosure() {
        var options = SidebarLayoutOptions()
        options.nestedTabs = true
        options.showWorkspaceTabs = true
        let layout = SidebarLayout.make(sections: sections(), metrics: .standard, options: options)
        #expect(layout.row(for: .workspace(id("a")))?.tabDisclosure == nil)
        #expect(layout.row(for: .tab(id("a"), TabID("t1"))) != nil)
    }

    @Test func countsShowTheWorkspaceTabCount() {
        var options = SidebarLayoutOptions()
        options.showCounts = true
        let layout = SidebarLayout.make(sections: sections(), metrics: .standard, options: options)
        #expect(layout.row(for: .workspace(id("a")))?.tabCount == 2)
        #expect(layout.row(for: .workspace(id("b")))?.tabCount == 0)
    }

    @MainActor @Test func theModelTogglesAWorkspaceOpenAndClosed() {
        let model = SidebarModel(sections: sections())
        model.toggleNestedTabs(id("a"))
        #expect(model.expandedWorkspaces == [id("a")])
        model.toggleNestedTabs(id("a"))
        #expect(model.expandedWorkspaces.isEmpty)
    }
}
