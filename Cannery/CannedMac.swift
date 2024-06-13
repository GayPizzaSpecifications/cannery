//
//  CannedMac.swift
//  macOS
//
//  Created by Alex Zenla on 3/22/22.
//

import Combine
import Foundation
import SwiftUI
import Virtualization

class CannedMac: ObservableObject, Identifiable {
    static let defaultVirtualMachineName = "macOS"

    @Published
    var state: CannedMacState = .unknown

    @Published
    var downloadCurrentProgress: Double = 0.0

    @Published
    var installerCurrentProgress: Double = 0.0

    @Published
    var error: Error?

    @Published
    var vm: VZVirtualMachine?

    @Published
    var currentVmState: VZVirtualMachine.State = .stopped

    var downloadProgressObserver: NSKeyValueObservation?
    var installProgressObserver: NSKeyValueObservation?
    var currentStateObserver: NSKeyValueObservation?

    var downloadTask: URLSessionDownloadTask?

    #if CANNED_MAC_USE_PRIVATE_APIS
    var vmVncServer: _VZVNCServer?
    #endif

    var virtualMachineName: String

    var id: String { virtualMachineName }

    private let serialReadPipe = Pipe()
    private let serialWritePipe = Pipe()

    var options: VirtualMachineOptions

    init(virtualMachineName: String = defaultVirtualMachineName, options: VirtualMachineOptions? = nil) {
        self.virtualMachineName = virtualMachineName
        do {
            let virtualMachineDirectory = try CannedMac.getVirtualMachineDirectory(name: virtualMachineName)
            self.options = try CannedMac.loadOrCreateOptions(virtualMachineDirectory: virtualMachineDirectory, options: options)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func createVmConfiguration() async throws -> (VZVirtualMachineConfiguration, VZMacOSRestoreImage?) {
        let existingHardwareModel = try loadMacHardwareModel()

        let model: VZMacHardwareModel
        let macRestoreImage: VZMacOSRestoreImage?
        if existingHardwareModel == nil {
            let image = try await downloadLatestSupportImage()

            guard let mostFeaturefulSupportedConfiguration = image.mostFeaturefulSupportedConfiguration else {
                throw UserError(.RestoreImageBad, "Restore image did not have a supported configuration.")
            }

            model = mostFeaturefulSupportedConfiguration.hardwareModel
            try saveMacHardwareModel(mostFeaturefulSupportedConfiguration.hardwareModel)
            macRestoreImage = image
        } else {
            model = existingHardwareModel!
            macRestoreImage = nil
        }

        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = computeCpuCount()
        configuration.memorySize = computeMemorySize(Int(options.memoryInGigabytes))

        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = try loadOrCreateMachineIdentifier()
        platform.auxiliaryStorage = try loadOrCreateAuxilaryStorage(model)
        platform.hardwareModel = model
        configuration.platform = platform
        configuration.bootLoader = VZMacOSBootLoader()

        let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        soundDeviceConfiguration.streams = [inputStream, outputStream]
        configuration.audioDevices.append(soundDeviceConfiguration)

        let diskImageAttachment = try getOrCreateDiskImage()
        let storage = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
        configuration.storageDevices.append(storage)

        let network = VZVirtioNetworkDeviceConfiguration()
        network.macAddress = try loadOrCreateMacAddress(network.macAddress)
        network.attachment = VZNATNetworkDeviceAttachment()
        configuration.networkDevices.append(network)

        let keyboard = VZUSBKeyboardConfiguration()
        configuration.keyboards.append(keyboard)

        var pointingDevice: VZPointingDeviceConfiguration = VZUSBScreenCoordinatePointingDeviceConfiguration()
        if options.macInputMode ?? true {
            pointingDevice = VZMacTrackpadConfiguration()
        }
        configuration.pointingDevices.append(pointingDevice)

        let memoryBalloon = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
        configuration.memoryBalloonDevices.append(memoryBalloon)

        let gpu = VZMacGraphicsDeviceConfiguration()

        let resolution = options.displayResolution

        let widthInPixels = resolution.width
        let heightInPixels = resolution.height
        let pixelsPerInch = resolution.pixelsPerInch

        let display = VZMacGraphicsDisplayConfiguration(
            widthInPixels: widthInPixels,
            heightInPixels: heightInPixels,
            pixelsPerInch: pixelsPerInch
        )
        gpu.displays.append(display)
        configuration.graphicsDevices.append(gpu)

        let entropy = VZVirtioEntropyDeviceConfiguration()
        configuration.entropyDevices.append(entropy)

        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.gdbDebugStub ?? false {
            let stub = VZPrivateUtilities.createGdbDebugStub(1)
            configuration.setGdbDebugStub(stub)
        }
        #endif

        if options.serialPortOutputEnabled {
            let serialPort = options.serialPortOutputType.createSerialPortConfiguration()
            serialPort.attachment = VZFileHandleSerialPortAttachment(
                fileHandleForReading: serialWritePipe.fileHandleForReading,
                fileHandleForWriting: serialReadPipe.fileHandleForWriting
            )
            configuration.serialPorts.append(serialPort)
        }

        try configuration.validate()
        return (configuration, macRestoreImage)
    }

    @MainActor
    func bootVirtualMachine() async throws {
        #if CANNED_MAC_USE_PRIVATE_APIS
        if vmVncServer != nil {
            vmVncServer!.stop()
            vmVncServer = nil
        }
        #endif

        let (configuration, macRestoreImage) = try await createVmConfiguration()
        let vm = VZVirtualMachine(configuration: configuration, queue: DispatchQueue.main)

        if let macRestoreImage {
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: macRestoreImage.url)
            installProgressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
                DispatchQueue.main.async {
                    if let value = change.newValue {
                        self.installerCurrentProgress = value
                    }
                }
            }
            DispatchQueue.main.async {
                self.state = .installingMacOS
            }
            try await installer.install()
            while vm.state != .stopped {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        DispatchQueue.main.async {
            self.state = .bootVirtualMachine
            self.vm = vm
        }

        currentStateObserver = vm.observe(\.state, options: [.initial, .new]) { machine, _ in
            DispatchQueue.main.async {
                self.currentVmState = machine.state
            }
        }

        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.vncServerEnabled ?? false {
            let vncServerPassword = (options.vncServerAuthenticationEnabled ?? false) ? options.vncServerPassword : nil
            let server = VZPrivateUtilities.createVncServer(port: options.vncServerPort ?? 5905, queue: DispatchQueue.main, password: vncServerPassword)
            server.virtualMachine = vm
            server.start()
            vmVncServer = server
        } else {
            vmVncServer = nil
        }
        #endif

        let startOptions = VZMacOSVirtualMachineStartOptions()
        startOptions.startUpFromMacOSRecovery = options.bootToRecovery ?? false
        try await vm.start(options: startOptions)
    }

    @MainActor
    func deleteVirtualMachine() async throws {
        if let vm {
            if vm.state != .stopped {
                try await vm.stop()
            }
        }

        try deleteVirtualMachineDirectory()
    }

    func loadMacHardwareModel() throws -> VZMacHardwareModel? {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let hardwareModelUrl = virtualMachineDirectory.appendingPathComponent("machw.bin")

        if FileManager.default.fileExists(at: hardwareModelUrl) {
            let data = try Data(contentsOf: hardwareModelUrl)
            return VZMacHardwareModel(dataRepresentation: data)
        }
        return nil
    }

    func saveMacHardwareModel(_ model: VZMacHardwareModel) throws {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let hardwareModelUrl = virtualMachineDirectory.appendingPathComponent("machw.bin")
        try model.dataRepresentation.write(to: hardwareModelUrl)
    }

    func downloadLatestSupportImage() async throws -> VZMacOSRestoreImage {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let standardRestoreIpswFileUrl = virtualMachineDirectory.appendingPathComponent("restore.ipsw")

        var restoreIpswUrl: URL = standardRestoreIpswFileUrl
        if let restoreIpswPath = options.restoreIpswPath {
            restoreIpswUrl = URL(fileURLWithPath: restoreIpswPath, relativeTo: virtualMachineDirectory)
        }

        if FileManager.default.fileExists(at: restoreIpswUrl) {
            return try await VZMacOSRestoreImage.image(from: restoreIpswUrl)
        }

        DispatchQueue.main.async {
            self.state = .downloadInstaller
        }

        let image = try await VZMacOSRestoreImage.latestSupported
        let future: Future<URL?, Error> = Future { promise in
            let task = URLSession.shared.downloadTask(with: image.url) { url, _, error in
                if let error {
                    promise(.failure(error))
                    return
                }
                promise(.success(url))
            }
            self.downloadTask = task

            self.downloadProgressObserver = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
                if let value = change.newValue {
                    DispatchQueue.main.async {
                        self.downloadCurrentProgress = value
                    }
                }
            }

            DispatchQueue.main.async {
                self.state = .downloadInstaller
            }
            task.resume()
        }

        let temporaryFileUrl = try await future.value

        guard let temporaryFileUrl else {
            throw UserError(.DownloadFailed, "Download of installer failed.")
        }

        try FileManager.default.moveItem(at: temporaryFileUrl, to: standardRestoreIpswFileUrl)

        return try await VZMacOSRestoreImage.image(from: standardRestoreIpswFileUrl)
    }

    func cancelInstallerDownload() {
        downloadTask?.cancel()
        state = .unknown
    }

    func loadOrCreateAuxilaryStorage(_ model: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let auxilaryStorageUrl = virtualMachineDirectory.appendingPathComponent("macaux.bin")

        if FileManager.default.fileExists(at: auxilaryStorageUrl) {
            return VZMacAuxiliaryStorage(contentsOf: auxilaryStorageUrl)
        } else {
            return try VZMacAuxiliaryStorage(creatingStorageAt: auxilaryStorageUrl, hardwareModel: model)
        }
    }

    func loadOrCreateMachineIdentifier() throws -> VZMacMachineIdentifier {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let macIdentifierUrl = virtualMachineDirectory.appendingPathComponent("macid.bin")

        if FileManager.default.fileExists(at: macIdentifierUrl) {
            let data = try Data(contentsOf: macIdentifierUrl)
            return VZMacMachineIdentifier(dataRepresentation: data)!
        } else {
            let identifier = VZMacMachineIdentifier()
            let data = identifier.dataRepresentation
            try data.write(to: macIdentifierUrl)
            return identifier
        }
    }

    func loadOrCreateMacAddress(_ randomAddress: VZMACAddress) throws -> VZMACAddress {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let macAddressUrl = virtualMachineDirectory.appendingPathComponent("macaddress.bin")

        if FileManager.default.fileExists(at: macAddressUrl) {
            let data = try Data(contentsOf: macAddressUrl)
            let string = String(data: data, encoding: .utf8)!
            return VZMACAddress(string: string)!
        } else {
            let string = randomAddress.string
            let data = string.data(using: .utf8)!
            try data.write(to: macAddressUrl)
            return randomAddress
        }
    }

    static func loadOrCreateOptions(virtualMachineDirectory: URL, options defaultOptions: VirtualMachineOptions? = nil) throws -> VirtualMachineOptions {
        let optionsFileUrl = virtualMachineDirectory.appendingPathComponent("options.plist")
        let options: VirtualMachineOptions = if FileManager.default.fileExists(at: optionsFileUrl) {
            try PropertyListDecoder().decode(VirtualMachineOptions.self, from: Data(contentsOf: optionsFileUrl))
        } else {
            defaultOptions ?? VirtualMachineOptions(virtualMachineName: virtualMachineDirectory.lastPathComponent)
        }
        try options.saveTo(url: optionsFileUrl)
        return options
    }

    func saveCurrentOptions() throws {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let optionsFileUrl = virtualMachineDirectory.appendingPathComponent("options.plist")
        try options.saveTo(url: optionsFileUrl)
    }

    func getOrCreateDiskImage() throws -> VZDiskImageStorageDeviceAttachment {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let diskImageUrl = virtualMachineDirectory.appendingPathComponent("disk.img")

        if FileManager.default.fileExists(at: diskImageUrl) {
            return try VZDiskImageStorageDeviceAttachment(url: diskImageUrl, readOnly: false)
        } else {
            var diskSpaceToUse = Int64(128 * 1024 * 1024 * 1024)
            if try FileUtilities.diskSpaceAvailable() < diskSpaceToUse {
                diskSpaceToUse = 64 * 1024 * 1024 * 1024
            }
            try FileUtilities.createSparseImage(diskImageUrl, size: diskSpaceToUse)
            return try VZDiskImageStorageDeviceAttachment(url: diskImageUrl, readOnly: false)
        }
    }

    func computeMemorySize(_ memory: Int) -> UInt64 {
        var memorySize = (UInt64(memory) * 1024 * 1024 * 1024) as UInt64
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

        return memorySize
    }

    func computeCpuCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }

    func deleteVirtualMachineDirectory() throws {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        try FileManager.default.trashItem(at: virtualMachineDirectory, resultingItemURL: nil)
    }

    func getVirtualMachineDirectory(createIfNotExists: Bool = true) throws -> URL {
        let applicationSupportDirectoryUrl = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineDirectory = applicationSupportDirectoryUrl.appendingPathComponent(virtualMachineName)
        if createIfNotExists {
            try FileManager.default.createDirectory(at: virtualMachineDirectory, withIntermediateDirectories: true)
        }
        return virtualMachineDirectory
    }

    static func getVirtualMachineDirectory(name: String, createIfNotExists: Bool = true) throws -> URL {
        let applicationSupportDirectoryUrl = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineDirectory = applicationSupportDirectoryUrl.appendingPathComponent(name)
        if createIfNotExists {
            try FileManager.default.createDirectory(at: virtualMachineDirectory, withIntermediateDirectories: true)
        }
        return virtualMachineDirectory
    }

    func migrateOldDirectoryIfNecessary() throws {
        if virtualMachineName != CannedMac.defaultVirtualMachineName {
            return
        }

        let legacyMachineDirectory = try FileUtilities.getLegacyApplicationSupportDirectory()

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(at: legacyMachineDirectory, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return
        }

        let virtualMachineDirectory = try getVirtualMachineDirectory(createIfNotExists: false)
        try FileManager.default.moveItem(at: legacyMachineDirectory, to: virtualMachineDirectory)
    }

    func setCurrentError(_ error: Error) {
        DispatchQueue.main.async {
            self.state = .error
            self.error = error
        }
    }

    func stateToString(_ state: VZVirtualMachine.State) -> String {
        switch state {
        case .stopped:
            return "stopped"
        case .running:
            return "running"
        case .paused:
            return "paused"
        case .error:
            return "error"
        case .starting:
            return "starting"
        case .pausing:
            return "pausing"
        case .resuming:
            return "resuming"
        case .stopping:
            return "stopping"
        case .saving:
            return "saving"
        case .restoring:
            return "restoring"
        @unknown default:
            return "unknown"
        }
    }
}

enum CannedMacState {
    case unknown
    case error
    case downloadInstaller
    case installingMacOS
    case bootVirtualMachine
}
