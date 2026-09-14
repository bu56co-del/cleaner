import SwiftUI
import PawlyCore

struct ContentView: View {
    @Bindable var store: AppStore
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store)
            Rectangle().fill(Palette.border).frame(width: 1)
            VStack(spacing: 0) {
                Group {
                    switch store.page {
                    case .home: DashboardView(store: store)
                    case .cleanup: CleanupView(store: store)
                    case .deepClean: DeepCleanView(store: store, clean: store.deepClean)
                    case .applications: ApplicationsView(store: store, mole: store.mole)
                    case .projects: ProjectsView(store: store, projects: store.projects)
                    case .installers: InstallersView(store: store, files: store.installers)
                    case .maintenance: MaintenanceView(store: store, maintenance: store.maintenance)
                    case .disk: EngineDiskView(store: store, mole: store.mole)
                    case .health: HealthView(store: store, mole: store.mole)
                    case .history: CombinedHistoryView(store: store, mole: store.mole)
                    case .utilities: UtilitiesView(store: store)
                    case .operation: OperationView(store: store, mole: store.mole)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.background(Palette.background)
        }
        .frame(minWidth: 960, minHeight: 690)
        .font(.system(size: 13))
        .foregroundStyle(Palette.ink)
        .tint(Palette.coral)
        .sheet(isPresented: $store.reviewVisible) { ReviewSheet(store: store) }
        .alert(store.t("提示", "Notice"), isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button(store.t("知道了", "OK")) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

struct SidebarView: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CatMark().frame(width: 41, height: 41)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pawly").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(store.t("Mac 的貓咪小管家", "YOUR MAC'S LITTLE HELPER"))
                        .font(.system(size: 8, weight: .medium)).tracking(0.7).foregroundStyle(Palette.muted)
                }
            }.padding(.top, 27).padding(.bottom, 22).padding(.horizontal, 18)
            ScrollView {
            VStack(spacing: 3) {
                ForEach(Page.allCases) { page in
                    Button { store.page = page } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.icon).font(.system(size: 16)).frame(width: 21)
                            Text(store.title(page)).font(.system(size: 13, weight: store.page == page ? .semibold : .regular))
                            Spacer()
                            if store.page == page { Circle().fill(Palette.coral).frame(width: 5, height: 5) }
                        }.foregroundStyle(store.page == page ? Palette.coral : Palette.ink)
                            .padding(.horizontal, 13).frame(height: 36)
                            .background(store.page == page ? Palette.peach : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("nav-\(page.rawValue)")
                        .disabled(store.mole.operationActive && page != .operation)
                }
            }.padding(.horizontal, 13)
            }
            Spacer(minLength: 8)
            SettingsLink {
                Label(store.t("偏好設定", "Preferences"), systemImage: "slider.horizontal.3")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.buttonStyle(.plain).padding(.leading, 24).padding(.bottom, 16)
            HStack { Label(store.t("本機運作", "On your Mac"), systemImage: "lock"); Spacer(); Text("1.2") }
                .font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.horizontal, 22).padding(.bottom, 20)
        }.frame(width: 190).background(Palette.sidebar)
    }
}
