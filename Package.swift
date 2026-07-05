// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlowState",
    platforms: [.macOS(.v13)],
    targets: [
        // 纯逻辑:事件模型 + 状态→图标映射。App 和自测都依赖它。
        .target(name: "FlowStateCore"),
        // 右侧贴边 App。
        .executableTarget(
            name: "FlowState",
            dependencies: ["FlowStateCore"]
        ),
        // assert 自测(ponytail:v0 唯一非平凡逻辑的 check,无框架)。
        .executableTarget(
            name: "FlowStateSelfTest",
            dependencies: ["FlowStateCore"]
        ),
    ]
)
